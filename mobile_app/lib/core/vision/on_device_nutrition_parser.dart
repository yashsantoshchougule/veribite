import 'dart:convert';

/// On-Device Structured Nutrition & Ingredient Regex Parser
/// Extracts Energy, Sugars, Saturated Fat, Sodium, Fiber, Protein,
/// comma-delimited ingredients, and INS/E-number additives directly from raw OCR text.
class OnDeviceNutritionParser {
  static const Set<String> southamptonRedDyes = {
    '102', // Tartrazine
    '104', // Quinoline Yellow
    '110', // Sunset Yellow
    '122', // Azorubine / Carmoisine
    '124', // Ponceau 4R
    '129', // Allura Red
  };

  static const Set<String> cautionAdditives = {
    '150c', '150d', '211', '220', '223', '249', '250', '282',
    '320', '321', '407', '621', '627', '631', '950', '951', '955', '960'
  };

  /// Parses raw OCR text into a structured product map ready for scoring and dosage evaluation
  static Map<String, dynamic>? parseFromText(String rawOcrText) {
    final text = rawOcrText.trim();
    if (text.length < 15) return null;

    final nutrition = parseNutritionTable(text);
    final ingredientsData = parseIngredientsAndIns(text);
    final detectedName = extractProductAndBrand(text);

    final rawIngredients = ingredientsData['ingredients'] as List<String>;
    final insCodes = ingredientsData['ins_codes'] as List<String>;

    // Build enriched additives list
    final additives = <Map<String, dynamic>>[];
    bool redCapTriggered = false;

    for (final code in insCodes) {
      final cleanCode = code.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();
      final baseDigits = RegExp(r'\d+').firstMatch(cleanCode)?.group(0) ?? cleanCode;

      final isRed = southamptonRedDyes.contains(baseDigits) || southamptonRedDyes.contains(cleanCode);
      final isCaution = !isRed && (cautionAdditives.contains(baseDigits) || cautionAdditives.contains(cleanCode));

      if (isRed) redCapTriggered = true;

      additives.add({
        'ins_code': code,
        'primary_name': 'Additive INS $code',
        'risk_tier': isRed ? 'RED' : (isCaution ? 'CAUTION' : 'GREEN'),
        'triggers_red_cap': isRed ? 1 : 0,
        'child_hyperactivity_flag': isRed ? 1 : 0,
        'jecfa_adi_mg_kg': isRed ? 4.0 : (isCaution ? 10.0 : 25.0),
      });
    }

    // Determine NOVA Grade (1 = unprocessed, 2 = culinary, 3 = processed, 4 = ultra-processed)
    int novaGrade = 1;
    if (additives.isNotEmpty || rawIngredients.length > 5) {
      novaGrade = 4;
    } else if (rawIngredients.length >= 3) {
      novaGrade = 3;
    } else if (rawIngredients.isNotEmpty) {
      novaGrade = 2;
    }

    // Baseline health score estimation
    int score = 75;
    final sugar = nutrition['sugar_g_per_100g'] ?? 0.0;
    final satFat = nutrition['sat_fat_g_per_100g'] ?? 0.0;
    final sodium = nutrition['sodium_mg_per_100g'] ?? 0.0;

    if (sugar > 20.0) {
      score -= 25;
    } else if (sugar > 10.0) {
      score -= 15;
    }

    if (satFat > 10.0) {
      score -= 20;
    } else if (satFat > 5.0) {
      score -= 10;
    }

    if (sodium > 800.0) {
      score -= 20;
    } else if (sodium > 400.0) {
      score -= 10;
    }

    if (redCapTriggered) {
      score = score.clamp(10, 39);
    } else {
      score = score.clamp(15, 95);
    }

    return {
      'source': 'on_device_vision',
      'product_name': detectedName['product_name'] ?? 'Scanned Food Product (On-Device OCR)',
      'brand_name': detectedName['brand_name'] ?? 'Packaged Food',
      'category': detectedName['category'] ?? 'Packaged Goods',
      'serving_size_g': nutrition['serving_size_g'] ?? 30.0,
      'pack_weight_g': nutrition['pack_weight_g'] ?? 100.0,
      'health_score': score,
      'nova_grade': novaGrade,
      'red_cap_triggered': redCapTriggered ? 1 : 0,
      'nutrition_json': jsonEncode(nutrition),
      'additives_json': jsonEncode(additives),
      'ingredients_json': jsonEncode(rawIngredients.isNotEmpty ? rawIngredients : ['Wheat Flour', 'Sugar', 'Edible Oil']),
    };
  }

  /// Extracts standard nutrition table values from text
  static Map<String, double> parseNutritionTable(String text) {
    final result = <String, double>{
      'energy_kj': 0.0,
      'energy_kcal': 0.0,
      'calories': 0.0,
      'sugar_g_per_100g': 0.0,
      'added_sugar_g_per_100g': 0.0,
      'total_fat_g_per_100g': 0.0,
      'sat_fat_g_per_100g': 0.0,
      'trans_fat_g_per_100g': 0.0,
      'sodium_mg_per_100g': 0.0,
      'cholesterol_mg_per_100g': 0.0,
      'protein_g': 0.0,
      'carbohydrates_g_per_100g': 0.0,
      'fiber_g': 0.0,
      'serving_size_g': 30.0,
      'pack_weight_g': 100.0,
    };

    // Energy: kcal or kJ
    final energyMatch = RegExp(r'(?:energy|calories?)(?:\s*\((?:kcal|kj)\))?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*(kcal|kj)?', caseSensitive: false).firstMatch(text);
    if (energyMatch != null) {
      final val = double.tryParse(energyMatch.group(1) ?? '') ?? 0.0;
      final unit = (energyMatch.group(2) ?? '').toLowerCase();
      if (unit == 'kj') {
        result['energy_kj'] = val;
        result['energy_kcal'] = val / 4.184;
        result['calories'] = val / 4.184;
      } else {
        result['energy_kj'] = val * 4.184;
        result['energy_kcal'] = val;
        result['calories'] = val;
      }
    }

    // Total Sugars & Added Sugars
    final addedSugarMatch = RegExp(r'added\s+sugars?\s*(?:\(g\))?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(text);
    if (addedSugarMatch != null) {
      result['added_sugar_g_per_100g'] = double.tryParse(addedSugarMatch.group(1) ?? '') ?? 0.0;
    }

    final sugarMatch = RegExp(r'(?:total\s+)?sugars?\s*(?:\(g\))?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(text);
    if (sugarMatch != null) {
      result['sugar_g_per_100g'] = double.tryParse(sugarMatch.group(1) ?? '') ?? 0.0;
    }

    // Total Fat
    final totalFatMatch = RegExp(r'(?:total\s+)?fat\s*(?:\(g\))?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(text);
    if (totalFatMatch != null) {
      result['total_fat_g_per_100g'] = double.tryParse(totalFatMatch.group(1) ?? '') ?? 0.0;
    }

    // Saturated Fat
    final satFatMatch = RegExp(r'saturated\s+fat(?:ty\s+acids?)?\s*(?:\(g\))?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(text);
    if (satFatMatch != null) {
      result['sat_fat_g_per_100g'] = double.tryParse(satFatMatch.group(1) ?? '') ?? 0.0;
    }

    // Trans Fat
    final transFatMatch = RegExp(r'trans\s+fat(?:ty\s+acids?)?\s*(?:\(g\))?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(text);
    if (transFatMatch != null) {
      result['trans_fat_g_per_100g'] = double.tryParse(transFatMatch.group(1) ?? '') ?? 0.0;
    }

    // Sodium
    final sodiumMatch = RegExp(r'sodium\s*(?:\(mg\))?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*(mg|g)?', caseSensitive: false).firstMatch(text);
    if (sodiumMatch != null) {
      final val = double.tryParse(sodiumMatch.group(1) ?? '') ?? 0.0;
      final unit = (sodiumMatch.group(2) ?? 'mg').toLowerCase();
      result['sodium_mg_per_100g'] = unit == 'g' ? val * 1000.0 : val;
    }

    // Cholesterol
    final cholMatch = RegExp(r'cholesterol\s*(?:\(mg\))?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*(mg|g)?', caseSensitive: false).firstMatch(text);
    if (cholMatch != null) {
      final val = double.tryParse(cholMatch.group(1) ?? '') ?? 0.0;
      final unit = (cholMatch.group(2) ?? 'mg').toLowerCase();
      result['cholesterol_mg_per_100g'] = unit == 'g' ? val * 1000.0 : val;
    }

    // Protein
    final proteinMatch = RegExp(r'protein\s*(?:\(g\))?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(text);
    if (proteinMatch != null) {
      result['protein_g'] = double.tryParse(proteinMatch.group(1) ?? '') ?? 0.0;
    }

    // Carbohydrates
    final carbsMatch = RegExp(r'(?:carbohydrates?|carbs?)\s*(?:\(g\))?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(text);
    if (carbsMatch != null) {
      result['carbohydrates_g_per_100g'] = double.tryParse(carbsMatch.group(1) ?? '') ?? 0.0;
    }

    // Fiber
    final fiberMatch = RegExp(r'(?:dietary\s+)?fib(?:er|re)\s*(?:\(g\))?\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(text);
    if (fiberMatch != null) {
      result['fiber_g'] = double.tryParse(fiberMatch.group(1) ?? '') ?? 0.0;
    }

    // Atwater Sanity Check on Calories
    final correctedKcal = verifyAndCorrectWithAtwater(
      rawKcal: result['energy_kcal'] ?? 0.0,
      proteinG: result['protein_g'] ?? 0.0,
      carbsG: result['carbohydrates_g_per_100g'] ?? 0.0,
      totalFatG: (result['total_fat_g_per_100g'] ?? 0.0) > 0 ? (result['total_fat_g_per_100g'] ?? 0.0) : (result['sat_fat_g_per_100g'] ?? 0.0),
    );
    if (correctedKcal > 0) {
      result['energy_kcal'] = correctedKcal;
      result['calories'] = correctedKcal;
      result['energy_kj'] = correctedKcal * 4.184;
    }

    // Serving Size
    final servingMatch = RegExp(r'serving\s+size\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*g?', caseSensitive: false).firstMatch(text);
    if (servingMatch != null) {
      result['serving_size_g'] = double.tryParse(servingMatch.group(1) ?? '') ?? 30.0;
    }

    // Pack Weight
    final packMatch = RegExp(r'(?:net\s+(?:wt|weight|qty|quantity)|pack\s+weight)\s*[:\-]?\s*(\d+(?:\.\d+)?)\s*(g|kg)?', caseSensitive: false).firstMatch(text);
    if (packMatch != null) {
      final val = double.tryParse(packMatch.group(1) ?? '') ?? 100.0;
      final unit = (packMatch.group(2) ?? 'g').toLowerCase();
      result['pack_weight_g'] = unit == 'kg' ? val * 1000.0 : val;
    }

    return result;
  }

  /// Automatic Atwater Calorie Sanity Check:
  /// Expected kcal = (protein * 4) + (carbs * 4) + (total_fat * 9).
  /// Detects plastic glare drift (e.g. 380 vs 368) or missed decimal points (36800).
  static double verifyAndCorrectWithAtwater({
    required double rawKcal,
    required double proteinG,
    required double carbsG,
    required double totalFatG,
  }) {
    if (proteinG <= 0 && carbsG <= 0 && totalFatG <= 0) return rawKcal;
    final atwaterKcal = (proteinG * 4.0) + (carbsG * 4.0) + (totalFatG * 9.0);
    if (rawKcal <= 0 || (rawKcal - atwaterKcal).abs() > 10.0 || rawKcal > 1000.0) {
      return atwaterKcal.roundToDouble();
    }
    return rawKcal;
  }

  /// Extracts ingredients list and INS / E-numbers
  static Map<String, dynamic> parseIngredientsAndIns(String text) {
    final ingMatch = RegExp(r'(?:ingredients?|contains?)\s*:\s*(.+)', caseSensitive: false, dotAll: true).firstMatch(text);
    var body = ingMatch != null ? ingMatch.group(1)! : text;

    // Truncate at trailing regulatory notices
    final stopMatch = RegExp(r'(?:allergen|manufactured\s+by|mfg|fssai|net\s+wt|mrp|best\s+before)', caseSensitive: false).firstMatch(body);
    if (stopMatch != null) {
      body = body.substring(0, stopMatch.start);
    }

    // Split on commas outside parentheses/brackets
    final rawTokens = body.split(RegExp(r',(?![^(\[]*[)\]])'));
    final cleaned = rawTokens
        .map((tok) => tok.replaceAll(RegExp(r'[\r\n]+'), ' ').trim())
        .where((tok) => tok.length > 1 && !RegExp(r'^(and|contains|with)$', caseSensitive: false).hasMatch(tok))
        .toList();

    // Extract INS and E numbers: e.g. INS 102, INS 322(i), E110, E-211
    final insMatches = RegExp(r'(?:ins|e)[-\s]?(\d{3,4}(?:\([a-z0-9iv]+\))?)', caseSensitive: false).allMatches(text);
    final insCodes = <String>{};
    for (final m in insMatches) {
      final code = m.group(1);
      if (code != null && code.isNotEmpty) {
        insCodes.add(code);
      }
    }

    return {
      'ingredients': cleaned,
      'ins_codes': insCodes.toList(),
    };
  }

  /// Attempts to infer brand and product title from header lines
  static Map<String, String> extractProductAndBrand(String text) {
    final lines = text.split(RegExp(r'[\r\n]+')).map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    String? foundBrand;
    String? foundProduct;

    // Check against top brands
    const popularBrands = [
      'Britannia', 'Nestle', 'Parle', 'ITC', 'Sunfeast', 'Amul', 'Cadbury',
      'Haldiram', 'MDH', 'Everest', 'Catch', 'MTR', 'Dabur', 'Tata', 'Kissan',
      'Bikaji', 'Balaji', 'Paper Boat', 'Mother Dairy', 'Patanjali', 'Ching'
    ];

    for (final line in lines.take(6)) {
      for (final brand in popularBrands) {
        if (line.toLowerCase().contains(brand.toLowerCase())) {
          foundBrand = brand;
          foundProduct = line;
          break;
        }
      }
      if (foundBrand != null) break;
    }

    if (foundProduct == null && lines.isNotEmpty) {
      foundProduct = lines.first;
    }

    return {
      if (foundBrand != null) 'brand_name': foundBrand,
      if (foundProduct != null) 'product_name': foundProduct,
      'category': 'Packaged Foods',
    };
  }
}
