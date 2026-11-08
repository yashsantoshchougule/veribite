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
  });
}
