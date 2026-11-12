import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/gemini_config.dart';

/// Multimodal Vision AI service that analyzes real product photos, curved packages,
/// and printed nutrition facts labels directly using Google Gemini Vision.
class GeminiVisionService {
  final http.Client? _injectedClient;

  GeminiVisionService({http.Client? httpClient}) : _injectedClient = httpClient;

  http.Client get _client => _injectedClient ?? http.Client();

  /// Analyzes one or more product packaging / nutrition label photos using Gemini Vision.
  /// Returns structured product map with real name, brand, macros, and ingredients.
  Future<Map<String, dynamic>?> analyzeProductPhoto({
    required List<List<int>> frames,
    String? hintBarcode,
  }) async {
    if (frames.isEmpty) return null;

    // Pick the largest frame (highest resolution image)
    List<int> bestFrame = frames.first;
    for (final frame in frames) {
      if (frame.length > bestFrame.length) {
        bestFrame = frame;
      }
    }

    // Guard: ignore trivial dummy bytes
    if (bestFrame.length < 50) {
      debugPrint('[GeminiVisionService] Frame too small (${bestFrame.length} bytes), skipping vision API.');
      return null;
    }

    if (!GeminiConfig.isConfigured) {
      debugPrint('[GeminiVisionService] Gemini API key not configured.');
      return null;
    }

    final base64Image = base64Encode(bestFrame);
    final prompt = _buildVisionPrompt(hintBarcode: hintBarcode);

    final requestBody = {
      'contents': [
        {
          'parts': [
            {'text': prompt},
            {
              'inline_data': {
                'mime_type': 'image/jpeg',
                'data': base64Image,
              }
            }
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.1,
        'responseMimeType': 'application/json',
      }
    };

    final modelsToTry = GeminiConfig.cascadeModels;
    final maxKeyAttempts = GeminiConfig.apiKeys.length.clamp(1, 4);

    for (int keyAttempt = 0; keyAttempt < maxKeyAttempts; keyAttempt++) {
      for (final model in modelsToTry) {
        try {
          final uri = Uri.parse('${GeminiConfig.baseUrl}/$model:generateContent?key=${GeminiConfig.apiKey}');
          final response = await _client
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(requestBody),
              )
              .timeout(const Duration(seconds: 8));

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates[0]['content'];
              final parts = content['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final rawJsonText = parts[0]['text']?.toString() ?? '';
                final parsed = _parseGeminiJson(rawJsonText);
                if (parsed != null) {
                  return parsed;
                }
              }
            }
          } else if (response.statusCode == 429 || response.statusCode == 503) {
            debugPrint(
              '[GeminiVisionService] Quota/Server busy on $model (HTTP ${response.statusCode}). Attempting cascade fallback.',
            );
            continue;
          } else {
            debugPrint('[GeminiVisionService] Gemini API error ($model): HTTP ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          debugPrint('[GeminiVisionService] Model $model query notice: $e');
        }
      }
      GeminiConfig.rotateKey();
    }

    return null;
  }

  String _buildVisionPrompt({String? hintBarcode}) {
    return '''
You are an expert food toxicology and nutrition analyst.
Analyze this photo to determine if it contains an edible food product, beverage, dietary supplement, or packaged grocery item.

CRITICAL STEP 1: FOOD CLASSIFICATION & GUARDRAILS
1. Determine if the photographed object is an edible food product, beverage, dietary supplement, or packaged grocery item.
2. If the image shows a NON-FOOD object (such as a laptop, computer, smartphone, electronics, gadget, person, animal, vehicle, furniture, clothing, footwear, book, document, stationery, tool, hardware, household cleaning chemical, cosmetic, or toy):
   - Set "is_food_or_beverage": false
   - Set "non_food_reason": "Clear explanation of what was detected and why it is not an edible food or drink."
   - Set "product_name": "<detected object name>"
   - Set "category": "Non-Food"
   - Leave nutrition and ingredients empty.
3. ONLY if the image contains an edible food product, beverage, supplement, or grocery package, set "is_food_or_beverage": true.

CRITICAL INSTRUCTIONS FOR INDIAN FOOD PACKAGING:
- Indian packaging frequently splits the nutrition table into TWO SIDE-BY-SIDE COLUMNS (e.g., Left table: Energy, Total Fat, Saturated Fat, Trans Fat, Carbohydrates; Right table: Total Sugar, Added Sugar, Protein, Cholesterol, Sodium, Dietary Fibre). Carefully read both columns!
- ALWAYS extract values from the "100g" / "Per 100g" column. DO NOT extract from "% RDA per 100g" or "% RDA per Serve" percentage columns!
- If "% RDA per 100g" and "% RDA per Serve" are printed, also extract them as "rda_per_100g" and "rda_per_serve" so exact serving size can be calculated: (rda_per_serve / rda_per_100g) * 100.

Extract the exact information printed on the package:
1. "is_food_or_beverage": true or false
2. "non_food_reason": Explanation if not food
3. "product_name": Full product name (e.g., "Kreamy Magic Cream Pav", "MTR Badam Drink Mix", "Catch Chole Masala").
4. "brand_name": Manufacturer brand (e.g., "Kwality", "MTR", "Catch", "Britannia").
5. "category": Food category (e.g., "Bakery & Breads", "Biscuits & Cookies", "Snacks & Namkeen", "Instant Foods & Noodles").
6. "serving_size_g": Serving size in grams or ml (default to 30.0 if not specified).
7. "pack_weight_g": Net pack weight in grams or ml (e.g., 60.0, 100.0, 200.0).
8. "nutrition": Object with numeric values per 100g:
   - "energy_kcal": Energy in kcal per 100g (e.g., 368.00)
   - "energy_kj": Energy in kJ per 100g (if kcal printed, multiply kcal by 4.184)
   - "sugar_g_per_100g": Total sugars in grams per 100g
   - "added_sugar_g_per_100g": Added sugars in grams per 100g
   - "total_fat_g_per_100g": Total fat in grams per 100g
   - "sat_fat_g_per_100g": Saturated fat in grams per 100g
   - "trans_fat_g_per_100g": Trans fat in grams per 100g
   - "carbohydrates_g_per_100g": Total carbohydrate in grams per 100g
   - "protein_g": Protein in grams per 100g
   - "sodium_mg_per_100g": Sodium in mg per 100g (if salt in g printed, salt_g * 400)
   - "cholesterol_mg_per_100g": Cholesterol in mg per 100g
   - "fiber_g": Dietary fiber in grams per 100g (default 1.0)
9. "ingredients": List of ingredient strings printed on the package.
10. "additives": List of detected food additives with "ins_code", "primary_name", and "risk_tier" ("GREEN", "YELLOW", or "RED").

${hintBarcode != null ? 'Note: Scanned barcode hint: $hintBarcode.' : ''}
Respond ONLY with a valid JSON object matching this schema without any markdown formatting.
''';
  }

  Map<String, dynamic>? _parseGeminiJson(String rawText) {
    if (rawText.trim().isEmpty) return null;

    try {
      var cleanText = rawText.trim();
      Map<String, dynamic>? decoded;

      // 1. Direct JSON decode
      try {
        final parsed = jsonDecode(cleanText);
        if (parsed is Map<String, dynamic>) decoded = parsed;
      } catch (_) {}

      // 2. Strip markdown code fences
      if (decoded == null && cleanText.contains('```')) {
        final match = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(cleanText);
        if (match != null) {
          try {
            final parsed = jsonDecode(match.group(1)!.trim());
            if (parsed is Map<String, dynamic>) decoded = parsed;
          } catch (_) {}
        }
      }

      // 3. Outermost curly braces
      if (decoded == null) {
        final firstBrace = cleanText.indexOf('{');
        final lastBrace = cleanText.lastIndexOf('}');
        if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
          try {
            final parsed = jsonDecode(cleanText.substring(firstBrace, lastBrace + 1));
            if (parsed is Map<String, dynamic>) decoded = parsed;
          } catch (_) {}
        }
      }

      if (decoded != null) {
        final productName = decoded['product_name']?.toString().trim();
        if (productName == null || productName.isEmpty) return null;

        // Guardrail: Non-food object detection
        if (decoded['is_food_or_beverage'] == false || decoded['is_non_food'] == true) {
          return {
            'is_food_or_beverage': false,
            'is_non_food': true,
            'non_food_reason': decoded['non_food_reason']?.toString() ?? 'Non-food item detected',
            'product_name': productName,
            'brand_name': decoded['brand_name']?.toString().trim() ?? 'Electronics / Non-food',
            'category': 'Non-Food',
          };
        }

        final brandName = decoded['brand_name']?.toString().trim() ?? 'Brand Verified';
        final category = decoded['category']?.toString().trim() ?? 'Packaged Food';
        // Ensure nutrition map is properly formatted
        final nut = (decoded['nutrition'] as Map<String, dynamic>?) ?? {};
        final sugars = (nut['sugar_g_per_100g'] as num?)?.toDouble() ?? 5.0;
        final addedSugars = (nut['added_sugar_g_per_100g'] as num?)?.toDouble() ?? 0.0;
        final satFat = (nut['sat_fat_g_per_100g'] as num?)?.toDouble() ?? 1.5;
        final totalFat = (nut['total_fat_g_per_100g'] as num?)?.toDouble() ?? satFat;
        final transFat = (nut['trans_fat_g_per_100g'] as num?)?.toDouble() ?? 0.0;
        final sodium = (nut['sodium_mg_per_100g'] as num?)?.toDouble() ?? 100.0;
        final cholesterol = (nut['cholesterol_mg_per_100g'] as num?)?.toDouble() ?? 0.0;
        final protein = (nut['protein_g'] as num?)?.toDouble() ?? 2.0;
        final carbs = (nut['carbohydrates_g_per_100g'] as num?)?.toDouble() ?? 0.0;
        final fiber = (nut['fiber_g'] as num?)?.toDouble() ?? 1.0;

        // Energy extraction & Atwater Calorie Sanity Check
        // Expected kcal per 100g = (protein * 4) + (carbs * 4) + (total_fat * 9)
        double energyKcal = (nut['energy_kcal'] as num?)?.toDouble() ?? 0.0;
        final double energyKj = (nut['energy_kj'] as num?)?.toDouble() ?? (energyKcal > 0 ? energyKcal * 4.184 : 600.0);
        if (energyKcal <= 0.0) {
          energyKcal = energyKj / 4.184;
        }

        if (protein > 0 || carbs > 0 || totalFat > 0) {
          final atwaterKcal = (protein * 4.0) + (carbs * 4.0) + (totalFat * 9.0);
          if (energyKcal <= 0 || (energyKcal - atwaterKcal).abs() > 10.0 || energyKcal > 1000.0) {
            debugPrint('[GeminiVisionService] Atwater correction: adjusting kcal from $energyKcal to ${atwaterKcal.roundToDouble()}');
            energyKcal = atwaterKcal.roundToDouble();
          }
        }

        // Serving size derivation from % RDA ratio if missing
        double servingG = (decoded['serving_size_g'] as num?)?.toDouble() ?? 0.0;
        final rdaServe = (decoded['rda_per_serve'] as num?)?.toDouble() ?? (nut['rda_per_serve'] as num?)?.toDouble();
        final rda100 = (decoded['rda_per_100g'] as num?)?.toDouble() ?? (nut['rda_per_100g'] as num?)?.toDouble();
        if (servingG <= 0.0) {
          if (rdaServe != null && rda100 != null && rda100 > 0) {
            servingG = double.parse(((rdaServe / rda100) * 100.0).toStringAsFixed(1));
          } else {
            servingG = 30.0;
          }
        }
        final packG = (decoded['pack_weight_g'] as num?)?.toDouble() ?? 100.0;

        final additives = (decoded['additives'] as List?) ?? [];
        final ingredients = (decoded['ingredients'] as List?) ?? ['Natural Food Ingredients'];

        return {
          'barcode': 'gemini_vision_${DateTime.now().millisecondsSinceEpoch}',
          'product_name': productName,
          'brand_name': brandName,
          'category': category,
          'serving_size_g': servingG,
          'pack_weight_g': packG,
          'piece_weight_g': null,
          'nova_grade': 3,
          'red_cap_triggered': 0,
          'nutrition_json': jsonEncode({
            'energy_kj': energyKcal * 4.184,
            'energy_kcal': energyKcal,
            'calories': energyKcal,
            'sugar_g_per_100g': sugars,
            'added_sugar_g_per_100g': addedSugars,
            'sat_fat_g_per_100g': satFat,
            'total_fat_g_per_100g': totalFat,
            'trans_fat_g_per_100g': transFat,
            'sodium_mg_per_100g': sodium,
            'cholesterol_mg_per_100g': cholesterol,
            'protein_g': protein,
            'carbohydrates_g_per_100g': carbs,
            'fiber_g': fiber,
            'fruit_veg_nut_pct': 0.0,
            'rda_per_serve': rdaServe,
            'rda_per_100g': rda100,
          }),
          'additives_json': jsonEncode(additives),
          'ingredients_json': jsonEncode(ingredients.map((e) => e.toString()).toList()),
        };
      }
    } catch (e) {
      debugPrint('[GeminiVisionService] Failed to parse JSON: $e\nRaw: $rawText');
    }

    return null;
  }
}

