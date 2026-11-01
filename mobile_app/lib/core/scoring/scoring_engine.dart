/// Deterministic Nutri-Score (0-100), NOVA, and 39/100 Hard Red Cap scoring engine.

int _getPoints(double value, List<double> thresholds) {
  for (int i = 0; i < thresholds.length; i++) {
    if (value <= thresholds[i]) {
      return i;
    }
  }
  return thresholds.length;
}

Map<String, int> computeNegativePoints(Map<String, double> nutrition, {bool isBeverage = false}) {
  final energyKj = nutrition['energy_kj'] ?? 0.0;
  final sugarsG = nutrition['total_sugars_g'] ?? nutrition['sugar_g_per_100g'] ?? 0.0;
  final satFatG = nutrition['sat_fat_g'] ?? nutrition['sat_fat_g_per_100g'] ?? 0.0;
  final sodiumMg = nutrition['sodium_mg'] ?? nutrition['sodium_mg_per_100g'] ?? 0.0;

  final List<double> eThresholds;
  final List<double> sThresholds;

  if (isBeverage) {
    eThresholds = [0, 30, 60, 90, 120, 150, 180, 210, 240, 270];
    sThresholds = [0.0, 1.5, 3.0, 4.5, 6.0, 7.5, 9.0, 10.5, 12.0, 13.5];
  } else {
    eThresholds = [335, 670, 1005, 1340, 1675, 2010, 2345, 2680, 3015, 3350];
    sThresholds = [4.5, 9.0, 13.5, 18.0, 22.5, 27.0, 31.5, 36.0, 40.5, 45.0];
  }

  final fatThresholds = [1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0, 10.0];
  final naThresholds = [90.0, 180.0, 270.0, 360.0, 450.0, 540.0, 630.0, 720.0, 810.0, 900.0];

  return {
    'energy_pts': _getPoints(energyKj, eThresholds),
    'sugar_pts': _getPoints(sugarsG, sThresholds),
    'sat_fat_pts': _getPoints(satFatG, fatThresholds),
    'sodium_pts': _getPoints(sodiumMg, naThresholds),
  };
}

Map<String, int> computePositivePoints(
  Map<String, double> nutrition,
  int negativePointsTotal, {
  bool isBeverage = false,
}) {
  final fvnPct = nutrition['fruit_veg_nut_pct'] ?? 0.0;
  final fiberG = nutrition['fiber_g'] ?? 0.0;
  final proteinG = nutrition['protein_g'] ?? 0.0;

  final int fvnPts;
  if (isBeverage) {
    fvnPts = fvnPct <= 40 ? 0 : (fvnPct <= 60 ? 2 : (fvnPct <= 80 ? 4 : 10));
  } else {
    fvnPts = fvnPct <= 40 ? 0 : (fvnPct <= 60 ? 1 : (fvnPct <= 80 ? 2 : 5));
  }

  final fiberPts = _getPoints(fiberG, [0.9, 1.9, 2.8, 3.7, 4.7]);
  final rawProteinPts = _getPoints(proteinG, [1.6, 3.2, 4.8, 6.4, 8.0]);

  // If N >= 11 and FVN < 80%, protein points are excluded
  final proteinPts = (negativePointsTotal < 11 || fvnPct >= 80.0) ? rawProteinPts : 0;

  return {
    'fvn_pts': fvnPts,
    'fiber_pts': fiberPts,
    'protein_pts': proteinPts,
  };
}

int computeBaseNutriscore(Map<String, double> nutrition, {bool isBeverage = false}) {
  final nPts = computeNegativePoints(nutrition, isBeverage: isBeverage);
  final nTotal = nPts.values.fold(0, (sum, val) => sum + val);

  final pPts = computePositivePoints(nutrition, nTotal, isBeverage: isBeverage);
  final pTotal = pPts.values.fold(0, (sum, val) => sum + val);

  final rawS = nTotal - pTotal;
  final score = (100.0 - ((rawS + 15.0) * 100.0 / 55.0)).round();
  return score.clamp(0, 100);
}

int classifyNovaGroup({
  required List<Map<String, dynamic>> additives,
  double transFatG = 0.0,
  int ingredientCount = 1,
  bool containsCosmeticAdditives = false,
  bool isCulinaryIngredient = false,
}) {
  if (isCulinaryIngredient) return 2;
  if (additives.isNotEmpty || transFatG > 0.0 || containsCosmeticAdditives) {
    return 4;
  }
  if (ingredientCount <= 1) return 1;
  return 3;
}

Map<String, dynamic> evaluateProductVerdict({
  required Map<String, double> nutrition,
  required List<Map<String, dynamic>> additives,
  bool isBeverage = false,
  int ingredientCount = 1,
  bool containsCosmeticAdditives = false,
  bool isCulinaryIngredient = false,
}) {
  final transFatG = nutrition['trans_fat_g'] ?? 0.0;
  final novaGrade = classifyNovaGroup(
    additives: additives,
    transFatG: transFatG,
    ingredientCount: ingredientCount,
    containsCosmeticAdditives: containsCosmeticAdditives,
    isCulinaryIngredient: isCulinaryIngredient,
  );

  final baseScore = computeBaseNutriscore(nutrition, isBeverage: isBeverage);

  final nCaution = additives.where((a) {
    final tier = a['risk_tier']?.toString().toUpperCase();
    return tier == 'CAUTION' || tier == 'MODERATE';
  }).length;

  final redAdditives = additives.where((a) {
    final tier = a['risk_tier']?.toString().toUpperCase();
    final redCap = a['triggers_red_cap'];
    return tier == 'RED' || redCap == 1 || redCap == true;
  }).toList();

  final nRed = redAdditives.length;
  final novaPenalty = (novaGrade == 4) ? 10 : 0;
  final netScore = baseScore - (8 * nCaution) - (20 * nRed) - novaPenalty;

  bool redCapTriggered = false;
  String? redCapReason;
  int finalScore;

  if (nRed > 0) {
    redCapTriggered = true;
    final names = redAdditives.map((a) => a['primary_name'] ?? a['ins_code'] ?? 'Unknown').join(', ');
    redCapReason = 'Red-Tier Additive Detected: $names';
    finalScore = netScore.clamp(0, 39);
  } else if (transFatG > 0.2) {
    redCapTriggered = true;
    redCapReason = 'Trans Fat Exceeds 0.2g (${transFatG.toStringAsFixed(2)}g per 100g)';
    finalScore = netScore.clamp(0, 39);
  } else {
    finalScore = netScore.clamp(0, 100);
  }

  return {
    'base_score': baseScore,
    'net_score': netScore,
    'final_score': finalScore,
    'nova_grade': novaGrade,
    'red_cap_triggered': redCapTriggered,
    'red_cap_reason': redCapReason,
    'n_caution': nCaution,
    'n_red': nRed,
  };
}

