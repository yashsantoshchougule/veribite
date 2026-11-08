import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/features/camera/application/product_scanner_service.dart';
import 'package:mobile_app/features/profile/domain/user_profile_model.dart';

void main() {
  group('ProductScannerService QR & Barcode Tests', () {
    final defaultUser = UserProfileModel.defaults('test_user_1');
    final childUser = UserProfileModel.defaults('child_user').copyWith(isChild: true, weightKg: 25.0);
    final diabeticUser = UserProfileModel.defaults('diabetic_user').copyWith(isDiabetic: true);

    test('resolves product from embedded JSON QR code with zero network latency', () async {
      final service = ProductScannerService();

      const qrPayload = '''
{
  "product_name": "Artisan Dark Chocolate",
  "brand_name": "ChocoCraft",
  "barcode": "8909999000111",
  "category": "Confectionery",
  "serving_size_g": 20.0,
  "pack_weight_g": 100.0,
  "piece_weight_g": 10.0,
  "nutrition": {
    "energy_kj": 2300.0,
    "sugar_g_per_100g": 28.0,
    "sat_fat_g_per_100g": 18.0,
    "sodium_mg_per_100g": 15.0
  },
  "additives": [
    {"ins_code": "322", "primary_name": "Soy Lecithin", "risk_tier": "GREEN"}
  ],
  "ingredients": ["Cocoa Mass", "Sugar", "Cocoa Butter", "Soy Lecithin"]
}
''';

      final result = await service.resolveScanInput(
        rawScan: qrPayload,
        userProfile: defaultUser,
      );

      expect(result.productName, 'Artisan Dark Chocolate');
      expect(result.brandName, 'ChocoCraft');
      expect(result.safePortionGrams, greaterThan(0));
      expect(result.additives.length, 1);
      expect(result.splitSugars, contains('sugar'));
    });

    test('resolves product from GS1 Digital Link QR URL', () async {
      final service = ProductScannerService();

      // Britannia Good Day Butter Cookies barcode in GS1 format
      const gs1Qr = 'https://id.gs1.org/01/08901063012117?10=BATCH01';

      final result = await service.resolveScanInput(
        rawScan: gs1Qr,
        userProfile: defaultUser,
      );

      expect(result.productName, 'Good Day Butter Cookies');
      expect(result.brandName, 'Britannia');
      expect(result.healthScore, 48);
      expect(result.safePieces, isNotNull);
    });

    test('resolves product from Open Food Facts QR URL with mock HTTP client', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.contains('7622210408549')) {
          return http.Response(
            jsonEncode({
              'status': 1,
              'product': {
                'product_name': 'Oreo Original Vanilla Cookies',
                'brands': 'Mondelez',
                'categories': 'Cookies',
                'serving_quantity': 28.0,
                'product_quantity': 154.0,
                'nutriments': {
                  'sugars_100g': 38.0,
                  'saturated-fat_100g': 9.8,
                  'sodium_100g': 0.19,
                  'energy-kcal_100g': 471.0,
                },
                'additives_tags': ['en:e322', 'en:e500ii'],
                'ingredients_text': 'Wheat flour, Sugar, Palm oil, Fat reduced cocoa powder',
              }
            }),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final service = ProductScannerService(httpClient: mockClient);

      const offQrUrl = 'https://world.openfoodfacts.org/product/7622210408549';
      final result = await service.resolveScanInput(
        rawScan: offQrUrl,
        userProfile: defaultUser,
      );

      expect(result.productName, contains('Oreo'));
      expect(result.brandName, 'Mondelez');
      expect(result.sugarGPer100g, 38.0);
      expect(result.safePortionGrams, lessThanOrEqualTo(150));
    });

    test('applies child safe limit constraints and flags high sugar budgets', () async {
      final service = ProductScannerService();

      // Maggi noodles (has Red-tier additive INS 635)
      final result = await service.resolveScanInput(
        rawScan: '8901058852339',
        userProfile: childUser,
      );

      expect(result.redCapTriggered, isTrue);
      expect(result.healthScore, lessThanOrEqualTo(39));
      expect(result.verdictTag, contains('Toxic / Capped'));
    });

    test('evaluates diabetic profiles with stricter sugar threshold', () async {
      final service = ProductScannerService();

      final result = await service.resolveScanInput(
        rawScan: '8901063012117',
        userProfile: diabeticUser,
      );

      expect(result.isExceededBudget, isFalse);
    });

    test('throws NonFoodScanException for non-food QR codes like laptop support or WhatsApp link', () async {
      final service = ProductScannerService();

      expect(
        () => service.resolveScanInput(
          rawScan: 'https://wa.me/912261014560',
          userProfile: defaultUser,
        ),
        throwsA(isA<NonFoodScanException>().having(
          (e) => e.message,
          'message',
          contains('not a packaged food item'),
        )),
      );

      expect(
        () => service.resolveScanInput(
          rawScan: 'https://support.hp.com/in-en',
          userProfile: defaultUser,
        ),
        throwsA(isA<NonFoodScanException>()),
      );
    });

    test('throws ProductNotFoundException for uncatalogued barcodes instead of fabricating fake food', () async {
      final mockClient = MockClient((request) async => http.Response('Not found', 404));
      final service = ProductScannerService(httpClient: mockClient);

      expect(
        () => service.resolveScanInput(
          rawScan: '9999999999999',
          userProfile: defaultUser,
        ),
        throwsA(isA<ProductNotFoundException>().having(
          (e) => e.barcode,
          'barcode',
          '9999999999999',
        )),
      );
    });

    test('resolves food product from quick-commerce web URL with live HTML extraction', () async {
      const mockHtml = '''
<!DOCTYPE html>
<html>
<head>
  <title>Milky Mist Cheddar Cheese Block 200g | Blinkit</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org/",
    "@type": "Product",
    "name": "Milky Mist Cheddar Cheese Block 200g",
    "brand": {"@type": "Brand", "name": "Milky Mist"},
    "category": "Cheese & Dairy",
    "nutrition": {
      "@type": "NutritionInformation",
      "calories": "380 kcal",
      "sugarContent": "0.5 g",
      "saturatedFatContent": "21.0 g",
      "sodiumContent": "650 mg",
      "proteinContent": "24.0 g"
    },
    "ingredients": ["Pasteurised Cow Milk", "Active Cheese Culture", "Microbial Rennet", "Common Salt"]
  }
  </script>
</head>
<body><h1>Milky Mist Cheddar Cheese Block</h1></body>
</html>
''';

      final mockClient = MockClient((request) async {
        if (request.url.toString().contains('blinkit.com')) {
          return http.Response(mockHtml, 200);
        }
        return http.Response('Not Found', 404);
      });

      final service = ProductScannerService(httpClient: mockClient);
      const blinkitUrl = 'https://blinkit.com/prn/milky-mist-cheddar-cheese-block-200g/prid/555';

      final result = await service.resolveScanInput(
        rawScan: blinkitUrl,
        userProfile: defaultUser,
      );

      expect(result.productName, contains('Milky Mist Cheddar Cheese'));
      expect(result.brandName, 'Milky Mist');
      expect(result.category, 'Cheese & Dairy');
      expect(result.sugarGPer100g, 0.5);
      expect(result.satFatGPer100g, 21.0);
      expect(result.healthScore, greaterThan(0));
      expect(result.safePortionGrams, greaterThan(0));
    });

    test('throws FoodWebExtractionException when food web URL is unreachable', () async {
      final mockClient = MockClient((request) async => http.Response('Network Error', 500));
      final service = ProductScannerService(httpClient: mockClient);

      expect(
        () => service.resolveScanInput(
          rawScan: 'https://zeptonow.com/pn/broken-link/p/111',
          userProfile: defaultUser,
        ),
        throwsA(isA<FoodWebExtractionException>()),
      );
    });

    test('resolves real product (MTR Badam Drink Mix) from multi-angle vision frames via Gemini Vision', () async {
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

      final service = ProductScannerService(httpClient: mockClient);
      final frames = [
        List<int>.generate(200, (i) => i % 255),
        List<int>.generate(200, (i) => (i + 10) % 255),
      ];

      final result = await service.resolveMultiAngleScan(
        frames: frames,
        userProfile: defaultUser,
      );

      expect(result.productName, 'MTR Badam Drink Mix');
      expect(result.brandName, 'MTR');
      expect(result.category, 'Beverages & Juices');
      expect(result.sugarGPer100g, 58.0);
      expect(result.healthScore, greaterThan(0));
      expect(result.safePortionGrams, greaterThan(0));
    });

    test('throws VisionExtractionException if captured frames cannot be parsed by Vision AI', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final service = ProductScannerService(httpClient: mockClient);
      final frames = [
        List<int>.generate(100, (i) => i % 255),
      ];

      expect(
        () => service.resolveMultiAngleScan(
          frames: frames,
          userProfile: defaultUser,
        ),
        throwsA(isA<VisionExtractionException>()),
      );
    });
  });
}
