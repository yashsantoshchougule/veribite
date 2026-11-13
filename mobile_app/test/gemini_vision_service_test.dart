import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/core/vision/gemini_vision_service.dart';

void main() {
  group('GeminiVisionService Tests', () {
    test('extracts MTR Badam Drink Mix details successfully from Gemini vision response', () async {
      final mockGeminiResponse = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'product_name': 'MTR Badam Drink Mix',
                    'brand_name': 'MTR',
                    'category': 'Beverages & Juices',
                    'serving_size_g': 25.0,
                    'pack_weight_g': 200.0,
                    'nutrition': {
                      'energy_kj': 1715.0,
                      'sugar_g_per_100g': 58.0,
                      'sat_fat_g_per_100g': 2.5,
                      'sodium_mg_per_100g': 120.0,
                      'protein_g': 7.5,
                      'fiber_g': 3.0,
                    },
                    'ingredients': ['Sugar', 'Almond (Badam 8.5%)', 'Milk Solids', 'Cardamom', 'Saffron'],
                    'additives': [],
                  })
                }
              ]
            }
          }
        ]
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(mockGeminiResponse), 200, headers: {'content-type': 'application/json'});
      });

      final service = GeminiVisionService(httpClient: mockClient);
      final dummyFrame = List<int>.generate(200, (i) => i % 255);

      final result = await service.analyzeProductPhoto(
        frames: [dummyFrame],
        hintBarcode: '8901042951111',
      );

      expect(result, isNotNull);
      expect(result!['product_name'], 'MTR Badam Drink Mix');
      expect(result['brand_name'], 'MTR');
      expect(result['category'], 'Beverages & Juices');
      expect(result['serving_size_g'], 25.0);
      expect(result['pack_weight_g'], 200.0);

      final nutrition = jsonDecode(result['nutrition_json'] as String);
      expect(nutrition['sugar_g_per_100g'], 58.0);
      expect(nutrition['protein_g'], 7.5);

      final ingredients = jsonDecode(result['ingredients_json'] as String) as List;
      expect(ingredients.contains('Sugar'), isTrue);
      expect(ingredients.any((ing) => ing.toString().contains('Almond')), isTrue);
    });

    test('ignores dummy frames with fewer than 50 bytes', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Should not be called for dummy tiny frames');
      });

      final service = GeminiVisionService(httpClient: mockClient);
      final result = await service.analyzeProductPhoto(frames: [[0xFF, 0xD8]]);

      expect(result, isNull);
    });

    test('handles API HTTP 500 failure gracefully', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Internal Server Error', 500);
      });

      final service = GeminiVisionService(httpClient: mockClient);
      final dummyFrame = List<int>.generate(100, (i) => i % 255);

      final result = await service.analyzeProductPhoto(frames: [dummyFrame]);
      expect(result, isNull);
    });

    test('strips markdown code blocks in Gemini response before parsing', () async {
      const wrappedJson = '''```json
{
  "product_name": "Milky Mist Cheddar Cheese",
  "brand_name": "Milky Mist",
  "category": "Cheese & Dairy",
  "serving_size_g": 20.0,
  "pack_weight_g": 200.0,
  "nutrition": {
    "energy_kj": 1500.0,
    "sugar_g_per_100g": 0.5,
    "sat_fat_g_per_100g": 18.0,
    "sodium_mg_per_100g": 650.0,
    "protein_g": 25.0
  },
  "ingredients": ["Pasteurised Cow Milk", "Common Salt", "Microbial Rennet"],
  "additives": []
}
```''';

      final mockResponse = {
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': wrappedJson}
              ]
            }
          }
        ]
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(mockResponse), 200, headers: {'content-type': 'application/json'});
      });

      final service = GeminiVisionService(httpClient: mockClient);
      final dummyFrame = List<int>.generate(150, (i) => i % 255);

      final result = await service.analyzeProductPhoto(frames: [dummyFrame]);
      expect(result, isNotNull);
      expect(result!['product_name'], 'Milky Mist Cheddar Cheese');
      expect(result['brand_name'], 'Milky Mist');
      expect(result['category'], 'Cheese & Dairy');
    });

    test('cascades to lightweight fallback models when primary model returns 429 quota limit', () async {
      int requestCount = 0;
      final requestedModels = <String>[];

      final mockResponse = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'product_name': 'Amul Pure Ghee',
                    'brand_name': 'Amul',
                    'category': 'Oils & Ghee',
                    'serving_size_g': 15.0,
                    'pack_weight_g': 1000.0,
                    'nutrition': {
                      'energy_kj': 3700.0,
                      'sugar_g_per_100g': 0.0,
                      'sat_fat_g_per_100g': 65.0,
                      'sodium_mg_per_100g': 0.0,
                    },
                    'ingredients': ['Milk Fat'],
                    'additives': [],
                  })
                }
              ]
            }
          }
        ]
      };

      final mockClient = MockClient((request) async {
        requestCount++;
        final path = request.url.path;
        if (path.contains('gemini-2.5-flash:')) {
          requestedModels.add('gemini-2.5-flash');
          return http.Response('{"error": {"code": 429, "message": "RESOURCE_EXHAUSTED"}}', 429);
        }
        if (path.contains('gemini-2.5-flash-lite:')) {
          requestedModels.add('gemini-2.5-flash-lite');
          return http.Response(jsonEncode(mockResponse), 200, headers: {'content-type': 'application/json'});
        }
        return http.Response('Not Found', 404);
      });

      final service = GeminiVisionService(httpClient: mockClient);
      final dummyFrame = List<int>.generate(150, (i) => i % 255);

      final result = await service.analyzeProductPhoto(frames: [dummyFrame]);

      expect(result, isNotNull);
      expect(result!['product_name'], 'Amul Pure Ghee');
      expect(result['brand_name'], 'Amul');
      expect(requestCount, 2);
      expect(requestedModels, contains('gemini-2.5-flash'));
      expect(requestedModels, contains('gemini-2.5-flash-lite'));
    });

    test('correctly identifies non-food items from Gemini response', () async {
      final mockNonFoodResponse = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'is_food_or_beverage': false,
                    'non_food_reason': 'This is an HP laptop computer, which is an electronic device, not a packaged food item.',
                    'product_name': 'HP Victus Laptop',
                    'brand_name': 'HP',
                    'category': 'Electronics',
                  })
                }
              ]
            }
          }
        ]
      };

      final mockClient = MockClient((request) async {
        return http.Response(jsonEncode(mockNonFoodResponse), 200, headers: {'content-type': 'application/json'});
      });

      final service = GeminiVisionService(httpClient: mockClient);
      final dummyFrame = List<int>.generate(150, (i) => i % 255);

      final result = await service.analyzeProductPhoto(frames: [dummyFrame]);

      expect(result, isNotNull);
      expect(result!['is_food_or_beverage'], isFalse);
      expect(result['is_non_food'], isTrue);
      expect(result['product_name'], 'HP Victus Laptop');
      expect(result['non_food_reason'], contains('HP laptop computer'));
    });
  });
}
