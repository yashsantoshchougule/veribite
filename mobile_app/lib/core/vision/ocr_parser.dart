/// On-device OCR text parsing and specular glare detection for Dart/Flutter.
library;

Map<String, double?> parseOcrNutritionTable(String text) {
  final result = <String, double?>{
    'energy_kj': null,
    'total_sugars_g': null,
    'sat_fat_g': null,
    'trans_fat_g': null,
    'sodium_mg': null,
    'salt_g': null,
    'fiber_g': null,
    'protein_g': null,
  };

  // Energy
  final energyMatch = RegExp(r'(?:energy|calories?)\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*(kcal|kj)?', caseSensitive: false).firstMatch(text);
  if (energyMatch != null) {
    final val = double.parse(energyMatch.group(1)!);
    final unit = (energyMatch.group(2) ?? '').toLowerCase();
    result['energy_kj'] = (unit == 'kj') ? val : val * 4.184;
  }

  // Total Sugars
  final sugarMatch = RegExp(r'(?:total\s+)?sugars?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(text);
  if (sugarMatch != null) {
    result['total_sugars_g'] = double.parse(sugarMatch.group(1)!);
  }

  // Saturated Fat
  final satFatMatch = RegExp(r'saturated\s+fat(?:ty\s+acids?)?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(text);
  if (satFatMatch != null) {
    result['sat_fat_g'] = double.parse(satFatMatch.group(1)!);
  }

  // Trans Fat
  final transFatMatch = RegExp(r'trans\s+fat(?:ty\s+acids?)?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(text);
  if (transFatMatch != null) {
    result['trans_fat_g'] = double.parse(transFatMatch.group(1)!);
  }

  // Sodium
  final sodiumMatch = RegExp(r'sodium\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*(mg|g)?', caseSensitive: false).firstMatch(text);
  if (sodiumMatch != null) {
    final val = double.parse(sodiumMatch.group(1)!);
    final unit = (sodiumMatch.group(2) ?? 'mg').toLowerCase();
    result['sodium_mg'] = (unit == 'g') ? val * 1000.0 : val;
  }

  // Salt
  final saltMatch = RegExp(r'salt\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(text);
  if (saltMatch != null) {
    result['salt_g'] = double.parse(saltMatch.group(1)!);
  }

  // Fiber
  final fiberMatch = RegExp(r'(?:dietary\s+)?fib(?:er|re)\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(text);
  if (fiberMatch != null) {
    result['fiber_g'] = double.parse(fiberMatch.group(1)!);
  }

  // Protein
  final proteinMatch = RegExp(r'protein\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(text);
  if (proteinMatch != null) {
    result['protein_g'] = double.parse(proteinMatch.group(1)!);
  }

  return result;
}

Map<String, dynamic> parseOcrIngredientsAndIns(String text) {
  final ingHeaderMatch = RegExp(r'(?:ingredients?|contains?)\s*:\s*(.+)', caseSensitive: false, dotAll: true).firstMatch(text);
  var body = (ingHeaderMatch != null) ? ingHeaderMatch.group(1)! : text;

  // Stop notices
  final stopMatch = RegExp(r'(?:allergen|manufactured\s+by|mfg|fssai|net\s+wt|mrp)', caseSensitive: false).firstMatch(body);
  if (stopMatch != null) {
    body = body.substring(0, stopMatch.start);
  }

  // Split on commas outside brackets/parentheses
  final tokens = body.split(RegExp(r',(?![^(\[]*[)\]])')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();

  // Extract INS matches
  final insMatches = RegExp(r'(?:ins|e)[-\s]?(\d{3,4}(?:\([a-z0-9iv]+\))?)', caseSensitive: false)
      .allMatches(body)
      .map((m) => m.group(1)!)
      .toSet()
      .toList();

  return {
    'ingredients': tokens,
    'ins_codes': insMatches,
    'raw_text': body.trim(),
  };
}

Map<String, dynamic> detectSpecularGlare(List<int> luminancePixels) {
  if (luminancePixels.isEmpty) {
    return {'is_glare': false, 'saturated_pct': 0.0, 'badge': null};
  }

  final total = luminancePixels.length;
  final saturatedCount = luminancePixels.where((px) => px > 248).length;
  final saturatedPct = (saturatedCount * 100.0) / total;

  final isGlare = saturatedPct > 18.0;
  final badge = isGlare ? 'Foil Glare Detected — Tilt Packet 15°' : null;

  return {
    'is_glare': isGlare,
    'saturated_pct': double.parse(saturatedPct.toStringAsFixed(2)),
    'badge': badge,
  };
}

