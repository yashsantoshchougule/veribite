/// Precision safe consumption dosage and body-weight JECFA ADI scaling engine for Dart/Flutter.

import 'dart:math' as math;

const Set<String> sweetenerKeywords = {
  'sugar', 'glucose', 'sucrose', 'dextrose', 'syrup', 'maltodextrin',
  'honey', 'jaggery', 'fructose', 'invert sugar', 'caramel', 'molasses',
};

const Set<String> satFatKeywords = {
  'palm', 'palmolein', 'hydrogenated', 'vanaspati', 'butter',
  'shortening', 'ghee', 'coconut oil', 'lard', 'tallow',
};

Map<String, dynamic> normalizeAndImputeNutrition({
  required Map<String, dynamic> rawNutrition,
  List<String>? ingredientsOrdered,
  String? category,
  bool isBeverage = false,
}) {
  final ingredients = ingredientsOrdered ?? [];
  final top3Ingredients = ingredients.take(3).map((e) => e.toLowerCase()).toList();
  bool isEstimated = false;

  // 1. Salt to Sodium Normalization: Sodium (mg) = Salt (g) * 400
  final saltVal = rawNutrition['salt_g'];
  var sodiumVal = rawNutrition['sodium_mg'] ?? rawNutrition['sodium_mg_per_100g'];

  final double sodiumMg;
  if (sodiumVal == null && saltVal != null) {
    sodiumMg = (saltVal as num).toDouble() * 400.0;
  } else {
    sodiumMg = (sodiumVal as num?)?.toDouble() ?? 0.0;
  }

  // 2. Sugar Imputation
  var sugarVal = rawNutrition['sugar_g_per_100g'] ?? rawNutrition['total_sugars_g'];
  final double sugarG;
  if (sugarVal == null) {
    final hasSweetener = top3Ingredients.any((ing) => sweetenerKeywords.any((kw) => ing.contains(kw)));
    if (hasSweetener) {
      sugarG = 22.0;
      isEstimated = true;
    } else {
      sugarG = 0.0;
    }
  } else {
    sugarG = (sugarVal as num).toDouble();
  }

  // 3. Saturated Fat Imputation
  var satFatVal = rawNutrition['sat_fat_g_per_100g'] ?? rawNutrition['sat_fat_g'];
  final double satFatG;
  if (satFatVal == null) {
    final hasSatFat = top3Ingredients.any((ing) => satFatKeywords.any((kw) => ing.contains(kw)));
    if (hasSatFat) {
      satFatG = 12.0;
      isEstimated = true;
    } else {
      satFatG = 0.0;
    }
  } else {
    satFatG = (satFatVal as num).toDouble();
  }

  final energyKj = (rawNutrition['energy_kj'] as num?)?.toDouble() ?? 0.0;
  final fiberG = (rawNutrition['fiber_g'] as num?)?.toDouble() ?? 0.0;
  final proteinG = (rawNutrition['protein_g'] as num?)?.toDouble() ?? 0.0;
  final fruitVegNutPct = (rawNutrition['fruit_veg_nut_pct'] as num?)?.toDouble() ?? 0.0;
  final transFatG = (rawNutrition['trans_fat_g'] as num?)?.toDouble() ?? 0.0;

  final String? estimateBadge = isEstimated
      ? 'Estimated from Ingredient Order — Scan Nutrition Table for Exact Gram Ceiling'
      : null;

  return {
    'energy_kj': energyKj,
    'total_sugars_g': sugarG,
    'sugar_g_per_100g': sugarG,
    'sat_fat_g': satFatG,
    'sat_fat_g_per_100g': satFatG,
    'sodium_mg': sodiumMg,
    'sodium_mg_per_100g': sodiumMg,
    'fiber_g': fiberG,
    'protein_g': proteinG,
    'fruit_veg_nut_pct': fruitVegNutPct,
    'trans_fat_g': transFatG,
    'is_estimated': isEstimated,
    'estimate_badge': estimateBadge,
    'is_beverage': isBeverage,
  };
}

Map<String, dynamic> calculatePrescribedDosage({
  required Map<String, dynamic> nutrition,
  required List<Map<String, dynamic>> additives,
  double userWeightKg = 65.0,
  bool isChild = false,
  double? unitPieceWeightG,
  int? productScore,
  int? novaGrade,
}) {
  final sugar100g = ((nutrition['sugar_g_per_100g'] ?? nutrition['total_sugars_g'] ?? 0.0) as num).toDouble();
  final satFat100g = ((nutrition['sat_fat_g_per_100g'] ?? nutrition['sat_fat_g'] ?? 0.0) as num).toDouble();
  final sodium100g = ((nutrition['sodium_mg_per_100g'] ?? nutrition['sodium_mg'] ?? 0.0) as num).toDouble();

  final sugarPerG = math.max(sugar100g / 100.0, 0.0001);
  final satFatPerG = math.max(satFat100g / 100.0, 0.0001);
  final sodiumPerG = math.max(sodium100g / 100.0, 0.0001);

  final portionSugar = 5.0 / sugarPerG;
  final portionSatFat = 4.0 / satFatPerG;
  final portionSodium = 400.0 / sodiumPerG;

  String limitingFactor = 'Sugar';
  double baseMacroPortion = portionSugar;

  if (portionSatFat < baseMacroPortion) {
    baseMacroPortion = portionSatFat;
    limitingFactor = 'Saturated Fat';
  }
  if (portionSodium < baseMacroPortion) {
    baseMacroPortion = portionSodium;
    limitingFactor = 'Sodium';
  }

  // 2. Body-Weight Scaling (65 kg baseline)
  final weightRatio = math.max(userWeightKg, 1.0) / 65.0;
  final scaledPortion = baseMacroPortion * weightRatio;

  // 3. Additive JECFA ADI Constraint
  double adiPortionMin = double.infinity;
  String? adiLimitingAdditive;

  for (final a in additives) {
    final adi = a['jecfa_adi_mg_kg'];
    if (adi != null && (adi as num).toDouble() > 0.0) {
      final defaultConc = (a['default_conc_mg_per_g'] as num?)?.toDouble() ?? 0.1;
      final conc = math.max(defaultConc, 0.0001);
      final aPortion = ((adi as num).toDouble() * userWeightKg * 0.50) / conc;
      if (aPortion < adiPortionMin) {
        adiPortionMin = aPortion;
        adiLimitingAdditive = a['primary_name'] ?? a['ins_code'];
      }
    }
  }

  double finalUnclampedPortion = scaledPortion;
  if (adiPortionMin < scaledPortion) {
    finalUnclampedPortion = adiPortionMin;
    limitingFactor = 'Additive ADI ($adiLimitingAdditive)';
  }

  // Clamp single snack to max 150g
  final clampedPortion = math.min(finalUnclampedPortion, 150.0);
  final safePortionGrams = clampedPortion.round();

  // 4. Safe Pieces
  int? safePieces;
  if (unitPieceWeightG != null && unitPieceWeightG > 0) {
    safePieces = (clampedPortion / unitPieceWeightG).floor();
  }

  // 5. 4-Tier Frequency Schedule & Child Hyperactivity Override
  final hasRedAdditive = additives.any((a) {
    final tier = a['risk_tier']?.toString().toUpperCase();
    final redCap = a['triggers_red_cap'];
    return tier == 'RED' || redCap == 1 || redCap == true;
  });
  final transFat = ((nutrition['trans_fat_g'] ?? 0.0) as num).toDouble();

  final childHyperactiveAdditives = additives.where((a) {
    final flag = a['child_hyperactivity_flag'];
    return flag == 1 || flag == true;
  }).toList();

  String frequencySchedule = 'Daily Safe';
  String? frequencyWarning;

  if (isChild && childHyperactiveAdditives.isNotEmpty) {
    final codes = childHyperactiveAdditives.map((a) => 'INS ${a['ins_code']}').join(', ');
    frequencySchedule = 'Complete Avoidance Recommended for Children';
    frequencyWarning =
        'Contains Synthetic Azo Dye $codes (Known to cause hyperactivity and attention deficit in children per Southampton & EFSA)';
  } else if (hasRedAdditive || transFat > 0.2) {
    frequencySchedule = 'Once a Month / Rare Treat';
    if (hasRedAdditive) {
      frequencyWarning = 'Contains Red-Tier toxic additives; frequent consumption carries chronic toxicity risks.';
    } else {
      frequencyWarning = 'High trans fat density exceeds WHO threshold.';
    }
  } else if ((productScore != null && productScore < 50) || (novaGrade == 4) || (sugar100g > 15.0 || satFat100g > 5.0)) {
    frequencySchedule = 'Strict 1–2x Per Week Cap';
  } else if ((productScore != null && productScore < 75) || (novaGrade == 3)) {
    frequencySchedule = '3–4x Per Week';
  } else {
    frequencySchedule = 'Daily Safe';
  }

  return {
    'safe_portion_grams': safePortionGrams,
    'safe_pieces': safePieces,
    'limiting_factor': limitingFactor,
    'frequency_schedule': frequencySchedule,
    'frequency_warning': frequencyWarning,
    'base_macro_portion': double.parse(baseMacroPortion.toStringAsFixed(2)),
    'user_weight_kg': userWeightKg,
  };
}

