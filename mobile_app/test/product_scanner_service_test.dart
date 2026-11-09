import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/core/vision/on_device_vision_service.dart';
import 'package:mobile_app/features/camera/application/offline_barcode_repository.dart';
import 'package:mobile_app/features/camera/application/product_scanner_service.dart';
import 'package:mobile_app/features/profile/domain/user_profile_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

    test('falls forward to PromotionalQrContextException when web URL has no nutrition facts', () async {
      final mockClient = MockClient((request) async => http.Response('Network Error', 500));
      final service = ProductScannerService(httpClient: mockClient);

      expect(
        () => service.resolveScanInput(
          rawScan: 'https://zeptonow.com/pn/broken-link/p/111',
          userProfile: defaultUser,
        ),
        throwsA(isA<PromotionalQrContextException>().having(
          (e) => e.message,
          'message',
          contains('Point camera at the back nutrition table'),
        )),
      );
    });

    test('unrollUrlAndExtractGtin extracts GTIN from URL queries and handles leading zero normalization', () async {
      final service = ProductScannerService();

      final gtin1 = await service.unrollUrlAndExtractGtin('https://qrs.ly/spice?gtin=08901234567890');
      expect(gtin1, '8901234567890');

      final gtin2 = await service.unrollUrlAndExtractGtin('https://id.gs1.org/01/08901030383786');
      expect(gtin2, '8901030383786');
    });

    test('cleanProductQuery removes promotional and recipe noise words', () {
      expect(
        ProductScannerService.cleanProductQuery('Catch Chana Masala Easy Recipe Step by Step'),
        'Catch Chana Masala',
      );

      expect(
        ProductScannerService.cleanProductQuery('Everest Pav Bhaji Masala Official Video in Hindi'),
        'Everest Pav Bhaji Masala',
      );

      expect(
        ProductScannerService.cleanProductQuery('MDH Deggi Mirch Promotional Contest Win QR'),
        'MDH Deggi Mirch',
      );
    });

    test('extractProductIdentityFromUrl extracts title and brand from YouTube oEmbed endpoint', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host.contains('youtube.com') && request.url.path.contains('oembed')) {
          return http.Response(
            jsonEncode({
              'author_name': 'Catch Foods',
              'title': 'Catch Chana Masala Delicious Recipe Tutorial',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = ProductScannerService(httpClient: mockClient);
      final identity = await service.extractProductIdentityFromUrl('https://www.youtube.com/watch?v=catch123');

      expect(identity, isNotNull);
      expect(identity!['title'], 'Catch Chana Masala Delicious Recipe Tutorial');
      expect(identity['brand'], 'Catch Foods');
    });

    test('resolves promotional YouTube recipe QR via Open Food Facts India search API', () async {
      final mockClient = MockClient((request) async {
        final urlStr = request.url.toString();

        // 1. YouTube oEmbed
        if (urlStr.contains('youtube.com/oembed')) {
          return http.Response(
            jsonEncode({
              'author_name': 'Catch Foods',
              'title': 'Catch Chana Masala Authentic Recipe',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        // 2. Open Food Facts search API
        if (urlStr.contains('openfoodfacts.org/cgi/search.pl')) {
          return http.Response(
            jsonEncode({
              'count': 1,
              'products': [
                {
                  'code': '8901234000999',
                  'product_name': 'Catch Chana Masala Powder',
                  'brands': 'Catch',
                  'nutriments': {
                    'energy-kcal_100g': 360.0,
                    'sugars_100g': 4.5,
                    'saturated-fat_100g': 2.0,
                    'sodium_100g': 1.2,
                    'proteins_100g': 12.0,
                  },
                  'ingredients_text': 'Coriander, Cumin, Dry Mango, Pomegranate seeds, Black Pepper, Salt',
                  'allergens_tags': [],
                }
              ]
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final service = ProductScannerService(httpClient: mockClient);
      final result = await service.resolveScanInput(
        rawScan: 'https://www.youtube.com/watch?v=chana_recipe',
        userProfile: defaultUser,
      );

      expect(result.productName, 'Catch Chana Masala Powder');
      expect(result.brandName, 'Catch');
      expect(result.sugarGPer100g, 4.5);
      expect(result.satFatGPer100g, 2.0);
      expect(result.healthScore, greaterThan(0));
    });

    test('hands off promotional QR with live frame to Gemini Vision when OFF has no nutrition', () async {
      final mockGeminiResponse = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'product_name': 'Catch Chana Masala',
                    'brand_name': 'Catch',
                    'category': 'Spices & Seasonings',
                    'serving_size_g': 10.0,
                    'pack_weight_g': 100.0,
                    'nutrition': {
                      'energy_kj': 1500.0,
                      'sugar_g_per_100g': 4.0,
                      'sat_fat_g_per_100g': 1.5,
                      'sodium_mg_per_100g': 800.0,
                      'protein_g': 11.0,
                      'fiber_g': 5.0,
                    },
                    'ingredients': ['Coriander', 'Pomegranate seeds', 'Cumin', 'Dry Mango', 'Salt'],
                    'additives': [],
                  })
                }
              ]
            }
          }
        ]
      };

      final mockClient = MockClient((request) async {
        final urlStr = request.url.toString();
        // YouTube oEmbed
        if (urlStr.contains('youtube.com/oembed')) {
          return http.Response(
            jsonEncode({
              'author_name': 'Catch Spices',
              'title': 'Catch Chana Masala Recipe Video',
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        // OFF search returns empty
        if (urlStr.contains('openfoodfacts.org/cgi/search.pl')) {
          return http.Response(
            jsonEncode({'count': 0, 'products': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        // Gemini Vision API responds
        if (urlStr.contains('generativelanguage.googleapis.com')) {
          return http.Response(
            jsonEncode(mockGeminiResponse),
            200,
            headers: {'content-type': 'application/json'},
          );
        }

        return http.Response('Not Found', 404);
      });

      final service = ProductScannerService(httpClient: mockClient);
      final dummyFrame = List<int>.generate(150, (i) => i % 255);

      final result = await service.resolveScanInput(
        rawScan: 'https://youtu.be/catch_chana_promo',
        userProfile: defaultUser,
        frameImage: dummyFrame,
      );

      expect(result.productName, 'Catch Chana Masala');
      expect(result.brandName, 'Catch');
      expect(result.sugarGPer100g, 4.0);
      expect(result.satFatGPer100g, 1.5);
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

    test('resolves Indian packaged product offline directly from Tier 1 seed database', () async {
      final service = ProductScannerService();

      // Parle-G 8901719101018 from Tier 1 seed
      final result = await service.resolveBarcode(
        barcode: '8901719101018',
        userProfile: defaultUser,
      );

      expect(result.productName, contains('Parle-G'));
      expect(result.brandName, 'Parle');
      expect(result.category, 'Biscuits & Cookies');
      expect(result.healthScore, greaterThan(0));
    });

    test('throws OfflineVariantMatchException with recognized brand and siblings for offline pack-size variant', () async {
      final service = ProductScannerService();

      // Unknown barcode with Nestle India prefix (8901058)
      expect(
        () => service.resolveBarcode(
          barcode: '8901058999999',
          userProfile: defaultUser,
        ),
        throwsA(isA<OfflineVariantMatchException>().having(
          (e) => e.brandName,
          'brandName',
          'Nestlé India',
        )),
      );
    });

    test('evaluates raw product data directly via evaluateProductData()', () {
      final service = ProductScannerService();
      final productData = {
        'barcode': '8901234567890',
        'product_name': 'Pure Almond Milk',
        'brand_name': 'Raw Nature',
        'category': 'Plant Milk',
        'serving_size_g': 200.0,
        'pack_weight_g': 1000.0,
        'health_score': 85,
        'nova_grade': 1,
        'nutrition': {
          'sugar_g_per_100g': 1.0,
          'sat_fat_g_per_100g': 0.2,
          'sodium_mg_per_100g': 30.0,
          'energy_kj': 150.0,
        },
      };

      final result = service.evaluateProductData(
        productData: productData,
        userProfile: defaultUser,
      );

      expect(result.productName, 'Pure Almond Milk');
      expect(result.brandName, 'Raw Nature');
      expect(result.healthScore, 85);
      expect(result.verdictTag, 'Nutri Safe 🟢');
    });

    test('automatically cascades to On-Device Vision Service when Gemini Vision and Backend Proxy fail', () async {
      // Mock HTTP client: both Gemini Vision and cloud backend fail
      final mockClient = MockClient((request) async {
        return http.Response('Service Unavailable', 503);
      });

      // Inject OnDeviceVisionService with local text extraction
      final localOcrService = OnDeviceVisionService(
        injectedOcrEngine: (bytes) async {
          return '''
Haldiram's Aloo Bhujia
NUTRITION FACTS per 100g:
Energy: 560 kcal
Total Sugars: 2.0 g
Saturated Fat: 14.0 g
Sodium: 650 mg
Protein: 9.0 g
Serving Size: 30 g
Net Weight: 200 g
Ingredients: Potatoes, Edible Vegetable Oil, Gram Pulse Flour, Spices and Condiments, Iodised Salt, Acidity Regulator (INS 330).
''';
        },
      );

      final service = ProductScannerService(
        httpClient: mockClient,
        onDeviceVisionService: localOcrService,
      );

      final dummyFrames = [
        List<int>.generate(150, (i) => i % 255),
      ];

      final result = await service.resolveMultiAngleScan(
        frames: dummyFrames,
        userProfile: defaultUser,
      );

      expect(result.brandName, "Haldiram");
      expect(result.sugarGPer100g, 2.0);
      expect(result.satFatGPer100g, 14.0);
      expect(result.sodiumMgPer100g, 650.0);
      expect(result.analysisSource, 'on_device_vision');
    });

    test('resolves Haldiram\'s Frozen Paneer Slab by barcode 8904004442526 without Bikaji confusion', () async {
      final service = ProductScannerService();
      final result = await service.resolveBarcode(
        barcode: '8904004442526',
        userProfile: defaultUser,
      );

      expect(result.brandName, "Haldiram's");
      expect(result.productName, contains('Frozen Paneer Slab'));
      expect(result.category, 'Dairy & Frozen Paneer');
      expect(result.caloriesPer100g, 290.0);
      expect(result.proteinGPer100g, 18.0);
      expect(result.totalFatGPer100g, 22.0);
      expect(result.satFatGPer100g, 14.0);
      expect(result.carbsGPer100g, 4.5);
      expect(result.sugarGPer100g, 2.0);
      expect(result.sodiumMgPer100g, 35.0);
      expect(result.novaGrade, 3);
      expect(result.healthScore, 78);
      expect(result.additives.any((a) => a['ins_code'] == '575'), isTrue);
      expect(result.additives.any((a) => a['ins_code'] == '330'), isTrue);
      expect(result.additives.any((a) => a['ins_code'] == '509'), isTrue);
    });

    test('fuses same-frame wrapper OCR and GS1 brand when uncatalogued barcode misses database', () async {
      // Mock Gemini that resolves Haldiram's Paneer from hint and frame
      final mockGeminiResponse = {
        'candidates': [
          {
            'content': {
              'parts': [
                {
                  'text': jsonEncode({
                    'product_name': 'Haldiram Frozen Paneer Slab',
                    'brand_name': "Haldiram's",
                    'category': 'Dairy & Frozen Paneer',
                    'serving_size_g': 30.0,
                    'pack_weight_g': 200.0,
                    'nutrition': {
                      'energy_kj': 1213.0,
                      'sugar_g_per_100g': 2.0,
                      'sat_fat_g_per_100g': 14.0,
                      'sodium_mg_per_100g': 35.0,
                      'protein_g': 18.0,
                      'carbohydrates_g_per_100g': 4.5,
                      'total_fat_g_per_100g': 22.0,
                    },
                    'ingredients': ['Milk Solids (Paneer)', 'Acidity Regulator (INS 575)', 'Acidity Regulator (INS 330)', 'Firming Agent (INS 509)'],
                    'additives': [
                      {'ins_code': '575', 'primary_name': 'Glucono delta-lactone'},
                      {'ins_code': '330', 'primary_name': 'Citric Acid'},
                      {'ins_code': '509', 'primary_name': 'Calcium Chloride'},
                    ],
                  })
                }
              ]
            }
          }
        ]
      };

      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode(mockGeminiResponse),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = ProductScannerService(
        httpClient: mockClient,
      );

      final dummyFrame = List<int>.generate(120, (i) => i % 255);

      // Scanning uncatalogued barcode under Haldiram prefix 89040044
      final result = await service.resolveScanInput(
        rawScan: '8904004499999',
        userProfile: defaultUser,
        frameImage: dummyFrame,
      );

      expect(result.brandName, "Haldiram's");
      expect(result.productName, contains('Paneer Slab'));
      expect(result.proteinGPer100g, 18.0);
    });
  });
}
