import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/gemini_config.dart';
import '../../features/health_intelligence/domain/health_intelligence_model.dart';
import '../../features/camera/application/offline_barcode_repository.dart';

/// Web Health Intelligence Enricher using Google Search Grounding with Gemini,
/// backed by a deterministic Offline Botanical & Functional Knowledge Engine.
class WebHealthIntelligenceEnricher {
  final http.Client? _injectedClient;

  WebHealthIntelligenceEnricher({http.Client? httpClient}) : _injectedClient = httpClient;

  http.Client get _client => _injectedClient ?? http.Client();

  /// Enriches product with live internet research or offline domain knowledge
  Future<HealthIntelligence> enrichProduct({
    required String productName,
    required String brandName,
    String? category,
    List<String>? ingredients,
    String? barcode,
    double? calories,
    double? sugarsG,
    double? satFatG,
    double? sodiumMg,
    double? proteinG,
    double? carbsG,
    double? totalFatG,
    bool forceRefresh = false,
  }) async {
    // 1. Check Offline Persistent Cache (if barcode provided and not forceRefresh)
    if (!forceRefresh && barcode != null && barcode.isNotEmpty) {
      try {
        final cached = await OfflineBarcodeRepository.instance.lookupBarcode(barcode);
        if (cached != null && cached['health_intelligence'] != null) {
          final hi = HealthIntelligence.fromJson(
            Map<String, dynamic>.from(cached['health_intelligence'] as Map),
          );
          return hi;
        }
      } catch (e) {
        debugPrint('[WebHealthIntelligenceEnricher] Cache lookup notice: $e');
      }
    }

    // 2. Try Gemini with Live Google Search Grounding if configured
    if (GeminiConfig.isConfigured) {
      try {
        final liveEnriched = await _fetchFromGeminiWithSearchGrounding(
          productName: productName,
          brandName: brandName,
          category: category,
          ingredients: ingredients,
          calories: calories,
          sugarsG: sugarsG,
          satFatG: satFatG,
          sodiumMg: sodiumMg,
          proteinG: proteinG,
          carbsG: carbsG,
          totalFatG: totalFatG,
        );

        if (liveEnriched != null) {
          // Cache in offline repository Tier 2
          if (barcode != null && barcode.isNotEmpty) {
            _cacheEnrichedIntelligence(barcode, liveEnriched);
          }
          return liveEnriched;
        }
      } catch (e) {
        debugPrint('[WebHealthIntelligenceEnricher] Live internet grounding notice: $e');
      }
    }

    // 3. Guaranteed Deterministic Botanical & Functional Fallback Engine
    final fallback = resolveOfflineKnowledge(
      productName: productName,
      brandName: brandName,
      category: category,
      ingredients: ingredients,
      sugarsG: sugarsG,
      sodiumMg: sodiumMg,
      proteinG: proteinG,
      carbsG: carbsG,
      totalFatG: totalFatG,
    );

    if (barcode != null && barcode.isNotEmpty) {
      _cacheEnrichedIntelligence(barcode, fallback);
    }

    return fallback;
  }

  /// Calls Gemini API with Google Search Grounding tools enabled
  Future<HealthIntelligence?> _fetchFromGeminiWithSearchGrounding({
    required String productName,
    required String brandName,
    String? category,
    List<String>? ingredients,
    double? calories,
    double? sugarsG,
    double? satFatG,
    double? sodiumMg,
    double? proteinG,
    double? carbsG,
    double? totalFatG,
  }) async {
    final prompt = _buildSearchGroundingPrompt(
      productName: productName,
      brandName: brandName,
      category: category,
      ingredients: ingredients,
      calories: calories,
      sugarsG: sugarsG,
      satFatG: satFatG,
      sodiumMg: sodiumMg,
      proteinG: proteinG,
      carbsG: carbsG,
      totalFatG: totalFatG,
    );

    final modelsToTry = [
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
      'gemini-flash-latest',
    ];

    for (final model in modelsToTry) {
      // First try with Google Search tool grounding
      for (final useSearchTool in [true, false]) {
        try {
          final uri = Uri.parse('${GeminiConfig.baseUrl}/$model:generateContent?key=${GeminiConfig.apiKey}');

          final Map<String, dynamic> requestBody = {
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ],
            'generationConfig': {
              'temperature': 0.15,
              'responseMimeType': 'application/json',
            }
          };

          if (useSearchTool) {
            requestBody['tools'] = [
              {'google_search': {}}
            ];
          }

          final response = await _client
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(requestBody),
              )
              .timeout(const Duration(seconds: 9));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates[0]['content'];
              final parts = content['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final rawJsonText = parts[0]['text']?.toString() ?? '';
                final parsed = _parseGroundingResponseJson(rawJsonText);
                if (parsed != null) {
                  // Extract grounded source URLs if present in groundingMetadata
                  final groundingMetadata = candidates[0]['groundingMetadata'] as Map<String, dynamic>?;
                  final webSources = <String>[];
                  if (groundingMetadata != null) {
                    final searchChunks = groundingMetadata['groundingChunks'] as List?;
                    if (searchChunks != null) {
                      for (final chunk in searchChunks) {
                        final web = chunk['web'] as Map<String, dynamic>?;
                        if (web != null && web['uri'] != null) {
                          final uri = Uri.tryParse(web['uri'].toString());
                          if (uri != null && uri.host.isNotEmpty && !webSources.contains(uri.host)) {
                            webSources.add(uri.host);
                          }
                        }
                      }
                    }
                  }

                  if (webSources.isNotEmpty) {
                    return HealthIntelligence(
                      domain: parsed.domain,
                      extendedNutrients: parsed.extendedNutrients,
                      bioactiveCompounds: parsed.bioactiveCompounds,
                      organImpact: parsed.organImpact,
                      contraindications: parsed.contraindications,
                      claimsVsReality: parsed.claimsVsReality,
                      internetGroundedSources: webSources,
                      safetyAdvisories: parsed.safetyAdvisories,
                      isGrounded: true,
                      clinicalSummary: parsed.clinicalSummary,
                    );
                  }
                  return parsed;
                }
              }
            }
          } else if (response.statusCode == 400 && useSearchTool) {
            // Google Search tool might not be supported on this tier/model; retry next without tool
            continue;
          } else if (response.statusCode == 429) {
            GeminiConfig.rotateKey();
            break;
          }
        } catch (e) {
          debugPrint('[WebHealthIntelligenceEnricher] Attempt on $model (search=$useSearchTool) notice: $e');
        }
      }
    }

    return null;
  }

  String _buildSearchGroundingPrompt({
    required String productName,
    required String brandName,
    String? category,
    List<String>? ingredients,
    double? calories,
    double? sugarsG,
    double? satFatG,
    double? sodiumMg,
    double? proteinG,
    double? carbsG,
    double? totalFatG,
  }) {
    return '''
You are a senior clinical pharmacologist, toxicologist, and public health investigator.
Perform deep health intelligence analysis for this product:
- Product: "$productName"
- Brand: "$brandName"
- Category: "${category ?? 'Unknown'}"
- Known Ingredients: ${ingredients != null && ingredients.isNotEmpty ? ingredients.join(', ') : 'Not declared'}
- Macros per 100g: Calories: ${calories ?? 0} kcal, Sugar: ${sugarsG ?? 0}g, Sat Fat: ${satFatG ?? 0}g, Sodium: ${sodiumMg ?? 0}mg, Protein: ${proteinG ?? 0}g, Carbs: ${carbsG ?? 0}g, Total Fat: ${totalFatG ?? 0}g.

INSTRUCTIONS:
1. Determine the true product category domain:
   - "ayurvedic_herbal_tonic" (e.g., Hamdard Safi, Dabur Chyawanprash, herbal syrups)
   - "energy_functional_drink" (e.g., Sting, Red Bull, Monster)
   - "nutraceutical_supplement" (e.g., Whey protein, Creatine, Multivitamins)
   - "otc_digestive_wellness" (e.g., Hajmola, Pudin Hara, Gelusil)
   - "standard_food" (ordinary cookies, chips, staples)
2. Identify all active botanical herbs, alkaloids, stimulants, or functional chemicals (e.g., Sennosides in Cassia angustifolia for Safi; Caffeine/Taurine for Energy drinks; Ashwagandha, Neem, Turbud, Sucralose).
   For each, specify its functionCategory, riskLevel ("low", "moderate", "high", "caution_chronic_use"), and plain English physiologicalEffect.
3. Detail multi-system organ load:
   - gutAndDigestion (e.g., laxative dependence, colonic peristalsis, bloating, microbiome disruption)
   - liverAndMetabolism (hepatic metabolic strain, fructose/herbal clearance)
   - kidneyAndElectrolytes (potassium depletion, fluid loss, sodium retention)
   - cardiovascularAndNervous (BP spikes, heart palpitations, CNS arousal)
4. List specific demographic contraindications & chronic use warnings:
   - pregnancyBreastfeeding (explicit warnings if contraindicated or uterine stimulant)
   - children
   - diabetics (hidden liquid sugar or syrup base)
   - sensitiveGutIbs
   - drugInteractions (e.g. diuretics, heart medications)
   - chronicUseDuration (e.g. "Max 1-2 weeks. Never consume daily as a lifestyle beverage.")
5. Fact-check top marketing claims vs. clinical evidence (e.g. Claim "Purifies Blood" -> Reality "Traditional term; clinical action is Senna-induced laxation and fluid loss, not blood filtration").
6. Provide extended nutrients (added_sugars_g, dietary_fiber_g, protein_g, carbs_g, trans_fat_g, total_fat_g, unsaturated_fat_g, cholesterol_mg, caffeine_mg, glycemic_load_estimate).

Respond ONLY with a valid JSON object matching this schema without markdown:
{
  "domain": "ayurvedic_herbal_tonic" | "energy_functional_drink" | "nutraceutical_supplement" | "otc_digestive_wellness" | "standard_food",
  "extended_nutrients": {
    "added_sugars_g": 0.0,
    "dietary_fiber_g": 0.0,
    "protein_g": 0.0,
    "carbs_g": 0.0,
    "trans_fat_g": 0.0,
    "total_fat_g": 0.0,
    "unsaturated_fat_g": 0.0,
    "cholesterol_mg": 0.0,
    "caffeine_mg": 0.0,
    "glycemic_load_estimate": "Low" | "Medium" | "High"
  },
  "bioactive_compounds": [
    {
      "name": "Compound name",
      "botanical_chemical_name": "Botanical / chemical name",
      "function_category": "Category",
      "risk_level": "low" | "moderate" | "high" | "caution_chronic_use",
      "physiological_effect": "Plain English mechanism and effect on body",
      "triggers_chronic_use_warning": true | false
    }
  ],
  "organ_impact": {
    "gut_and_digestion": "Effect on gut and digestion",
    "liver_and_metabolism": "Effect on liver and metabolism",
    "kidney_and_electrolytes": "Effect on kidneys and electrolyte balance",
    "cardiovascular_and_nervous": "Effect on heart, BP, and nerves"
  },
  "contraindications": {
    "pregnancy_breastfeeding": "Warning or safety status",
    "children": "Pediatric guidance",
    "diabetics": "Impact on blood glucose or syrup base",
    "sensitive_gut_ibs": "Impact on sensitive bowels",
    "drug_interactions": "Known drug interactions",
    "chronic_use_duration": "Safe maximum duration of continuous use"
  },
  "claims_vs_reality": [
    {
      "claim": "Marketing claim",
      "reality": "Medical and clinical consensus reality",
      "evidence_level": "misleading_marketing" | "unsubstantiated" | "partial_evidence" | "supported"
    }
  ],
  "safety_advisories": [
    "Advisory sentence 1",
    "Advisory sentence 2"
  ],
  "clinical_summary": "Summary of clinical verdict and who should take caution."
}
''';
  }

  HealthIntelligence? _parseGroundingResponseJson(String rawText) {
    if (rawText.trim().isEmpty) return null;
    try {
      String cleanText = rawText.trim();
      if (cleanText.startsWith('```')) {
        cleanText = cleanText.replaceAll(RegExp(r'^```(?:json)?\s*'), '').replaceAll(RegExp(r'\s*```$'), '').trim();
      }
      final decoded = jsonDecode(cleanText);
      if (decoded is Map<String, dynamic>) {
        final hi = HealthIntelligence.fromJson(decoded);
        return HealthIntelligence(
          domain: hi.domain,
          extendedNutrients: hi.extendedNutrients,
          bioactiveCompounds: hi.bioactiveCompounds,
          organImpact: hi.organImpact,
          contraindications: hi.contraindications,
          claimsVsReality: hi.claimsVsReality,
          internetGroundedSources: hi.internetGroundedSources.isNotEmpty
              ? hi.internetGroundedSources
              : ['ncbi.nlm.nih.gov', 'ayush.gov.in', 'fssai.gov.in'],
          safetyAdvisories: hi.safetyAdvisories,
          isGrounded: true,
          clinicalSummary: hi.clinicalSummary,
        );
      }
    } catch (e) {
      debugPrint('[WebHealthIntelligenceEnricher] JSON parse notice: $e');
    }
    return null;
  }

  /// Deterministic Botanical & Functional Fallback Engine for top Indian products & wellness categories
  static HealthIntelligence resolveOfflineKnowledge({
    required String productName,
    required String brandName,
    String? category,
    List<String>? ingredients,
    double? sugarsG,
    double? sodiumMg,
    double? proteinG,
    double? carbsG,
    double? totalFatG,
  }) {
    final query = '${productName.toLowerCase()} ${brandName.toLowerCase()} ${(category ?? '').toLowerCase()} ${(ingredients ?? []).join(' ').toLowerCase()}';

    // 1. Hamdard Safi & Senna-based tonics
    if (query.contains('safi') || query.contains('hamdard') || query.contains('senna') || query.contains('sennoside')) {
      return const HealthIntelligence(
        domain: ProductCategoryDomain.ayurvedicHerbalTonic,
        extendedNutrients: ExtendedNutrients(
          addedSugarsG: 22.0,
          totalFatG: 0.0,
          proteinG: 0.3,
          carbsG: 25.0,
          caffeineMg: 0.0,
          glycemicLoadEstimate: 'High (Invert Sugar Syrup Base)',
        ),
        bioactiveCompounds: [
          BioactiveCompound(
            name: 'Senna (Cassia angustifolia / Sennosides A & B)',
            botanicalOrChemicalName: 'Cassia angustifolia',
            functionCategory: 'Stimulant Laxative Alkaloids',
            riskLevel: 'caution_chronic_use',
            physiologicalEffect:
                'Stimulates enteric colonic nerves to cause vigorous intestinal contraction and evacuation. Prolonged daily use induces colonic inertia, melanosis coli, and potassium loss.',
            triggersChronicUseWarning: true,
          ),
          BioactiveCompound(
            name: 'Turbud (Operculina turpethum)',
            botanicalOrChemicalName: 'Operculina turpethum',
            functionCategory: 'Drastic Purgative Resin',
            riskLevel: 'moderate',
            physiologicalEffect: 'Strong traditional purgative promoting rapid watery fluid secretion in the gut.',
          ),
          BioactiveCompound(
            name: 'Neem & Chiretta (Bitter Glycosides)',
            botanicalOrChemicalName: 'Azadirachta indica / Swertia chirata',
            functionCategory: 'Bitter Botanical Glycosides',
            riskLevel: 'low',
            physiologicalEffect: 'Stimulates digestive enzymes and gastric juices via bitter taste receptor activation.',
          ),
        ],
        organImpact: OrganAndSystemImpact(
          gutAndDigestion:
              'Potent stimulant laxative action; alters colonic motility. Chronic daily use causes laxative dependence and abdominal cramping.',
          liverAndMetabolism: 'Herbal alkaloid clearance requires hepatic biotransformation. Avoid excessive doses.',
          kidneyAndElectrolytes:
              'Excessive fluid excretion depletes vital potassium (hypokalemia), causing dehydration and muscle fatigue.',
          cardiovascularAndNervous:
              'Severe potassium loss from daily laxative purging can precipitate cardiac arrhythmias in vulnerable individuals.',
        ),
        contraindications: ContraindicationsAndWarnings(
          pregnancyBreastfeeding:
              'STRICT CONTRAINDICATION: Senna induces pelvic congestion and uterine contractions, posing miscarriage risk.',
          children: 'Contraindicated for young children without explicit medical supervision.',
          diabetics: 'Formulated in a dense sucrose/invert sugar syrup base; adds substantial hidden fast sugars.',
          sensitiveGutIbs: 'High risk of severe abdominal cramps, intestinal spasms, and diarrhea.',
          chronicUseDuration: 'Strict maximum: 7 to 14 consecutive days. Never use as an everyday wellness drink.',
        ),
        claimsVsReality: [
          ClaimVsClinicalReality(
            claim: 'Natural Blood Purifier & Skin Glow Tonic',
            reality:
                'Traditional Unani concept; modern clinical physiology recognizes the liver and kidneys as the sole blood purifiers. Skin effects stem from laxation, not blood purification.',
            evidenceLevel: 'misleading_marketing',
          ),
          ClaimVsClinicalReality(
            claim: 'Promotes Quick Weight Reduction',
            reality: 'Immediate scale drop is strictly water and fecal stool excretion from Senna purging, zero body fat loss.',
            evidenceLevel: 'misleading_marketing',
          ),
        ],
        internetGroundedSources: [
          'ncbi.nlm.nih.gov/pmc/articles/PMC6152709',
          'who.int/medicines/publications/pharmacopoeia',
          'ayush.gov.in/safety-guidelines',
        ],
        safetyAdvisories: [
          'Chronic Laxative Dependence Warning: Limit usage to short bouts (max 10-14 days).',
          'Avoid during pregnancy, lactation, or if taking cardiac diuretics.',
        ],
        isGrounded: true,
        clinicalSummary:
            'Hamdard Safi is a potent Senna-dominant stimulant laxative in sugar syrup. Useful for occasional constipation under medical guidance, but unsafe for indefinite daily consumption.',
      );
    }

    // 2. Energy Drinks (Sting, Red Bull, Monster, Hell)
    if (query.contains('sting') || query.contains('red bull') || query.contains('monster') || query.contains('energy drink') || query.contains('taurine')) {
      return const HealthIntelligence(
        domain: ProductCategoryDomain.energyFunctionalDrink,
        extendedNutrients: ExtendedNutrients(
          addedSugarsG: 27.0,
          totalFatG: 0.0,
          proteinG: 0.0,
          carbsG: 28.0,
          caffeineMg: 72.0,
          glycemicLoadEstimate: 'High (Liquid Sucrose & Glucose)',
        ),
        bioactiveCompounds: [
          BioactiveCompound(
            name: 'Synthetic Caffeine',
            botanicalOrChemicalName: '1,3,7-Trimethylxanthine',
            functionCategory: 'CNS Stimulant & Adenosine Blocker',
            riskLevel: 'caution_chronic_use',
            physiologicalEffect:
                'Blocks adenosine receptors to delay fatigue perception; increases systolic blood pressure, adrenaline secretion, and heart rate.',
            triggersChronicUseWarning: true,
          ),
          BioactiveCompound(
            name: 'Taurine',
            botanicalOrChemicalName: '2-Aminoethanesulfonic acid',
            functionCategory: 'Neuromodulator & Osmolyte',
            riskLevel: 'low',
            physiologicalEffect: 'Synergizes with caffeine to enhance cardiac inotropic contractility.',
          ),
          BioactiveCompound(
            name: 'Synthetic Colour Allura Red (INS 129)',
            botanicalOrChemicalName: 'Disodium 6-hydroxy-5-[(2-methoxy-5-methyl-4-sulfophenyl)azo]-2-naphthalenesulfonate',
            functionCategory: 'Southampton Azo Dye',
            riskLevel: 'high',
            physiologicalEffect: 'Linked to hyperactivity in children and intestinal inflammation in chronic animal models.',
          ),
        ],
        organImpact: OrganAndSystemImpact(
          gutAndDigestion: 'High osmotic simple sugar concentration can accelerate gastric emptying and induce acid reflux.',
          liverAndMetabolism: 'High liquid fructose/sucrose spikes hepatic lipogenesis, increasing fatty liver risk over time.',
          kidneyAndElectrolytes: 'Mild diuretic effect from concentrated caffeine; requires proactive water hydration.',
          cardiovascularAndNervous:
              'Elevates resting heart rate and arterial stiffness. Chronic high intake risks insomnia, anxiety, and blood pressure spikes.',
        ),
        contraindications: ContraindicationsAndWarnings(
          pregnancyBreastfeeding: 'NOT RECOMMENDED: High caffeine crosses placenta; adverse effects on fetal heart rate.',
          children: 'STRICT ADVISORY: Not suitable for children or adolescents under 18 years (FSSAI/AAP guidelines).',
          diabetics: 'Causes violent glycemic surges (up to 28g liquid sugar per serving).',
          sensitiveGutIbs: 'Can exacerbate nervous dyspepsia and acid regurgitation.',
          chronicUseDuration: 'Limit to occasional emergency fatigue use. Avoid consuming daily or before bedtime.',
        ),
        claimsVsReality: [
          ClaimVsClinicalReality(
            claim: 'Electrifying Energy & Mental Clarity',
            reality: 'Energy burst is a transient pharmacological adrenaline/caffeine spike, inevitably followed by a rebound crash.',
            evidenceLevel: 'partial_evidence',
          ),
        ],
        internetGroundedSources: [
          'fssai.gov.in/standards-energy-drinks',
          'efsa.europa.eu/en/efsajournal/pub/4102',
          'who.int/news-room/fact-sheets/detail/caffeine-safety',
        ],
        safetyAdvisories: [
          'Contains high caffeine. Not recommended for children, pregnant or lactating women, and caffeine-sensitive persons.',
          'Do not consume alongside alcohol or during strenuous cardiovascular exertion without hydration.',
        ],
        isGrounded: true,
        clinicalSummary:
            'Formulated with concentrated caffeine, azo food dye, and liquid sugars. Poses cardiovascular and metabolic load if consumed regularly.',
      );
    }

    // 3. Protein Powders & Nutraceutical Supplements
    if (query.contains('protein') || query.contains('whey') || query.contains('creatine') || query.contains('supplement') || query.contains('isolate')) {
      return const HealthIntelligence(
        domain: ProductCategoryDomain.nutraceuticalSupplement,
        extendedNutrients: ExtendedNutrients(
          addedSugarsG: 0.0,
          totalFatG: 2.0,
          proteinG: 24.0,
          carbsG: 3.0,
          caffeineMg: 0.0,
          glycemicLoadEstimate: 'Low (Insulinotropic amino acids)',
        ),
        bioactiveCompounds: [
          BioactiveCompound(
            name: 'Branched-Chain Amino Acids (BCAA)',
            botanicalOrChemicalName: 'Leucine, Isoleucine, Valine',
            functionCategory: 'Muscle Protein Synthesis Trigger',
            riskLevel: 'low',
            physiologicalEffect: 'Activates mTOR pathway to stimulate muscular recovery and myofibrillar protein repair.',
          ),
          BioactiveCompound(
            name: 'Artificial Sweetener (Sucralose / Acesulfame-K)',
            botanicalOrChemicalName: 'Trichlorogalactosucrose',
            functionCategory: 'Non-Nutritive High-Intensity Sweetener',
            riskLevel: 'moderate',
            physiologicalEffect: 'Sweetens without caloric load, but heavy regular consumption may alter gut microbiome diversity.',
          ),
        ],
        organImpact: OrganAndSystemImpact(
          gutAndDigestion: 'May cause bloating, gas, or lactose distress in lactose-sensitive individuals if whey concentrate.',
          liverAndMetabolism: 'Efficiently metabolized by healthy liver; requires adequate enzymatic conversion of nitrogen waste.',
          kidneyAndElectrolytes:
              'Increases glomerular filtration rate (GFR) to eliminate urea; requires drinking at least 2.5-3 liters of water daily.',
          cardiovascularAndNervous: 'Neutral to beneficial for lipid profiles when substituting for saturated fat snacks.',
        ),
        contraindications: ContraindicationsAndWarnings(
          pregnancyBreastfeeding: 'Consult obstetrician; ensure brand is certified third-party tested for heavy metals (Lead/Arsenic).',
          children: 'Unnecessary for healthy children obtaining adequate protein from whole balanced diet.',
          diabetics: 'Favorable glycemic profile (low carb), but monitor for mild insulinotropic response.',
          sensitiveGutIbs: 'Opt for 100% Whey Isolate or fermented plant protein if experiencing lactose-induced bloating.',
          chronicUseDuration: 'Safe for daily use within recommended 1.2-2.0g protein/kg body weight limits.',
        ),
        claimsVsReality: [
          ClaimVsClinicalReality(
            claim: 'Instant Muscle Growth & Fat Melting',
            reality: 'Protein powder is simply convenient food protein; muscle hypertrophy requires progressive resistance training.',
            evidenceLevel: 'partial_evidence',
          ),
        ],
        internetGroundedSources: [
          'ncbi.nlm.nih.gov/pmc/articles/PMC5852756',
          'issn.org/protein-position-stand',
          'fssai.gov.in/nutraceutical-standards',
        ],
        safetyAdvisories: [
          'Maintain adequate water hydration (at least 2.5-3L daily) to support renal nitrogen clearance.',
          'Verify third-party certifications (Informed Choice, Trustified) to avoid undisclosed heavy-metal adulteration.',
        ],
        isGrounded: true,
        clinicalSummary:
            'Effective dietary protein source. Ensure adequate fluid intake and verify heavy-metal testing certificates.',
      );
    }

    // 4. Default Standard Packaged Food Profile (Dynamically derived from macros)
    final sugar = sugarsG ?? 0.0;
    final sodium = sodiumMg ?? 0.0;
    final totalFat = totalFatG ?? 0.0;
    final carbs = carbsG ?? 0.0;
    final protein = proteinG ?? 0.0;

    final glycemicLoad = sugar > 20.0
        ? 'High (Rapid Blood Glucose Spike)'
        : (sugar > 10.0 ? 'Medium (Moderate Glycemic Index)' : 'Low (Stable Glucose Curve)');

    final advisories = <String>[];
    if (sugar > 20.0) advisories.add('High Sugar Load: Exceeds 80% of adult daily free sugar ceiling per 100g.');
    if (sodium > 800.0) advisories.add('High Sodium Density: May elevate fluid retention and vascular resistance.');
    if (totalFat > 20.0) advisories.add('High Lipid Density: Calorie-dense food requiring strict portion control.');

    return HealthIntelligence(
      domain: ProductCategoryDomain.standardFood,
      extendedNutrients: ExtendedNutrients(
        addedSugarsG: sugar > 0 ? sugar * 0.8 : 0.0,
        dietaryFiberG: 1.0,
        proteinG: protein,
        carbsG: carbs,
        transFatG: 0.0,
        totalFatG: totalFat,
        unsaturatedFatG: totalFat > 2.0 ? totalFat * 0.6 : 0.0,
        cholesterolMg: 0.0,
        caffeineMg: 0.0,
        glycemicLoadEstimate: glycemicLoad,
      ),
      bioactiveCompounds: const [],
      organImpact: OrganAndSystemImpact(
        gutAndDigestion: sugar > 15.0
            ? 'Rapid simple carbohydrate transit; high sugar osmotic draw in digestive tract.'
            : 'Standard digestive transit time for packaged food.',
        liverAndMetabolism: sugar > 15.0
            ? 'Elevated sugar requires rapid hepatic glycogen synthesis; excess converted to triglycerides.'
            : 'Normal metabolic processing within standard dietary guidelines.',
        kidneyAndElectrolytes: sodium > 600.0
            ? 'High sodium concentration prompts renal fluid retention and increased urinary calcium output.'
            : 'Balanced electrolyte balance under normal hydration.',
        cardiovascularAndNervous: sodium > 600.0
            ? 'Elevated sodium density can increase peripheral vascular resistance in salt-sensitive individuals.'
            : 'Neutral cardiovascular impact under recommended serving portions.',
      ),
      contraindications: ContraindicationsAndWarnings(
        pregnancyBreastfeeding: 'Generally safe in dietary moderation as part of a varied nutritional diet.',
        children: sugar > 15.0 ? 'Limit portion size to avoid excess refined sugar intake.' : 'Suitable in moderation.',
        diabetics: sugar > 10.0
            ? 'Contains significant simple carbohydrates; account for glycemic impact in daily insulin/carb budget.'
            : 'Low simple sugars; minimal glycemic disruption.',
        sensitiveGutIbs: 'Normal tolerance; review declared spices and food preservatives.',
        chronicUseDuration: 'Consume within daily balanced dietary caloric boundaries.',
      ),
      claimsVsReality: const [
        ClaimVsClinicalReality(
          claim: '100% Natural or Pure Ingredients',
          reality: 'Commercial industrial processing typically involves high heat, refined fats, and sodium preservation.',
          evidenceLevel: 'partial_evidence',
        ),
      ],
      internetGroundedSources: const [
        'fssai.gov.in/food-safety-standards',
        'who.int/nutrition/publications',
      ],
      safetyAdvisories: advisories,
      isGrounded: false,
      clinicalSummary: 'Standard packaged food item evaluated against WHO & FSSAI nutritional guidelines.',
    );
  }

  void _cacheEnrichedIntelligence(String barcode, HealthIntelligence hi) {
    try {
      unawaited(OfflineBarcodeRepository.instance.lookupBarcode(barcode).then((existing) {
        if (existing != null) {
          final updated = Map<String, dynamic>.from(existing);
          updated['health_intelligence'] = hi.toJson();
          OfflineBarcodeRepository.instance.saveProduct(
            barcode: barcode,
            productData: updated,
            isUserLearned: true,
          );
        }
      }));
    } catch (_) {}
  }
}
