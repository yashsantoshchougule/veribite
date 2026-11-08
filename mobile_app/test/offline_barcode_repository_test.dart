import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/camera/application/offline_barcode_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflineBarcodeRepository repo;

  setUp(() async {
    repo = OfflineBarcodeRepository.instance;
    repo.resetForTesting();
    await repo.ensureInitialized();
  });

  group('OfflineBarcodeRepository - Tier 1 Seed & Lookup', () {
    test('loads Tier 1 seed dataset with 400+ Indian FMCG products', () {
      expect(repo.tier1Count, greaterThan(400));
      expect(repo.totalProductCount, greaterThan(400));
    });

    test('retrieves Britannia Good Day Butter Cookies instantly by barcode', () async {
      final product = await repo.lookupBarcode('8901063012117');
      expect(product, isNotNull);
      expect(product!['product_name'], 'Good Day Butter Cookies');
      expect(product['brand_name'], 'Britannia');
      expect(product['category'], 'Biscuits & Cookies');
      expect(product['health_score'], 48);
      expect(product['nova_grade'], 4);
    });

    test('retrieves Nestle Maggi 2-Minute Noodles instantly by barcode', () async {
      final product = await repo.lookupBarcode('8901058852339');
      expect(product, isNotNull);
      expect(product!['product_name'], 'Maggi 2-Minute Noodles Masala');
      expect(product['brand_name'], 'Nestle');
      expect(product['red_cap_triggered'], 1);
    });

    test('retrieves Amul Butter and Haldiram Aloo Bhujia instantly by barcode', () async {
      final amul = await repo.lookupBarcode('8901262010012');
      expect(amul, isNotNull);
      expect(amul!['product_name'], contains('Amul Pasteurised Salted Butter'));

      final haldiram = await repo.lookupBarcode('8901491101837');
      expect(haldiram, isNotNull);
      expect(haldiram!['product_name'], contains('Aloo Bhujia'));
    });

    test('returns null for unregistered barcode', () async {
      final product = await repo.lookupBarcode('0000000000000');
      expect(product, isNull);
    });
  });

  group('OfflineBarcodeRepository - Tier 2 Read-Through & Self-Learning', () {
    test('saves online-fetched product into Tier 2 cache and retrieves it', () async {
      const customBarcode = '8909999123456';
      final productData = {
        'barcode': customBarcode,
        'product_name': 'Himalayan Organic Tea',
        'brand_name': 'Himalayan Organics',
        'category': 'Tea & Beverages',
        'serving_size_g': 2.0,
        'pack_weight_g': 100.0,
        'health_score': 88,
        'nova_grade': 1,
        'red_cap_triggered': 0,
        'nutrition': {'energy_kj': 0, 'sugar_g_per_100g': 0, 'sodium_mg_per_100g': 0},
        'additives': <Map<String, dynamic>>[],
        'ingredients': ['100% Organic Green Tea Leaves'],
      };

      await repo.saveProduct(
        barcode: customBarcode,
        productData: productData,
        isUserLearned: true,
      );

      final retrieved = await repo.lookupBarcode(customBarcode);
      expect(retrieved, isNotNull);
      expect(retrieved!['product_name'], 'Himalayan Organic Tea');
      expect(retrieved['is_user_learned'], 1);
      expect(repo.tier2Count, 1);
    });

    test('Tier 2 cache takes precedence over Tier 1 seed for updated records', () async {
      const barcode = '8901063012117';
      final updatedData = {
        'barcode': barcode,
        'product_name': 'Good Day Butter Cookies - Reformulated 2026',
        'brand_name': 'Britannia',
        'category': 'Biscuits & Cookies',
        'health_score': 55,
      };

      await repo.saveProduct(barcode: barcode, productData: updatedData);

      final result = await repo.lookupBarcode(barcode);
      expect(result, isNotNull);
      expect(result!['product_name'], 'Good Day Butter Cookies - Reformulated 2026');
      expect(result['health_score'], 55);
    });
  });

  group('OfflineBarcodeRepository - GS1 India 890 Prefix & Sibling Matching', () {
    test('identifies manufacturer / brand for known Indian GS1 prefixes', () {
      expect(repo.getBrandOrManufacturerForBarcode('8901063000000'), 'Britannia Industries');
      expect(repo.getBrandOrManufacturerForBarcode('8901058000000'), 'Nestlé India');
      expect(repo.getBrandOrManufacturerForBarcode('8901719000000'), 'Parle Products');
      expect(repo.getBrandOrManufacturerForBarcode('8901491000000'), "Haldiram's Snacks");
      expect(repo.getBrandOrManufacturerForBarcode('8901262000000'), 'Amul (GCMMF)');
      expect(repo.getBrandOrManufacturerForBarcode('8901499000000'), 'PepsiCo India (Lay\'s / Kurkure)');
      expect(repo.getBrandOrManufacturerForBarcode('8901036000000'), 'Everest Spices');
      expect(repo.getBrandOrManufacturerForBarcode('8901233000000'), 'MDH Spices');
      expect(repo.getBrandOrManufacturerForBarcode('8901287000000'), 'Catch Spices (DS Group)');
    });

    test('finds sibling products sharing the same manufacturer prefix', () async {
      // 8901058999999 is an unknown barcode for Nestle/Maggi prefix (8901058)
      final siblings = await repo.findSiblingProducts('8901058999999');
      expect(siblings, isNotEmpty);
      expect(siblings.any((s) => s['product_name'].toString().contains('Maggi')), isTrue);
      expect(siblings.any((s) => s['brand_name'] == 'Nestle'), isTrue);
    });

    test('finds sibling products for Britannia prefix', () async {
      // 8901063999999 is an unknown barcode for Britannia prefix (8901063)
      final siblings = await repo.findSiblingProducts('8901063999999');
      expect(siblings, isNotEmpty);
      expect(siblings.any((s) => s['brand_name'] == 'Britannia'), isTrue);
    });

    test('finds sibling products for Parle prefix', () async {
      final siblings = await repo.findSiblingProducts('8901719999999');
      expect(siblings, isNotEmpty);
      expect(siblings.any((s) => s['brand_name'] == 'Parle'), isTrue);
    });
  });
}
