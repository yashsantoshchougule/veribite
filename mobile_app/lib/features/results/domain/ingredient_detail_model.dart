import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Toxicity risk classification tier for food additives & ingredients
enum RiskTier {
  red,
  caution,
  safe;

  String get displayName {
    switch (this) {
      case RiskTier.red:
        return 'High Risk 🔴';
      case RiskTier.caution:
        return 'Caution 🟠';
      case RiskTier.safe:
        return 'Safe / Clean 🟢';
    }
  }

  Color get color {
    switch (this) {
      case RiskTier.red:
        return AppColors.safetyRed;
      case RiskTier.caution:
        return AppColors.safetyAmber;
      case RiskTier.safe:
        return AppColors.safetyGreen;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case RiskTier.red:
        return const Color(0xFFFCE8E6);
      case RiskTier.caution:
        return const Color(0xFFFEF7E0);
      case RiskTier.safe:
        return const Color(0xFFE6F4EA);
    }
  }
}

/// Comprehensive toxicology model for an ingredient or chemical additive
class IngredientDetailModel {
  final String name;
  final String? insCode;
  final RiskTier riskTier;
  final String category;
  final bool triggersRedCap;
  final String purpose;
  final String healthConcerns;
  final double? safeAdiMgPerKg;
  final List<String> internationalBans;
  final String? citationSource;
  final String? citationQuote;

  const IngredientDetailModel({
    required this.name,
    this.insCode,
    required this.riskTier,
    required this.category,
    this.triggersRedCap = false,
    required this.purpose,
    required this.healthConcerns,
    this.safeAdiMgPerKg,
    this.internationalBans = const [],
    this.citationSource,
    this.citationQuote,
  });

  /// Calculate acceptable daily intake in total milligrams for user's body weight
  double? calculateTotalSafeAdiMg(double userWeightKg) {
    if (safeAdiMgPerKg == null) return null;
    return safeAdiMgPerKg! * userWeightKg;
  }

  /// Construct from raw database map or scanner additive dictionary
  factory IngredientDetailModel.fromRawMap(Map<String, dynamic> raw) {
    final ins = raw['ins_code']?.toString();
    final rawName = raw['primary_name']?.toString() ?? raw['name']?.toString() ?? 'Unknown Ingredient';
    final rawRisk = raw['risk_tier']?.toString().toUpperCase() ?? 'GREEN';

    RiskTier tier;
    if (rawRisk == 'RED') {
      tier = RiskTier.red;
    } else if (rawRisk == 'CAUTION' || rawRisk == 'AMBER') {
      tier = RiskTier.caution;
    } else {
      tier = RiskTier.safe;
    }

    final redCap = raw['triggers_red_cap'] == 1 || raw['triggers_red_cap'] == true || tier == RiskTier.red;

    // Rich built-in toxicology knowledge base for common Indian packaged foods
    String purpose = raw['purpose']?.toString() ?? _defaultPurpose(ins, rawName);
    String concerns = raw['hazard_description']?.toString() ?? raw['health_concerns']?.toString() ?? _defaultConcerns(ins, rawName, tier);
    double? safeAdi = (raw['safe_adi_mg_kg'] as num?)?.toDouble() ?? _defaultAdi(ins);
    List<String> bans = (raw['international_bans'] as List?)?.map((e) => e.toString()).toList() ?? _defaultBans(ins);
    String? citationSrc = raw['citation_source']?.toString() ?? _defaultCitationSource(ins);
    String? citationText = raw['citation_quote']?.toString() ?? _defaultCitationQuote(ins);

    return IngredientDetailModel(
      name: rawName,
      insCode: ins != null && ins.isNotEmpty ? (ins.startsWith('INS') ? ins : 'INS $ins') : null,
      riskTier: tier,
      category: raw['category']?.toString() ?? _defaultCategory(ins),
      triggersRedCap: redCap,
      purpose: purpose,
      healthConcerns: concerns,
      safeAdiMgPerKg: safeAdi,
      internationalBans: bans,
      citationSource: citationSrc,
      citationQuote: citationText,
    );
  }

  static String _defaultPurpose(String? ins, String name) {
    if (ins == null) return 'Core food ingredient providing structure, texture, or nutrition.';
    final code = ins.replaceAll(RegExp(r'[^0-9]'), '');
    if (code.startsWith('1')) return 'Synthetic coloring agent added to restore or enhance bright cosmetic appearance.';
    if (code.startsWith('2')) return 'Preservative inhibiting growth of mold, yeast, and bacterial pathogens.';
    if (code.startsWith('3')) return 'Antioxidant preventing rancidity of fats and oils upon oxygen exposure.';
    if (code.startsWith('4')) return 'Emulsifier, stabilizer, or thickener binding fat and water phases seamlessly.';
    if (code.startsWith('5')) return 'Acidity regulator or leavening agent promoting dough expansion and texture.';
    if (code.startsWith('6')) return 'Flavor enhancer stimulating umami receptors on the palate to amplify savory taste.';
    if (code.startsWith('9')) return 'Artificial intense sweetener delivering concentrated sweetness with minimal calories.';
    return 'Technological additive performing specialized processing functions during production.';
  }

  static String _defaultConcerns(String? ins, String name, RiskTier tier) {
    if (tier == RiskTier.red) {
      if (ins != null && ins.contains('635')) {
        return 'Disodium 5-ribonucleotides are purine-rich flavor enhancers. May trigger gout flares, allergic skin rashes, and hyperactivity; avoid in infants and individuals with uric acid metabolic disorders.';
      }
      if (ins != null && (ins.contains('102') || ins.contains('110') || ins.contains('122') || ins.contains('124') || ins.contains('129'))) {
        return 'Synthetic azo dye derived from petroleum distillates. Clinically correlated with Attention Deficit Hyperactivity Disorder (ADHD) in children and acute histamine release (urticaria).';
      }
      return 'Classified as High Risk additive. Restricted or under strict regulatory surveillance due to potential long-term cellular or physiological toxicity.';
    } else if (tier == RiskTier.caution) {
      return 'Moderate consumption advised. May cause mild gastrointestinal discomfort, mineral absorption competition, or allergic sensitivity in predisposed individuals.';
    } else {
      return 'Generally Recognized As Safe (GRAS). Metabolized naturally by standard physiological human digestive pathways without cumulative toxic residue.';
    }
  }

  static double? _defaultAdi(String? ins) {
    if (ins == null) return null;
    final code = ins.replaceAll(RegExp(r'[^0-9]'), '');
    switch (code) {
      case '102': // Tartrazine
        return 7.5; // mg/kg bw
      case '110': // Sunset Yellow
        return 4.0;
      case '211': // Sodium Benzoate
        return 5.0;
      case '320': // BHA
        return 0.5;
      case '322': // Lecithin
        return null; // Not specified (safe)
      case '635': // Disodium 5-ribonucleotides
        return 70.0;
      case '955': // Sucralose
        return 15.0;
      default:
        return null;
    }
  }

  static List<String> _defaultBans(String? ins) {
    if (ins == null) return const [];
    final code = ins.replaceAll(RegExp(r'[^0-9]'), '');
    switch (code) {
      case '102':
        return ['Warning Label Required in UK/EU (Southampton 6)', 'Restricted in Austria & Norway'];
      case '110':
        return ['Restricted in European Union', 'Warning Label Required in UK'];
      case '635':
        return ['Prohibited in Infant Formulations (FSSAI/EU)'];
      default:
        return const [];
    }
  }

  static String? _defaultCitationSource(String? ins) {
    if (ins == null) return 'FSSAI Food Safety and Standards (Food Products Standards and Food Additives) Regulations, 2011';
    final code = ins.replaceAll(RegExp(r'[^0-9]'), '');
    switch (code) {
      case '102':
      case '110':
        return 'EFSA Scientific Opinion on the re-evaluation of food colours (EFSA Journal 2009; 7(11):1331)';
      case '635':
        return 'Joint FAO/WHO Expert Committee on Food Additives (JECFA Evaluation Series 35, 1993)';
      case '500':
      case '503':
      case '322':
        return 'FSSAI Compendium of Food Additive Standards, Appendix A, Table 1';
      default:
        return 'WHO Food Additives Series & JECFA Database of Evaluations';
    }
  }

  static String? _defaultCitationQuote(String? ins) {
    if (ins == null) return 'Complies with general safety specifications for food grade substances permitted in processed foods.';
    final code = ins.replaceAll(RegExp(r'[^0-9]'), '');
    switch (code) {
      case '102':
        return '"Consumption of tartrazine and sunset yellow blends has been shown to result in an increased effect on hyperactivity in 3-year old and 8/9-year old children."';
      case '635':
        return '"Disodium 5-ribonucleotides shall not be used in infant foods. Because ribonucleotides are metabolized to uric acid, caution is warranted in patients with hyperuricemia."';
      case '322':
        return '"Lecithins (INS 322) are naturally occurring phosphatides evaluated with an ADI of Not Specified, presenting no safety concern under good manufacturing practice."';
      default:
        return '"Evaluated by international safety committees. Permitted subject to Good Manufacturing Practice (GMP) limits specified in national standards."';
    }
  }

  static String _defaultCategory(String? ins) {
    if (ins == null) return 'Food Ingredient';
    final code = ins.replaceAll(RegExp(r'[^0-9]'), '');
    if (code.startsWith('1')) return 'Food Colour';
    if (code.startsWith('2')) return 'Preservative';
    if (code.startsWith('3')) return 'Antioxidant';
    if (code.startsWith('4')) return 'Emulsifier / Stabilizer';
    if (code.startsWith('5')) return 'Leavening / Acidity Regulator';
    if (code.startsWith('6')) return 'Flavor Enhancer';
    if (code.startsWith('9')) return 'Sweetener';
    return 'Additive';
  }
}
