import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/core/intelligence/web_health_intelligence_enricher.dart';
import 'package:mobile_app/features/health_intelligence/domain/health_intelligence_model.dart';

void main() {
  group('WebHealthIntelligenceEnricher Tests', () {
    test('resolves offline botanical intelligence for Hamdard Safi tonic with Senna warnings', () {
      final result = WebHealthIntelligenceEnricher.resolveOfflineKnowledge(
        productName: 'Hamdard Safi',
        brandName: 'Hamdard',
        category: 'Ayurvedic Tonic',
        ingredients: ['Senna', 'Turbud', 'Neem', 'Sugar'],
        sugarsG: 22.0,
      );

      expect(result.domain, ProductCategoryDomain.ayurvedicHerbalTonic);
      expect(result.hasBioactiveRisk, isTrue);
      expect(result.bioactiveCompounds.any((c) => c.name.contains('Senna')), isTrue);
      expect(result.organImpact.gutAndDigestion, contains('stimulant laxative'));
      expect(result.contraindications.pregnancyBreastfeeding, contains('CONTRAINDICATION'));
      expect(result.contraindications.chronicUseDuration, contains('7 to 14 consecutive days'));
      expect(result.claimsVsReality.any((c) => c.claim.contains('Blood Purifier')), isTrue);
    });

    test('resolves offline functional intelligence for energy drinks (Sting/Red Bull)', () {
      final result = WebHealthIntelligenceEnricher.resolveOfflineKnowledge(
        productName: 'Sting Energy Drink',
        brandName: 'PepsiCo',
        category: 'Energy Drink',
        ingredients: ['Carbonated Water', 'Sugar', 'Caffeine', 'Taurine', 'INS 129'],
        sugarsG: 27.0,
      );

      expect(result.domain, ProductCategoryDomain.energyFunctionalDrink);
      expect(result.hasBioactiveRisk, isTrue);
      expect(result.bioactiveCompounds.any((c) => c.name.contains('Caffeine')), isTrue);
      expect(result.bioactiveCompounds.any((c) => c.name.contains('Taurine')), isTrue);
      expect(result.contraindications.children, contains('Not suitable for children'));
      expect(result.organImpact.cardiovascularAndNervous, contains('heart rate'));
    });

    test('resolves offline nutraceutical intelligence for Whey Protein powder', () {
      final result = WebHealthIntelligenceEnricher.resolveOfflineKnowledge(
        productName: 'Gold Standard 100% Whey Protein',
        brandName: 'Optimum Nutrition',
        category: 'Protein Supplement',
        ingredients: ['Whey Protein Isolate', 'BCAA', 'Sucralose'],
        proteinG: 24.0,
      );

      expect(result.domain, ProductCategoryDomain.nutraceuticalSupplement);
      expect(result.extendedNutrients.proteinG, 24.0);
      expect(result.bioactiveCompounds.any((c) => c.name.contains('BCAA')), isTrue);
      expect(result.organImpact.kidneyAndElectrolytes, contains('filtration rate'));
    });

    test('enrichProduct queries Gemini with Google Search Grounding when online', () async {
      final mockClient = MockClient((request) async {
        // Mock successful Gemini response with Google Search grounding
        final mockResponse = {
          'candidates': [
            {
              'content': {
                'parts': [
                  {
                    'text': jsonEncode({
                      'domain': 'ayurvedic_herbal_tonic',
                      'extended_nutrients': {
                        'added_sugars_g': 20.0,
                        'protein_g': 0.5,
                        'glycemic_load_estimate': 'High',
                      },
                      'bioactive_compounds': [
                        {
                          'name': 'Senna Leaf Extract (Sennoside B)',
                          'botanical_chemical_name': 'Cassia angustifolia',
                          'function_category': 'Stimulant Laxative',
                          'risk_level': 'caution_chronic_use',
                          'physiological_effect': 'Stimulates bowel motility.',
                          'triggers_chronic_use_warning': true,
                        }
                      ],
                      'organ_impact': {
                        'gut_and_digestion': 'Induces laxative peristalsis.',
                        'liver_and_metabolism': 'Hepatic clearance.',
                        'kidney_and_electrolytes': 'Electrolyte depletion.',
                        'cardiovascular_and_nervous': 'Arrhythmia risk if hypokalemic.'
                      },
                      'contraindications': {
                        'pregnancy_breastfeeding': 'Contraindicated during pregnancy.',
                        'chronic_use_duration': 'Do not use for more than 7 days.'
                      },
                      'claims_vs_reality': [
                        {
                          'claim': 'Blood Cleanser',
                          'reality': 'Fluid stool loss, not blood filtration.',
                          'evidence_level': 'misleading_marketing'
                        }
                      ],
                      'safety_advisories': [
                        'Avoid prolonged daily use.'
                      ],
                      'clinical_summary': 'Senna-dominant herbal tonic.'
                    })
                  }
                ]
              },
              'groundingMetadata': {
                'groundingChunks': [
                  {
                    'web': {'uri': 'https://ncbi.nlm.nih.gov/articles/PMC1234'}
                  },
                  {
                    'web': {'uri': 'https://who.int/medicines/senna'}
                  }
                ]
              }
            }
          ]
        };

        return http.Response(jsonEncode(mockResponse), 200, headers: {'content-type': 'application/json'});
      });

      final enricher = WebHealthIntelligenceEnricher(httpClient: mockClient);
      final result = await enricher.enrichProduct(
        productName: 'Hamdard Safi',
        brandName: 'Hamdard',
        category: 'Ayurvedic',
        forceRefresh: true,
      );

      expect(result.domain, ProductCategoryDomain.ayurvedicHerbalTonic);
      expect(result.hasBioactiveRisk, isTrue);
      expect(result.isGrounded, isTrue);
      expect(result.internetGroundedSources, contains('ncbi.nlm.nih.gov'));
      expect(result.internetGroundedSources, contains('who.int'));
    });

    test('resolves offline botanical intelligence for Kokangem Fruit Syrup without refined fats', () {
      final result = WebHealthIntelligenceEnricher.resolveOfflineKnowledge(
        productName: 'Kokangem Fruit Syrup',
        brandName: 'Kokangem',
        category: 'Beverages & Juices',
        ingredients: ['Kokum Juice', 'Sugar', 'Water', 'INS 330', 'INS 211'],
        sugarsG: 68.0,
        satFatG: 0.0,
        totalFatG: 0.0,
        sodiumMg: 15.0,
        calories: 272.0,
      );

      expect(result.domain, ProductCategoryDomain.ayurvedicHerbalTonic);
      expect(result.bioactiveCompounds.any((c) => c.name.contains('Kokum Anthocyanins')), isTrue);
      expect(result.bioactiveCompounds.any((c) => c.name.contains('Hydroxycitric Acid')), isTrue);
      expect(result.organImpact.liverAndMetabolism, contains('antioxidant'));

      // Strict validation: NEVER mention refined fats on fruit syrup!
      for (final item in result.claimsVsReality) {
        expect(item.reality.toLowerCase(), isNot(contains('refined fat')));
        expect(item.claim.toLowerCase(), isNot(contains('refined fat')));
      }

      // Must have Kokum and free-sugar claims
      expect(result.claimsVsReality.any((c) => c.claim.contains('Kokum Botanical Wellness')), isTrue);
      expect(result.claimsVsReality.any((c) => c.reality.contains('free-sugar limit')), isTrue);
    });

    test('verifies that Gemini search grounding request omits responseMimeType to prevent HTTP 400', () async {
      bool capturedSearchRequest = false;

      final mockClient = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final tools = body['tools'] as List?;
        final genConfig = body['generationConfig'] as Map<String, dynamic>?;

        if (tools != null && tools.any((t) => t['google_search'] != null)) {
          capturedSearchRequest = true;
          // CRITICAL: When google_search tool is present, responseMimeType must NOT be set
          expect(genConfig?['responseMimeType'], isNull,
              reason: 'Gemini API throws HTTP 400 if responseMimeType is sent with tools');
        }

        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': jsonEncode({
                        'domain': 'standard_food',
                        'extended_nutrients': {'added_sugars_g': 10.0},
                        'bioactive_compounds': [],
                        'organ_impact': {
                          'gut_and_digestion': 'Normal',
                          'liver_and_metabolism': 'Normal',
                          'kidney_and_electrolytes': 'Normal',
                          'cardiovascular_and_nervous': 'Normal'
                        },
                        'contraindications': {'pregnancy_breastfeeding': 'Safe'},
                        'claims_vs_reality': [
                          {
                            'claim': 'Pure & Natural',
                            'reality': 'Standard processing.',
                            'evidence_level': 'partial_evidence'
                          }
                        ],
                        'safety_advisories': [],
                        'clinical_summary': 'Standard item.'
                      })
                    }
                  ]
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final enricher = WebHealthIntelligenceEnricher(httpClient: mockClient);
      final result = await enricher.enrichProduct(
        productName: 'Kokangem Fruit Syrup',
        brandName: 'Kokangem',
        category: 'Beverages & Juices',
        forceRefresh: true,
      );

      expect(capturedSearchRequest, isTrue);
      expect(result, isNotNull);
    });

    test('dynamic claims analyzer triggers Rule B for high fat and Rule C for high sodium', () {
      // High fat product (e.g. Fried Bhujia)
      final highFat = WebHealthIntelligenceEnricher.resolveOfflineKnowledge(
        productName: 'Bikaji Bhujia',
        brandName: 'Bikaji',
        category: 'Snacks & Savouries',
        sugarsG: 2.0,
        satFatG: 12.0,
        totalFatG: 38.0,
        sodiumMg: 750.0,
        calories: 560.0,
      );

      // Must trigger Rule B (Saturated / Total fat)
      expect(highFat.claimsVsReality.any((c) => c.reality.contains('saturated fat') && c.reality.contains('38.0g total fat')), isTrue);
      // Must trigger Rule C (High sodium)
      expect(highFat.claimsVsReality.any((c) => c.reality.contains('750mg sodium')), isTrue);
      // Must NOT contain the old static text
      for (final c in highFat.claimsVsReality) {
        expect(c.reality, isNot(contains('Commercial industrial processing typically involves high heat, refined fats, and sodium preservation')));
      }
    });
  });
}

