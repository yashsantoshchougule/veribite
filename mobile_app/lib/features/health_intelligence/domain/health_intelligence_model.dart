import 'dart:convert';

/// High-level domain of product for health classification
enum ProductCategoryDomain {
  standardFood,
  ayurvedicHerbalTonic,
  energyFunctionalDrink,
  nutraceuticalSupplement,
  otcDigestiveWellness;

  String toDbString() {
    switch (this) {
      case ProductCategoryDomain.standardFood:
        return 'standard_food';
      case ProductCategoryDomain.ayurvedicHerbalTonic:
        return 'ayurvedic_herbal_tonic';
      case ProductCategoryDomain.energyFunctionalDrink:
        return 'energy_functional_drink';
      case ProductCategoryDomain.nutraceuticalSupplement:
        return 'nutraceutical_supplement';
      case ProductCategoryDomain.otcDigestiveWellness:
        return 'otc_digestive_wellness';
    }
  }

  static ProductCategoryDomain fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'ayurvedic_herbal_tonic':
      case 'ayurvedic':
      case 'herbal':
      case 'unani':
        return ProductCategoryDomain.ayurvedicHerbalTonic;
      case 'energy_functional_drink':
      case 'energy_drink':
      case 'functional_drink':
        return ProductCategoryDomain.energyFunctionalDrink;
      case 'nutraceutical_supplement':
      case 'supplement':
      case 'nutraceutical':
      case 'protein_powder':
        return ProductCategoryDomain.nutraceuticalSupplement;
      case 'otc_digestive_wellness':
      case 'digestive':
      case 'otc':
        return ProductCategoryDomain.otcDigestiveWellness;
      default:
        return ProductCategoryDomain.standardFood;
    }
  }

  String get displayName {
    switch (this) {
      case ProductCategoryDomain.standardFood:
        return 'Standard Packaged Food';
      case ProductCategoryDomain.ayurvedicHerbalTonic:
        return 'Ayurvedic / Herbal Tonic';
      case ProductCategoryDomain.energyFunctionalDrink:
        return 'Energy & Functional Drink';
      case ProductCategoryDomain.nutraceuticalSupplement:
        return 'Nutraceutical & Supplement';
      case ProductCategoryDomain.otcDigestiveWellness:
        return 'Digestive & Wellness Formulation';
    }
  }
}

/// Active botanical alkaloid, stimulant, or pharmacological compound
class BioactiveCompound {
  final String name; // e.g., "Senna (Cassia angustifolia / Sennosides)"
  final String botanicalOrChemicalName;
  final String functionCategory; // e.g., "Stimulant Laxative", "CNS Stimulant", "Bitter Botanical"
  final String riskLevel; // 'low', 'moderate', 'high', 'caution_chronic_use'
  final String physiologicalEffect; // Plain English mechanism of action
  final bool triggersChronicUseWarning;

  const BioactiveCompound({
    required this.name,
    this.botanicalOrChemicalName = '',
    required this.functionCategory,
    this.riskLevel = 'low',
    required this.physiologicalEffect,
    this.triggersChronicUseWarning = false,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'botanical_chemical_name': botanicalOrChemicalName,
        'function_category': functionCategory,
        'risk_level': riskLevel,
        'physiological_effect': physiologicalEffect,
        'triggers_chronic_use_warning': triggersChronicUseWarning,
      };

  factory BioactiveCompound.fromJson(Map<String, dynamic> json) {
    return BioactiveCompound(
      name: json['name']?.toString() ?? 'Botanical Compound',
      botanicalOrChemicalName: json['botanical_chemical_name']?.toString() ?? '',
      functionCategory: json['function_category']?.toString() ?? 'Active Compound',
      riskLevel: json['risk_level']?.toString() ?? 'low',
      physiologicalEffect: json['physiological_effect']?.toString() ?? '',
      triggersChronicUseWarning: json['triggers_chronic_use_warning'] == true ||
          json['risk_level'] == 'caution_chronic_use' ||
          json['risk_level'] == 'high',
    );
  }
}

/// Multi-system organ load breakdown
class OrganAndSystemImpact {
  final String? gutAndDigestion;
  final String? liverAndMetabolism;
  final String? kidneyAndElectrolytes;
  final String? cardiovascularAndNervous;

  const OrganAndSystemImpact({
    this.gutAndDigestion,
    this.liverAndMetabolism,
    this.kidneyAndElectrolytes,
    this.cardiovascularAndNervous,
  });

  Map<String, dynamic> toJson() => {
        if (gutAndDigestion != null) 'gut_and_digestion': gutAndDigestion,
        if (liverAndMetabolism != null) 'liver_and_metabolism': liverAndMetabolism,
        if (kidneyAndElectrolytes != null) 'kidney_and_electrolytes': kidneyAndElectrolytes,
        if (cardiovascularAndNervous != null) 'cardiovascular_and_nervous': cardiovascularAndNervous,
      };

  factory OrganAndSystemImpact.fromJson(Map<String, dynamic> json) {
    return OrganAndSystemImpact(
      gutAndDigestion: json['gut_and_digestion']?.toString(),
      liverAndMetabolism: json['liver_and_metabolism']?.toString(),
      kidneyAndElectrolytes: json['kidney_and_electrolytes']?.toString(),
      cardiovascularAndNervous: json['cardiovascular_and_nervous']?.toString(),
    );
  }

  bool get hasAnyImpact =>
      gutAndDigestion != null ||
      liverAndMetabolism != null ||
      kidneyAndElectrolytes != null ||
      cardiovascularAndNervous != null;
}

/// Demographic contraindications and drug interactions
class ContraindicationsAndWarnings {
  final String? pregnancyBreastfeeding;
  final String? children;
  final String? diabetics;
  final String? sensitiveGutIbs;
  final String? drugInteractions;
  final String? chronicUseDuration; // e.g. "Strict maximum: 7-14 consecutive days"

  const ContraindicationsAndWarnings({
    this.pregnancyBreastfeeding,
    this.children,
    this.diabetics,
    this.sensitiveGutIbs,
    this.drugInteractions,
    this.chronicUseDuration,
  });

  Map<String, dynamic> toJson() => {
        if (pregnancyBreastfeeding != null) 'pregnancy_breastfeeding': pregnancyBreastfeeding,
        if (children != null) 'children': children,
        if (diabetics != null) 'diabetics': diabetics,
        if (sensitiveGutIbs != null) 'sensitive_gut_ibs': sensitiveGutIbs,
        if (drugInteractions != null) 'drug_interactions': drugInteractions,
        if (chronicUseDuration != null) 'chronic_use_duration': chronicUseDuration,
      };

  factory ContraindicationsAndWarnings.fromJson(Map<String, dynamic> json) {
    return ContraindicationsAndWarnings(
      pregnancyBreastfeeding: json['pregnancy_breastfeeding']?.toString(),
      children: json['children']?.toString(),
      diabetics: json['diabetics']?.toString(),
      sensitiveGutIbs: json['sensitive_gut_ibs']?.toString(),
      drugInteractions: json['drug_interactions']?.toString(),
      chronicUseDuration: json['chronic_use_duration']?.toString(),
    );
  }

  bool get hasAnyWarning =>
      pregnancyBreastfeeding != null ||
      children != null ||
      diabetics != null ||
      sensitiveGutIbs != null ||
      drugInteractions != null ||
      chronicUseDuration != null;
}

/// Marketing claim vs. evidence-based medical consensus
class ClaimVsClinicalReality {
  final String claim; // e.g. "Purifies blood & clears skin overnight"
  final String reality; // e.g. "Traditional marketing term. Scale loss is due to Senna laxative fluid/stool clearance, not toxin elimination."
  final String evidenceLevel; // 'misleading_marketing', 'unsubstantiated', 'partial_evidence', 'supported'

  const ClaimVsClinicalReality({
    required this.claim,
    required this.reality,
    this.evidenceLevel = 'misleading_marketing',
  });

  Map<String, dynamic> toJson() => {
        'claim': claim,
        'reality': reality,
        'evidence_level': evidenceLevel,
      };

  factory ClaimVsClinicalReality.fromJson(Map<String, dynamic> json) {
    return ClaimVsClinicalReality(
      claim: json['claim']?.toString() ?? '',
      reality: json['reality']?.toString() ?? '',
      evidenceLevel: json['evidence_level']?.toString() ?? 'misleading_marketing',
    );
  }
}

/// Comprehensive 12+ Extended Nutritional Profile
class ExtendedNutrients {
  final double addedSugarsG;
  final double dietaryFiberG;
  final double proteinG;
  final double carbsG;
  final double transFatG;
  final double totalFatG;
  final double unsaturatedFatG;
  final double cholesterolMg;
  final double caffeineMg;
  final Map<String, String> vitaminsMinerals;
  final String? glycemicLoadEstimate; // 'Low (<= 10)', 'Medium (11-19)', 'High (>= 20)'

  const ExtendedNutrients({
    this.addedSugarsG = 0.0,
    this.dietaryFiberG = 0.0,
    this.proteinG = 0.0,
    this.carbsG = 0.0,
    this.transFatG = 0.0,
    this.totalFatG = 0.0,
    this.unsaturatedFatG = 0.0,
    this.cholesterolMg = 0.0,
    this.caffeineMg = 0.0,
    this.vitaminsMinerals = const {},
    this.glycemicLoadEstimate,
  });

  Map<String, dynamic> toJson() => {
        'added_sugars_g': addedSugarsG,
        'dietary_fiber_g': dietaryFiberG,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'trans_fat_g': transFatG,
        'total_fat_g': totalFatG,
        'unsaturated_fat_g': unsaturatedFatG,
        'cholesterol_mg': cholesterolMg,
        'caffeine_mg': caffeineMg,
        'vitamins_minerals': vitaminsMinerals,
        if (glycemicLoadEstimate != null) 'glycemic_load_estimate': glycemicLoadEstimate,
      };

  factory ExtendedNutrients.fromJson(Map<String, dynamic> json) {
    return ExtendedNutrients(
      addedSugarsG: (json['added_sugars_g'] as num?)?.toDouble() ?? 0.0,
      dietaryFiberG: (json['dietary_fiber_g'] as num?)?.toDouble() ?? 0.0,
      proteinG: (json['protein_g'] as num?)?.toDouble() ?? 0.0,
      carbsG: (json['carbs_g'] as num?)?.toDouble() ?? 0.0,
      transFatG: (json['trans_fat_g'] as num?)?.toDouble() ?? 0.0,
      totalFatG: (json['total_fat_g'] as num?)?.toDouble() ?? 0.0,
      unsaturatedFatG: (json['unsaturated_fat_g'] as num?)?.toDouble() ?? 0.0,
      cholesterolMg: (json['cholesterol_mg'] as num?)?.toDouble() ?? 0.0,
      caffeineMg: (json['caffeine_mg'] as num?)?.toDouble() ?? 0.0,
      vitaminsMinerals: (json['vitamins_minerals'] is Map)
          ? Map<String, String>.from((json['vitamins_minerals'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())))
          : const {},
      glycemicLoadEstimate: json['glycemic_load_estimate']?.toString(),
    );
  }
}

/// Rich, product-specific health intelligence retrieved via Internet Grounding or offline engine
class HealthIntelligence {
  final ProductCategoryDomain domain;
  final ExtendedNutrients extendedNutrients;
  final List<BioactiveCompound> bioactiveCompounds;
  final OrganAndSystemImpact organImpact;
  final ContraindicationsAndWarnings contraindications;
  final List<ClaimVsClinicalReality> claimsVsReality;
  final List<String> internetGroundedSources;
  final List<String> safetyAdvisories;
  final bool isGrounded;
  final String? clinicalSummary;

  const HealthIntelligence({
    this.domain = ProductCategoryDomain.standardFood,
    this.extendedNutrients = const ExtendedNutrients(),
    this.bioactiveCompounds = const [],
    this.organImpact = const OrganAndSystemImpact(),
    this.contraindications = const ContraindicationsAndWarnings(),
    this.claimsVsReality = const [],
    this.internetGroundedSources = const [],
    this.safetyAdvisories = const [],
    this.isGrounded = false,
    this.clinicalSummary,
  });

  bool get hasBioactiveRisk =>
      bioactiveCompounds.any((c) => c.triggersChronicUseWarning || c.riskLevel == 'high' || c.riskLevel == 'caution_chronic_use');

  bool get isNonStandardFood => domain != ProductCategoryDomain.standardFood;

  Map<String, dynamic> toJson() => {
        'domain': domain.toDbString(),
        'extended_nutrients': extendedNutrients.toJson(),
        'bioactive_compounds': bioactiveCompounds.map((c) => c.toJson()).toList(),
        'organ_impact': organImpact.toJson(),
        'contraindications': contraindications.toJson(),
        'claims_vs_reality': claimsVsReality.map((c) => c.toJson()).toList(),
        'internet_grounded_sources': internetGroundedSources,
        'safety_advisories': safetyAdvisories,
        'is_grounded': isGrounded,
        if (clinicalSummary != null) 'clinical_summary': clinicalSummary,
      };

  factory HealthIntelligence.fromJson(Map<String, dynamic> json) {
    return HealthIntelligence(
      domain: ProductCategoryDomain.fromString(json['domain']?.toString()),
      extendedNutrients: json['extended_nutrients'] is Map
          ? ExtendedNutrients.fromJson(Map<String, dynamic>.from(json['extended_nutrients'] as Map))
          : const ExtendedNutrients(),
      bioactiveCompounds: (json['bioactive_compounds'] as List?)
              ?.map((e) => BioactiveCompound.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      organImpact: json['organ_impact'] is Map
          ? OrganAndSystemImpact.fromJson(Map<String, dynamic>.from(json['organ_impact'] as Map))
          : const OrganAndSystemImpact(),
      contraindications: json['contraindications'] is Map
          ? ContraindicationsAndWarnings.fromJson(Map<String, dynamic>.from(json['contraindications'] as Map))
          : const ContraindicationsAndWarnings(),
      claimsVsReality: (json['claims_vs_reality'] as List?)
              ?.map((e) => ClaimVsClinicalReality.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          const [],
      internetGroundedSources: (json['internet_grounded_sources'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      safetyAdvisories: (json['safety_advisories'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      isGrounded: json['is_grounded'] == true,
      clinicalSummary: json['clinical_summary']?.toString(),
    );
  }

  static HealthIntelligence? fromJsonString(String? jsonString) {
    if (jsonString == null || jsonString.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) {
        return HealthIntelligence.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }
}

