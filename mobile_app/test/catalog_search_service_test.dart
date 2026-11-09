import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/features/home/application/catalog_search_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CatalogSearchService Tests', () {
    test('getStarterSuggestions returns curated food items and chemical additives', () {
      final service = CatalogSearchService();
      final all = service.getStarterSuggestions(filter: 'All');
      expect(all, isNotEmpty);
      expect(all.any((i) => i.isFood), isTrue);
      expect(all.any((i) => i.isAdditive), isTrue);

      final foodsOnly = service.getStarterSuggestions(filter: 'Foods');
      expect(foodsOnly.every((i) => i.isFood), isTrue);

      final additivesOnly = service.getStarterSuggestions(filter: 'Additives');
      expect(additivesOnly.every((i) => i.isAdditive), isTrue);
    });

    test('searchAdditives matches Tartrazine (INS 102) with RED risk tier', () async {
      final service = CatalogSearchService();
      final results = await service.searchAdditives('102');
      expect(results, isNotEmpty);
      final tartrazine = results.firstWhere((r) => r.id == '102');
      expect(tartrazine.title, contains('Tartrazine'));
      expect(tartrazine.riskTier, 'RED');
      expect(tartrazine.childHyperactivityFlag, isTrue);
    });

    test('searchAdditives matches PGPR (INS 476) with CAUTION risk tier', () async {
      final service = CatalogSearchService();
      final results = await service.searchAdditives('476');
      expect(results, isNotEmpty);
      final pgpr = results.firstWhere((r) => r.id == '476');
      expect(pgpr.title, contains('Polyglycerol polyricinoleate'));
      expect(pgpr.riskTier, 'CAUTION');
    });

    test('searchFoodProducts queries Search-a-licious API and parses results', () async {
      final mockJson = jsonEncode({
        'count': 1,
        'hits': [
          {
            'code': '8901262010016',
            'product_name': 'Amul Pasteurized Butter',
            'brands': ['Amul'],
            'categories': 'Dairy, Butter',
            'nova_group': 2,
            'nutriscore_score': 30,
            'image_front_small_url': 'https://images.openfoodfacts.org/amul_thumb.jpg',
          }
        ]
      });

      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('search.openfoodfacts.org')) {
          return http.Response(mockJson, 200);
        }
        return http.Response('{"hits": []}', 200);
      });

      final service = CatalogSearchService(httpClient: mockClient);
      final foods = await service.searchFoodProducts('amul butter');

      expect(foods, isNotEmpty);
      expect(foods.first.id, '8901262010016');
      expect(foods.first.title, 'Amul Pasteurized Butter');
      expect(foods.first.subtitle, contains('Amul'));
      expect(foods.first.imageUrl, 'https://images.openfoodfacts.org/amul_thumb.jpg');
    });

    test('search combines additives and food products on general query', () async {
      final mockJson = jsonEncode({
        'count': 1,
        'hits': [
          {
            'code': '8901058852339',
            'product_name': 'Maggi Masala Noodles',
            'brands': ['Maggi'],
            'nova_group': 4,
          }
        ]
      });

      final mockClient = MockClient((request) async {
        return http.Response(mockJson, 200);
      });

      final service = CatalogSearchService(httpClient: mockClient);
      final results = await service.search(query: 'maggi', filter: 'All');

      expect(results, isNotEmpty);
      expect(results.any((r) => r.isFood && r.title.contains('Maggi')), isTrue);
    });

    test('IndianFoodQueryNormalizer normalizes phonetic typos to canonical Indian food names', () {
      expect(IndianFoodQueryNormalizer.normalize('chess'), 'cheese');
      expect(IndianFoodQueryNormalizer.normalize('chees'), 'cheese');
      expect(IndianFoodQueryNormalizer.normalize('cheez'), 'cheese');
      expect(IndianFoodQueryNormalizer.normalize('chiz'), 'cheese');
      expect(IndianFoodQueryNormalizer.normalize('panner'), 'paneer');
      expect(IndianFoodQueryNormalizer.normalize('paner'), 'paneer');
      expect(IndianFoodQueryNormalizer.normalize('panir'), 'paneer');
      expect(IndianFoodQueryNormalizer.normalize('paneere'), 'paneer');
      expect(IndianFoodQueryNormalizer.normalize('vadilal panner makhani'), 'vadilal paneer makhani');
      expect(IndianFoodQueryNormalizer.normalize('bater'), 'butter');
      expect(IndianFoodQueryNormalizer.normalize('buter'), 'butter');
      expect(IndianFoodQueryNormalizer.normalize('ghee'), 'ghee');
      expect(IndianFoodQueryNormalizer.normalize('ghi'), 'ghee');
      expect(IndianFoodQueryNormalizer.normalize('choklet'), 'chocolate');
      expect(IndianFoodQueryNormalizer.normalize('ketchap'), 'ketchup');
      expect(IndianFoodQueryNormalizer.normalize('mayo'), 'mayonnaise');
      expect(IndianFoodQueryNormalizer.normalize('oates'), 'oats');
      expect(IndianFoodQueryNormalizer.normalize('bhujiya'), 'bhujia');
      expect(IndianFoodQueryNormalizer.normalize('chavanprash'), 'chyawanprash');
      expect(IndianFoodQueryNormalizer.normalize('masla'), 'masala');
      expect(IndianFoodQueryNormalizer.normalize('biskut'), 'biscuit');
      expect(IndianFoodQueryNormalizer.normalize('namkin'), 'namkeen');
      expect(IndianFoodQueryNormalizer.normalize('dahi'), 'dahi curd');
    });

    test('Purges empty/corrupted OFF stubs (like "Chess" with zero macros & no ingredients) and never returns score 95', () async {
      final mockJson = jsonEncode({
        'count': 2,
        'products': [
          {
            'code': '9999999999999',
            'product_name': 'Chess',
            'brands': '',
            'categories': 'Games, Toys',
            'nova_group': 3,
            'nutriments': {
              'energy-kcal_100g': 0.0,
              'fat_100g': 0.0,
              'carbohydrates_100g': 0.0,
              'proteins_100g': 0.0,
              'sodium_100g': 0.0,
            },
            'ingredients_text': '',
            'additives_tags': [],
          },
          {
            'code': '8901262010450',
            'product_name': 'Amul Processed Cheese',
            'brands': 'Amul',
            'categories': 'Dairy & Cheese',
            'nova_group': 4,
            'nutriments': {
              'energy-kcal_100g': 314.0,
              'fat_100g': 25.0,
              'saturated-fat_100g': 16.0,
              'carbohydrates_100g': 2.0,
              'proteins_100g': 20.0,
              'sodium_100g': 0.72,
            },
          }
        ]
      });

      final mockClient = MockClient((request) async {
        return http.Response(mockJson, 200);
      });

      final service = CatalogSearchService(httpClient: mockClient);
      final results = await service.searchFoodProducts('chess');

      // The empty "Chess" stub with 0 macros MUST be purged completely!
      expect(results.any((r) => r.code == '9999999999999'), isFalse);
      // Valid cheese product MUST be present
      expect(results.any((r) => r.title.contains('Amul Processed Cheese')), isTrue);
      // No product should have brand "Verified Brand"
      expect(results.any((r) => r.subtitle.contains('Verified Brand')), isFalse);
    });

    test('Populates Category Baseline Macros when known cheese search hit has missing nutrition in OFF', () async {
      final mockJson = jsonEncode({
        'count': 1,
        'products': [
          {
            'code': '0099887766554',
            'product_name': 'Kraft Cheddar Cheese Block',
            'brands': 'Kraft',
            'categories': 'Dairy, Cheese, Cheddar',
            'nova_group': 4,
            'nutriments': {}, // Missing/empty crowdsourced macros!
            'ingredients_text': 'Cheddar Cheese, Water, Butter, Salt',
          }
        ]
      });

      final mockClient = MockClient((request) async {
        return http.Response(mockJson, 200);
      });

      final service = CatalogSearchService(httpClient: mockClient);
      final results = await service.searchFoodProducts('cheese');

      expect(results, isNotEmpty);
      final item = results.firstWhere((r) => r.code == '0099887766554');
      final evaluated = item.evaluatedProduct;
      expect(evaluated, isNotNull);

      // Cheese category baseline should be applied: ~310 kcal, ~20g protein, ~25g fat, ~16g sat fat
      expect(evaluated!.caloriesPer100g, closeTo(310.0, 2.0));
      expect(evaluated.proteinGPer100g, 20.0);
      expect(evaluated.totalFatGPer100g, 25.0);
      expect(evaluated.satFatGPer100g, 16.0);
      expect(evaluated.sodiumMgPer100g, 650.0);

      // Final score must be realistic (50 - 68), NEVER 95!
      expect(item.healthScore, isNotNull);
      expect(item.healthScore!, inInclusiveRange(50, 68));
      expect(item.healthScore!, isNot(95));
    });

    test('searchFoodProducts ranks authentic Indian paneer dishes above foreign brand-only matches', () async {
      final mockJson = jsonEncode({
        'count': 3,
        'products': [
          {
            'code': '4001234567890',
            'product_name': 'Kranzwurst Sausage',
            'brands': 'Panner',
            'categories': 'Meats, Sausages',
            'nova_group': 3,
            'nutriments': {'fat_100g': 25.0, 'energy-kcal_100g': 310.0},
          },
          {
            'code': '8901262010999',
            'product_name': 'Vadilal Paneer Makhani',
            'brands': 'Vadilal',
            'categories': 'Indian Dishes, Paneer Gravy',
            'nova_group': 3,
            'nutriments': {
              'sugars_100g': 2.5,
              'saturated-fat_100g': 4.5,
              'fat_100g': 10.0,
              'carbohydrates_100g': 8.0,
              'proteins_100g': 7.0,
              'sodium_100g': 0.45,
              'energy-kcal_100g': 160.0,
            },
          },
          {
            'code': '0012345678901',
            'product_name': 'Grape Jelly & Peanut Butter',
            'brands': 'Panner',
            'categories': 'Spreads',
            'nova_group': 4,
            'nutriments': {
              'sugars_100g': 34.0,
              'saturated-fat_100g': 2.8,
              'energy-kcal_100g': 340.0,
            },
          },
        ]
      });

      final mockClient = MockClient((request) async {
        return http.Response(mockJson, 200);
      });

      final service = CatalogSearchService(httpClient: mockClient);
      final results = await service.searchFoodProducts('panner');

      expect(results, isNotEmpty);
      // The authentic Indian paneer dishes MUST be at the top!
      expect(results.first.title.toLowerCase(), contains('paneer'));
      expect(results.any((r) => r.title.contains('Vadilal Paneer Makhani')), isTrue);
      // Foreign items where "Panner" was only a brand must NOT be at the top
      expect(results.first.title, isNot(contains('Kranzwurst')));
      expect(results.first.evaluatedProduct, isNotNull);
      // Confirm the list card score matches the evaluated product score 100%
      expect(results.first.healthScore, results.first.evaluatedProduct!.healthScore);
    });

    test('Evaluated search item enforces biochemical consistency floor rules (zero desync and no 0.0g fat/carbs)', () async {
      // Simulates Grape Jelly with missing fat_100g and carbohydrates_100g in raw OFF payload
      final mockJson = jsonEncode({
        'count': 1,
        'products': [
          {
            'code': '0012345678901',
            'product_name': 'Grape Jelly & Peanut Butter',
            'brands': 'Panner',
            'categories': 'Spreads',
            'nova_group': 4,
            'nutriments': {
              'sugars_100g': 34.0,
              'saturated-fat_100g': 2.8,
              'proteins_100g': 4.0,
              'sodium_100g': 0.15,
              'energy-kcal_100g': 250.0,
            },
            'additives_tags': ['en:e330', 'en:e440', 'en:e202', 'en:e150d', 'en:e471'],
          }
        ]
      });

      final mockClient = MockClient((request) async {
        return http.Response(mockJson, 200);
      });

      final service = CatalogSearchService(httpClient: mockClient);
      final results = await service.searchFoodProducts('grape jelly');

      expect(results, isNotEmpty);
      final item = results.first;
      final evaluated = item.evaluatedProduct;
      expect(evaluated, isNotNull);

      // 1. Single Scoring Pipeline: card score equals evaluated score (exact 100% match)
      expect(item.healthScore, evaluated!.healthScore);
      expect(item.healthScore, inInclusiveRange(40, 60));

      // 2. Biochemical floor rule 1: Total Fat MUST be >= Saturated Fat (2.8g), never 0.0g!
      expect(evaluated.totalFatGPer100g, greaterThanOrEqualTo(2.8));

      // 3. Biochemical floor rule 2: Carbohydrates MUST be >= Sugar (34.0g), never 0.0g!
      expect(evaluated.carbsGPer100g, greaterThanOrEqualTo(34.0));

      // 4. Biochemical floor rule 3: Calories MUST be >= Atwater macroeconomic sum
      final atwaterMin = (evaluated.proteinGPer100g * 4.0) + (evaluated.carbsGPer100g * 4.0) + (evaluated.totalFatGPer100g * 9.0);
      expect(evaluated.caloriesPer100g, greaterThanOrEqualTo(atwaterMin));
    });
  });
}
