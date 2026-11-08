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

    final modelsToTry = [GeminiConfig.model, ...GeminiConfig.fallbackModels];

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
        } else {
          debugPrint('[GeminiVisionService] Gemini API error ($model): HTTP ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        debugPrint('[GeminiVisionService] Model $model query notice: $e');
      }
    }

    return null;
  }

  String _buildVisionPrompt({String? hintBarcode}) {
    return '''
You are an expert food toxicology and nutrition analyst.
Analyze this photo of a packaged food product, bottle, can, or nutrition facts label.
Extract the exact information printed on the package:
1. "product_name": Full product name (e.g., "MTR Badam Drink Mix", "Amul Gold Milk", "Tata Tea Gold").
2. "brand_name": Manufacturer brand (e.g., "MTR", "Amul", "Tata Consumer", "Britannia").
3. "category": Food category (e.g., "Beverages & Juices", "Biscuits & Cookies", "Cheese & Dairy", "Snacks & Namkeen", "Breakfast Cereals", "Instant Foods & Noodles").
4. "serving_size_g": Serving size in grams or ml (default to 30.0 if not specified).
5. "pack_weight_g": Net pack weight in grams or ml (e.g., 200.0, 500.0, 1000.0).
6. "nutrition": Object with numeric values per 100g:
   - "energy_kj": Energy in kJ (if kcal printed, multiply kcal by 4.184)
   - "sugar_g_per_100g": Total sugars in grams per 100g
   - "sat_fat_g_per_100g": Saturated fat in grams per 100g
   - "sodium_mg_per_100g": Sodium in mg per 100g (if salt in g printed, salt_g * 400)
   - "protein_g": Protein in grams per 100g
   - "fiber_g": Dietary fiber in grams per 100g (default 1.0)
7. "ingredients": List of ingredient strings printed on the package.
8. "additives": List of detected food additives with "ins_code", "primary_name", and "risk_tier" ("GREEN", "YELLOW", or "RED").

${hintBarcode != null ? 'Note: Scanned barcode hint: $hintBarcode.' : ''}
Respond ONLY with a valid JSON object matching this schema without any markdown formatting.
''';
  }

  Map<String, dynamic>? _parseGeminiJson(String rawText) {
    if (rawText.trim().isEmpty) return null;

    try {
      // Strip markdown code fences if present
      String cleanText = rawText.trim();
      if (cleanText.startsWith('```')) {
        cleanText = cleanText.replaceAll(RegExp(r'^```(?:json)?\s*'), '').replaceAll(RegExp(r'\s*```$'), '').trim();
      }

      final decoded = jsonDecode(cleanText);
      if (decoded is Map<String, dynamic>) {
        final productName = decoded['product_name']?.toString().trim();
        if (productName == null || productName.isEmpty) return null;

        final brandName = decoded['brand_name']?.toString().trim() ?? 'Brand Verified';
        final category = decoded['category']?.toString().trim() ?? 'Packaged Food';
        final servingG = (decoded['serving_size_g'] as num?)?.toDouble() ?? 30.0;
        final packG = (decoded['pack_weight_g'] as num?)?.toDouble() ?? 100.0;

        // Ensure nutrition map is properly formatted
        final nut = (decoded['nutrition'] as Map<String, dynamic>?) ?? {};
        final energyKj = (nut['energy_kj'] as num?)?.toDouble() ?? 600.0;
        final sugars = (nut['sugar_g_per_100g'] as num?)?.toDouble() ?? 5.0;
        final satFat = (nut['sat_fat_g_per_100g'] as num?)?.toDouble() ?? 1.5;
        final sodium = (nut['sodium_mg_per_100g'] as num?)?.toDouble() ?? 100.0;
        final protein = (nut['protein_g'] as num?)?.toDouble() ?? 2.0;
        final fiber = (nut['fiber_g'] as num?)?.toDouble() ?? 1.0;

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
          'health_score': 65,
          'nova_grade': 3,
          'red_cap_triggered': 0,
          'nutrition_json': jsonEncode({
            'energy_kj': energyKj,
            'sugar_g_per_100g': sugars,
            'sat_fat_g_per_100g': satFat,
            'sodium_mg_per_100g': sodium,
            'protein_g': protein,
            'fiber_g': fiber,
            'fruit_veg_nut_pct': 0.0,
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
