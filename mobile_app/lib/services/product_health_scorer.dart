import 'dart:math' as math;
import '../features/health_intelligence/domain/health_intelligence_model.dart';

/// Normalized nutritional values per 100g / 100ml
class NormalizedNutrients {
  final double? energyKcal;
  final double? sugarsG;
  final double? saturatedFatG;
  final double? totalFatG;
  final double? sodiumMg;
  final double? proteinG;
  final double? fiberG;

  const NormalizedNutrients({
    this.energyKcal,
    this.sugarsG,
    this.saturatedFatG,
    this.totalFatG,
    this.sodiumMg,
    this.proteinG,
    this.fiberG,
  });

  bool get hasNutritionalValues =>
      energyKcal != null ||
      sugarsG != null ||
      saturatedFatG != null ||
      totalFatG != null ||
      sodiumMg != null ||
      proteinG != null ||
      fiberG != null;
}

/// Dynamic Health & Safety Score Result (0–100) with complete mathematical transparency
class HealthScoreResult {
  final int? score;
  final String verdictTag;
  final bool isRedCapped;
  final String? redCapReason;
  final bool isIngredientOnlyScore;
  final bool hasSufficientData;
  final bool isDataIncomplete;
  final String scoreBreakdownSummary;
  final Map<String, dynamic> breakdownDetails;

  const HealthScoreResult({
    required this.score,
    required this.verdictTag,
    required this.isRedCapped,
    this.redCapReason,
    required this.isIngredientOnlyScore,
    required this.hasSufficientData,
    this.isDataIncomplete = false,
    required this.scoreBreakdownSummary,
    required this.breakdownDetails,
  });

  factory HealthScoreResult.insufficientData() {
    return const HealthScoreResult(
      score: null,
      verdictTag: 'Insufficient Data',
      isRedCapped: false,
      redCapReason: null,
      isIngredientOnlyScore: false,
      hasSufficientData: false,
      isDataIncomplete: true,
      scoreBreakdownSummary: 'Insufficient Data — Capture Nutrition Label to score',
      breakdownDetails: {},
    );
  }
}

/// Dedicated, real-time scientific scoring engine for VeriBite.
/// Normalizes keys across Open Food Facts, Gemini Vision, and on-device OCR.
/// Evaluates products deterministically on a 0–100 scale from 100 base points.
class ProductHealthScorer {
  /// Extracts and normalizes nutrient values from heterogeneous dictionary sources
  static NormalizedNutrients normalizeNutrients(Map<dynamic, dynamic>? rawNutrition) {
    if (rawNutrition == null || rawNutrition.isEmpty) {
      return const NormalizedNutrients();
    }

    // 1. Energy in Kcal (converts from kJ if kcal is not explicitly present)
    double? energyKcal = _findDouble(rawNutrition, [
      'energy-kcal_100g',
      'energy_kcal',
      'calories',
      'kcal',
      'calories_per_100g',
    ]);
    if (energyKcal == null) {
      final energyKj = _findDouble(rawNutrition, ['energy_kj', 'energy-kj_100g', 'energy_kj_per_100g']);
      if (energyKj != null && energyKj > 0) {
        energyKcal = energyKj / 4.184;
      }
    }

    // 2. Sugars in grams
    final sugarsG = _findDouble(rawNutrition, [
      'sugars_100g',
      'sugar_g',
      'total_sugars',
      'sugars',
      'sugar_g_per_100g',
      'total_sugars_g',
    ]);

    // 3. Saturated Fat in grams
    final saturatedFatG = _findDouble(rawNutrition, [
      'saturated-fat_100g',
      'saturated_fat_g',
      'sat_fat',
      'saturated_fat',
      'sat_fat_g_per_100g',
    ]);

    // 4. Total Fat in grams
    double? totalFatG = _findDouble(rawNutrition, [
      'fat_100g',
      'total-fat_100g',
      'total_fat_g',
      'fat',
      'total_fat',
      'fat_g_per_100g',
      'total_fat_g_per_100g',
    ]);

    // Biochemical Floor: Total Fat >= Saturated Fat
    if (saturatedFatG != null) {
      if (totalFatG == null || totalFatG < saturatedFatG) {
        totalFatG = saturatedFatG;
      }
    }

    // 5. Sodium in mg (converts from grams if <= 15.0 or converts from salt_100g * 400)
    double? sodiumMg = _findDouble(rawNutrition, [
      'sodium_mg',
      'sodium_mg_per_100g',
      'sodium',
    ]);
    if (sodiumMg == null) {
      final rawSodium100g = _findDouble(rawNutrition, ['sodium_100g', 'sodium_g']);
      if (rawSodium100g != null) {
        // Values <= 15.0 are in grams per 100g (e.g. 0.25g = 250mg)
        sodiumMg = rawSodium100g <= 15.0 ? rawSodium100g * 1000.0 : rawSodium100g;
      }
    }
    if (sodiumMg == null) {
      final saltG = _findDouble(rawNutrition, ['salt_100g', 'salt_g', 'salt']);
      if (saltG != null) {
        sodiumMg = saltG * 400.0;
      }
    }

    // 6. Protein in grams
    final proteinG = _findDouble(rawNutrition, [
      'proteins_100g',
      'protein_g',
      'protein',
      'proteins',
    ]);

    // 7. Dietary Fiber in grams
    final fiberG = _findDouble(rawNutrition, [
      'fiber_100g',
      'dietary_fiber_g',
      'fiber',
      'dietary_fiber',
    ]);

    // Biochemical Floor: Energy Kcal >= Atwater minimum
    if (energyKcal != null && (proteinG != null || sugarsG != null || totalFatG != null)) {
      final p = proteinG ?? 0.0;
      final c = sugarsG ?? 0.0;
      final f = totalFatG ?? 0.0;
      final atwaterMin = (p * 4.0) + (c * 4.0) + (f * 9.0);
      if (energyKcal < atwaterMin && atwaterMin > 0) {
        energyKcal = atwaterMin;
      }
    }

    return NormalizedNutrients(
      energyKcal: energyKcal,
      sugarsG: sugarsG,
      saturatedFatG: saturatedFatG,
      totalFatG: totalFatG,
      sodiumMg: sodiumMg,
      proteinG: proteinG,
      fiberG: fiberG,
    );
  }

  /// Calculates dynamic health score from 100 base points
  static HealthScoreResult calculate({
    Map<dynamic, dynamic>? nutrition,
    List<dynamic>? additives,
    List<dynamic>? ingredients,
    int? novaGrade,
    bool? redCapTriggered,
    HealthIntelligence? healthIntelligence,
    String? productName,
    String? category,
  }) {
    final normalized = normalizeNutrients(nutrition);
    final additiveList = _normalizeAdditives(additives);
    final ingredientList = _normalizeIngredients(ingredients);

    final bool hasMacroData = (normalized.energyKcal != null && normalized.energyKcal! > 0) ||
        (normalized.totalFatG != null && normalized.totalFatG! > 0) ||
        (normalized.sugarsG != null && normalized.sugarsG! > 0) ||
        (normalized.proteinG != null && normalized.proteinG! > 0) ||
        (normalized.sodiumMg != null && normalized.sodiumMg! > 0);

    final nameLower = '${productName ?? ''} ${category ?? ''}'.toLowerCase();
    final bool isZeroCalorieDrink = nameLower.contains('water') ||
        nameLower.contains('sparkling water') ||
        nameLower.contains('soda water') ||
        nameLower.contains('green tea') ||
        nameLower.contains('black tea') ||
        nameLower.contains('herbal tea') ||
        nameLower.contains('black coffee') ||
        nameLower.contains('zero calorie') ||
        nameLower.contains('diet');

    final bool hasNutrition = normalized.hasNutritionalValues && (hasMacroData || isZeroCalorieDrink);
    final bool hasIngredientsOrAdditives = additiveList.isNotEmpty || ingredientList.isNotEmpty;

    // RULE 3: Handle completely missing data honestly
    if (!hasNutrition && !hasIngredientsOrAdditives) {
      return HealthScoreResult.insufficientData();
    }

    // Check strict Red-tier additives
    final bool hasRedAdditive = additiveList.any((a) {
      final tier = a['risk_tier']?.toString().toUpperCase();
      final redCap = a['triggers_red_cap'];
      return tier == 'RED' || redCap == 1 || redCap == true;
    });

    // Check bioactive pharmacological risks & chronic stimulant/laxative warnings
    bool hasBioactiveRisk = false;
    String? bioactiveReason;
    int bioactivePenalty = 0;

    if (healthIntelligence != null) {
      for (final compound in healthIntelligence.bioactiveCompounds) {
        if (compound.triggersChronicUseWarning ||
            compound.riskLevel == 'caution_chronic_use' ||
            compound.riskLevel == 'high') {
          hasBioactiveRisk = true;
          bioactivePenalty = math.max(bioactivePenalty, 25);
          bioactiveReason = 'Clinical Caution: ${compound.name} (${compound.functionCategory})';
        }
      }
    }

    final bool isRedCapped = (redCapTriggered == true) || hasRedAdditive || hasBioactiveRisk;
    final String? redCapReason = hasBioactiveRisk
        ? bioactiveReason
        : (hasRedAdditive
            ? 'High-Risk Synthetic Additive Detected'
            : (isRedCapped ? 'Strict Toxicology Red-Cap Triggered' : null));

    // RULE 3b: If nutrition table is missing but ingredients/additives exist
    if (!hasNutrition && hasIngredientsOrAdditives) {
      return _calculateIngredientOnlyScore(
        additives: additiveList,
        ingredients: ingredientList,
        novaGrade: novaGrade ?? (additiveList.isNotEmpty ? 4 : 3),
        isRedCapped: isRedCapped,
        redCapReason: redCapReason,
        bioactivePenalty: bioactivePenalty,
      );
    }

    // 1. BASE: 100 Points
    double currentScore = 100.0;
    final breakdown = <String, dynamic>{'base': 100};
    final summaryTokens = <String>['Base 100'];

    // 2. NUTRITIONAL PENALTIES (Max -55 pts)
    final sugarVal = normalized.sugarsG ?? 0.0;
    final sodiumVal = normalized.sodiumMg ?? 0.0;
    final satFatVal = normalized.saturatedFatG ?? 0.0;
    final kcalVal = normalized.energyKcal ?? 0.0;

    // Sugar Penalty: 0g = 0; scales linearly to -20 at >= 22.5g/100g (UK FSA / FSSAI threshold)
    final double sugarPenalty = (sugarVal <= 0.0)
        ? 0.0
        : (sugarVal / 22.5 * 20.0).clamp(0.0, 20.0);

    // Sodium Penalty: <= 120mg = 0; scales linearly to -15 at >= 600mg/100g
    final double sodiumPenalty = (sodiumVal <= 120.0)
        ? 0.0
        : ((sodiumVal - 120.0) / (600.0 - 120.0) * 15.0).clamp(0.0, 15.0);

    // Saturated Fat Penalty: <= 1.5g = 0; scales linearly to -12 at >= 5.0g/100g
    final double satFatPenalty = (satFatVal <= 1.5)
        ? 0.0
        : ((satFatVal - 1.5) / (5.0 - 1.5) * 12.0).clamp(0.0, 12.0);

    // Calorie Density Penalty: <= 150 kcal = 0; scales linearly to -8 at >= 450 kcal/100g
    final double caloriePenalty = (kcalVal <= 150.0)
        ? 0.0
        : ((kcalVal - 150.0) / (450.0 - 150.0) * 8.0).clamp(0.0, 8.0);

    final double rawNutritionalPenalties = sugarPenalty + sodiumPenalty + satFatPenalty + caloriePenalty;
    final double cappedNutritionalPenalties = math.min(55.0, rawNutritionalPenalties);

    currentScore -= cappedNutritionalPenalties;
    breakdown['sugar_penalty'] = -sugarPenalty.round();
    breakdown['sodium_penalty'] = -sodiumPenalty.round();
    breakdown['sat_fat_penalty'] = -satFatPenalty.round();
    breakdown['calorie_penalty'] = -caloriePenalty.round();
    breakdown['total_nutritional_penalties'] = -cappedNutritionalPenalties.round();

    if (sugarPenalty >= 1.0) summaryTokens.add('Sugar: -${sugarPenalty.round()}');
    if (sodiumPenalty >= 1.0) summaryTokens.add('Sodium: -${sodiumPenalty.round()}');
    if (satFatPenalty >= 1.0) summaryTokens.add('Sat Fat: -${satFatPenalty.round()}');
    if (caloriePenalty >= 1.0) summaryTokens.add('Calories: -${caloriePenalty.round()}');

    // 3. NUTRITIONAL REWARDS (Max +15 pts)
    final proteinVal = normalized.proteinG ?? 0.0;
    final fiberVal = normalized.fiberG ?? 0.0;

    // Protein Bonus: +1 pt per 1.5g protein (up to +8 pts; capped at +4 pts if high sugar/satfat)
    final double rawProteinBonus = (proteinVal / 1.5).floorToDouble();
    final double maxProteinAllowed = (sugarVal > 15.0 || satFatVal > 5.0) ? 4.0 : 8.0;
    final double proteinBonus = math.min(maxProteinAllowed, rawProteinBonus);

    // Fiber Bonus: +1 pt per 1.0g dietary fiber (up to +7 pts)
    final double fiberBonus = math.min(7.0, (fiberVal / 1.0).floorToDouble());

    final double totalNutritionalRewards = math.min(15.0, proteinBonus + fiberBonus);
    currentScore += totalNutritionalRewards;

    breakdown['protein_bonus'] = proteinBonus.round();
    breakdown['fiber_bonus'] = fiberBonus.round();
    breakdown['total_nutritional_rewards'] = totalNutritionalRewards.round();

    if (proteinBonus >= 1.0) summaryTokens.add('Protein: +${proteinBonus.round()}');
    if (fiberBonus >= 1.0) summaryTokens.add('Fiber: +${fiberBonus.round()}');

    // 4. ADDITIVE & PROCESSING PENALTIES (Max -40 pts)
    int additivePenalty = 0;
    int redCount = 0;
    int amberCount = 0;
    int greenCount = 0;

    for (final add in additiveList) {
      final tier = add['risk_tier']?.toString().toUpperCase();
      final triggersRed = add['triggers_red_cap'] == 1 || add['triggers_red_cap'] == true;
      if (tier == 'RED' || triggersRed) {
        additivePenalty += 12;
        redCount++;
      } else if (tier == 'CAUTION' || tier == 'MODERATE' || tier == 'AMBER') {
        additivePenalty += 6;
        amberCount++;
      } else {
        additivePenalty += 2;
        greenCount++;
      }
    }

    final int resolvedNova = novaGrade ?? _detectNova(additiveList, ingredientList);
    int novaAdjustment = 0;
    switch (resolvedNova) {
      case 1:
        novaAdjustment = 5; // Reward unprocessed whole foods
        break;
      case 2:
        novaAdjustment = 0;
        break;
      case 3:
        novaAdjustment = -5;
        break;
      case 4:
      default:
        novaAdjustment = -12; // Ultra-processed formulation penalty
        break;
    }

    final double totalProcessingPenalty = math.min(40.0, (additivePenalty - novaAdjustment).toDouble());
    currentScore -= totalProcessingPenalty;

    breakdown['additive_penalty'] = -additivePenalty;
    breakdown['red_additives_count'] = redCount;
    breakdown['amber_additives_count'] = amberCount;
    breakdown['green_additives_count'] = greenCount;
    breakdown['nova_grade'] = resolvedNova;
    breakdown['nova_adjustment'] = novaAdjustment;
    breakdown['total_processing_penalty'] = -totalProcessingPenalty.round();

    if (additiveList.isNotEmpty) {
      summaryTokens.add('Additives (${additiveList.length}): -$additivePenalty');
    }
    summaryTokens.add('NOVA $resolvedNova: ${novaAdjustment >= 0 ? "+$novaAdjustment" : "$novaAdjustment"}');

    // 4b. Bioactive & Chronic Pharmacological Risks (e.g. Senna, High Stimulants)
    if (bioactivePenalty > 0) {
      currentScore -= bioactivePenalty;
      breakdown['bioactive_penalty'] = -bioactivePenalty;
      summaryTokens.add('Bioactive Risk: -$bioactivePenalty');
    }

    // 5. CLAMPING & RED-CAP ENFORCEMENT (Clamp 5 to 98)
    int finalScore = currentScore.round().clamp(5, 98);

    if (isRedCapped) {
      if (finalScore > 39) {
        finalScore = 39;
        breakdown['red_cap_enforced'] = true;
        summaryTokens.add(hasBioactiveRisk ? 'Chronic Caution: Capped to 39' : 'Red-Cap: Capped to 39');
      } else {
        breakdown['red_cap_enforced'] = true;
        summaryTokens.add(hasBioactiveRisk ? 'Chronic Caution (≤39)' : 'Red-Tier Cap (≤39)');
      }
    }

    final String verdictTag = _deriveVerdictTag(finalScore, isRedCapped);
    final String summary = '${summaryTokens.join(' | ')} | Final Score: $finalScore';

    return HealthScoreResult(
      score: finalScore,
      verdictTag: verdictTag,
      isRedCapped: isRedCapped,
      redCapReason: redCapReason,
      isIngredientOnlyScore: false,
      hasSufficientData: true,
      scoreBreakdownSummary: summary,
      breakdownDetails: breakdown,
    );
  }

  /// Calculates Ingredient & Additive Safety Score when nutrition facts are absent
  static HealthScoreResult _calculateIngredientOnlyScore({
    required List<Map<String, dynamic>> additives,
    required List<String> ingredients,
    required int novaGrade,
    required bool isRedCapped,
    String? redCapReason,
    int bioactivePenalty = 0,
  }) {
    double score = 100.0;
    final tokens = <String>['Base 100 (Ingredient-Based)'];

    if (bioactivePenalty > 0) {
      score -= bioactivePenalty;
      tokens.add('Bioactive Risk: -$bioactivePenalty');
    }

    int addDeduction = 0;
    for (final add in additives) {
      final tier = add['risk_tier']?.toString().toUpperCase();
      final triggersRed = add['triggers_red_cap'] == 1 || add['triggers_red_cap'] == true;
      if (tier == 'RED' || triggersRed) {
        addDeduction += 12;
      } else if (tier == 'CAUTION' || tier == 'MODERATE' || tier == 'AMBER') {
        addDeduction += 6;
      } else {
        addDeduction += 2;
      }
    }
    score -= math.min(30.0, addDeduction.toDouble());
    if (additives.isNotEmpty) tokens.add('Additives: -$addDeduction');

    int novaAdj = 0;
    switch (novaGrade) {
      case 1:
        novaAdj = 5;
        break;
      case 2:
        novaAdj = 0;
        break;
      case 3:
        novaAdj = -5;
        break;
      case 4:
      default:
        novaAdj = -12;
        break;
    }
    score += novaAdj;
    tokens.add('NOVA $novaGrade: ${novaAdj >= 0 ? "+$novaAdj" : "$novaAdj"}');

    // Ingredient count penalty
    if (ingredients.length > 10) {
      score -= 5;
      tokens.add('Lengthy Ingredients: -5');
    }

    int finalScore = score.round().clamp(10, 70);
    if (isRedCapped) {
      if (finalScore > 39) {
        finalScore = 39;
        tokens.add('Red-Cap: Capped to 39');
      } else {
        tokens.add('Red-Tier Cap (≤39)');
      }
    }

    final summary = 'Scored from ingredients only — nutrition table not reported | ${tokens.join(' | ')} | Final Score: $finalScore';

    return HealthScoreResult(
      score: finalScore,
      verdictTag: _deriveVerdictTag(finalScore, isRedCapped),
      isRedCapped: isRedCapped,
      redCapReason: redCapReason,
      isIngredientOnlyScore: true,
      hasSufficientData: true,
      scoreBreakdownSummary: summary,
      breakdownDetails: {
        'is_ingredient_only': true,
        'additives_penalty': -addDeduction,
        'nova_adjustment': novaAdj,
      },
    );
  }

  static String _deriveVerdictTag(int score, bool isRedCapped) {
    if (isRedCapped || score <= 39) {
      return 'Toxic / Capped 🔴';
    } else if (score < 70) {
      return 'Caution 🟠';
    } else {
      return 'Nutri Safe 🟢';
    }
  }

  static int _detectNova(List<Map<String, dynamic>> additives, List<String> ingredients) {
    if (additives.length >= 2 || ingredients.length >= 6) {
      return 4;
    }
    if (additives.isNotEmpty || ingredients.length >= 3) {
      return 3;
    }
    if (ingredients.length > 1) {
      return 2;
    }
    return 1;
  }

  static double? _findDouble(Map<dynamic, dynamic> map, List<String> keys) {
    for (final key in keys) {
      if (map.containsKey(key)) {
        final val = map[key];
        if (val is num) {
          final d = val.toDouble();
          if (!d.isNaN && !d.isInfinite && d >= 0.0) return d;
        }
        if (val is String) {
          final cleaned = val.replaceAll(RegExp(r'[^0-9.]'), '');
          if (cleaned.isNotEmpty) {
            final parsed = double.tryParse(cleaned);
            if (parsed != null && !parsed.isNaN && !parsed.isInfinite && parsed >= 0.0) {
              return parsed;
            }
          }
        }
      }
    }
    return null;
  }

  static List<Map<String, dynamic>> _normalizeAdditives(List<dynamic>? rawAdditives) {
    if (rawAdditives == null) return [];
    final result = <Map<String, dynamic>>[];
    for (final item in rawAdditives) {
      if (item is Map) {
        result.add(Map<String, dynamic>.from(item));
      } else if (item is String && item.isNotEmpty) {
        result.add({
          'ins_code': item,
          'primary_name': item,
          'risk_tier': 'GREEN',
        });
      }
    }
    return result;
  }

  static List<String> _normalizeIngredients(List<dynamic>? rawIngredients) {
    if (rawIngredients == null) return [];
    return rawIngredients.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }
}
