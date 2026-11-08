import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/core/vision/food_web_extractor.dart';

void main() {
  group('FoodWebExtractor Tests', () {
    test('parses Schema.org JSON-LD product data with nutrition info', () async {
      const mockHtml = '''
<!DOCTYPE html>
<html>
<head>
  <title>Milky Mist Paneer Fresh 200g | Blinkit</title>
  <script type="application/ld+json">
  {
    "@context": "https://schema.org/",
    "@type": "Product",
    "name": "Milky Mist Fresh Paneer 200g",
    "brand": {
      "@type": "Brand",
      "name": "Milky Mist"
    },
    "description": "Fresh and soft malai paneer packed with milk solids.",
    "category": "Cheese & Dairy",
    "nutrition": {
      "@type": "NutritionInformation",
      "calories": "260 kcal",
      "sugarContent": "2.1 g",
      "saturatedFatContent": "14.5 g",
      "sodiumContent": "45 mg",
      "proteinContent": "18.0 g"
    },
    "ingredients": ["Pasteurised Cow Milk", "Lactic Acid"]
  }
  </script>
</head>
<body>
  <h1>Milky Mist Fresh Paneer 200g</h1>
</body>
</html>
''';

      final mockClient = MockClient((request) async {
        return http.Response(mockHtml, 200);
      });

      final extractor = FoodWebExtractor(httpClient: mockClient);
      final product = await extractor.extractProductFromUrl('https://blinkit.com/prn/milky-mist-paneer/prid/123');

      expect(product, isNotNull);
      expect(product!['product_name'], 'Milky Mist Fresh Paneer 200g');
      expect(product['brand_name'], 'Milky Mist');
      expect(product['category'], 'Cheese & Dairy');
      expect(product['pack_weight_g'], 200.0);

      final nutrition = jsonDecode(product['nutrition_json'] as String);
      expect(nutrition['sugar_g_per_100g'], 2.1);
      expect(nutrition['sat_fat_g_per_100g'], 14.5);
      expect(nutrition['sodium_mg_per_100g'], 45.0);
      expect(nutrition['protein_g'], 18.0);

      final ingredients = jsonDecode(product['ingredients_json'] as String) as List;
      expect(ingredients, contains('Pasteurised Cow Milk'));
    });

    test('parses OpenGraph meta tags and regex nutrition table from HTML body', () async {
      const mockHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta property="og:title" content="Amul Salted Butter 100g - BigBasket" />
  <meta property="og:description" content="Pure churned butter from rich pasteurised milk." />
  <meta property="product:brand" content="Amul" />
</head>
<body>
  <div class="product-details">
    <p>Ingredients: Butter, Edible Common Salt (2.5%), Permitted Natural Colour (INS 160a)</p>
    <table>
      <tr><td>Energy</td><td>720 kcal</td></tr>
      <tr><td>Total Sugar</td><td>0.0 g</td></tr>
      <tr><td>Saturated Fat</td><td>52.0 g</td></tr>
      <tr><td>Sodium</td><td>830 mg</td></tr>
      <tr><td>Protein</td><td>0.6 g</td></tr>
    </table>
  </div>
</body>
</html>
''';

      final mockClient = MockClient((request) async {
        return http.Response(mockHtml, 200);
      });

      final extractor = FoodWebExtractor(httpClient: mockClient);
      final product = await extractor.extractProductFromUrl('https://www.bigbasket.com/pd/12345/amul-salted-butter-100g');

      expect(product, isNotNull);
      expect(product!['product_name'], 'Amul Salted Butter 100g');
      expect(product['brand_name'], 'Amul');
      expect(product['category'], 'Cheese & Dairy');

      final nutrition = jsonDecode(product['nutrition_json'] as String);
      expect(nutrition['sugar_g_per_100g'], 0.0);
      expect(nutrition['sat_fat_g_per_100g'], 52.0);
      expect(nutrition['sodium_mg_per_100g'], 830.0);

      final additives = jsonDecode(product['additives_json'] as String) as List;
      expect(additives.any((a) => a['ins_code'] == '160A'), isTrue);
    });

    test('detects high-risk additives and categorizes correctly', () async {
      const mockHtml = '''
<!DOCTYPE html>
<html>
<head><title>Spicy Instant Ramen 70g</title></head>
<body>
  <div>Ingredients: Wheat flour, Palm oil, Flavor enhancer (INS 635), Permitted Color (INS 102), Preservative (INS 211)</div>
  <div>Calories: 350 kcal, Total Sugar: 2.0g, Saturated Fat: 8.0g, Sodium: 950 mg</div>
</body>
</html>
''';

      final mockClient = MockClient((request) async => http.Response(mockHtml, 200));
      final extractor = FoodWebExtractor(httpClient: mockClient);
      final product = await extractor.extractProductFromUrl('https://zeptonow.com/pn/spicy-instant-ramen/p/999');

      expect(product, isNotNull);
      final additives = jsonDecode(product!['additives_json'] as String) as List;
      final ins635 = additives.firstWhere((a) => a['ins_code'] == '635');
      expect(ins635['risk_tier'], 'RED');

      final ins102 = additives.firstWhere((a) => a['ins_code'] == '102');
      expect(ins102['risk_tier'], 'RED');

      final ins211 = additives.firstWhere((a) => a['ins_code'] == '211');
      expect(ins211['risk_tier'], 'YELLOW');
    });

    test('falls back gracefully to URL slug and catalog category when HTML is minimal', () async {
      const minimalHtml = '<html><head><title>App Loading...</title></head><body><noscript>Please enable JS</noscript></body></html>';
      final mockClient = MockClient((request) async => http.Response(minimalHtml, 200));

      final extractor = FoodWebExtractor(httpClient: mockClient);
      final product = await extractor.extractProductFromUrl('https://blinkit.com/prn/the-whole-truth-dark-chocolate-peanut-butter-350g/prid/789');

      expect(product, isNotNull);
      expect(product!['product_name'], contains('The Whole Truth Dark Chocolate Peanut Butter'));
      expect(product['brand_name'], 'The Whole Truth');
      expect(product['category'], 'Spreads & Dips');
      expect(product['pack_weight_g'], 350.0);
    });

    test('returns null when HTTP request returns 404 error or invalid URL', () async {
      final mockClient = MockClient((request) async => http.Response('Page Not Found', 404));
      final extractor = FoodWebExtractor(httpClient: mockClient);

      final result = await extractor.extractProductFromUrl('https://blinkit.com/prn/non-existent-product');
      expect(result, isNull);

      final resultInvalid = await extractor.extractProductFromUrl('');
      expect(resultInvalid, isNull);
    });

    test('parses Everest Chole Masala brand page and extracts spice category and ingredients', () async {
      const everestHtml = '''
<!DOCTYPE html>
<html>
<head>
  <title>Everest Chole Masala 100g - Authentic Blend of Spices</title>
  <meta property="og:title" content="Everest Chole Masala 100g" />
  <meta property="product:brand" content="Everest" />
</head>
<body>
  <h1>Everest Chole Masala 100g</h1>
  <div class="product-info">
    <p>Ingredients: Coriander, Cumin, Chilli, Pomegranate Seeds, Dry Mango, Black Pepper, Cassia Leaf, Iodized Salt, Fenugreek</p>
    <table>
      <tr><td>Energy</td><td>350 kcal</td></tr>
      <tr><td>Total Sugar</td><td>3.0 g</td></tr>
      <tr><td>Saturated Fat</td><td>2.0 g</td></tr>
      <tr><td>Sodium</td><td>1200 mg</td></tr>
      <tr><td>Protein</td><td>10.0 g</td></tr>
    </table>
  </div>
</body>
</html>
''';

      final mockClient = MockClient((request) async => http.Response(everestHtml, 200));
      final extractor = FoodWebExtractor(httpClient: mockClient);
      final product = await extractor.extractProductFromUrl('https://everestspices.com/product/chole-masala-100g');

      expect(product, isNotNull);
      expect(product!['product_name'], contains('Everest Chole Masala'));
      expect(product['brand_name'], 'Everest');
      expect(product['category'], 'Spices & Masalas');
      expect(product['pack_weight_g'], 100.0);

      final nutrition = jsonDecode(product['nutrition_json'] as String);
      expect(nutrition['sugar_g_per_100g'], 3.0);
      expect(nutrition['protein_g'], 10.0);

      final ingredients = jsonDecode(product['ingredients_json'] as String) as List;
      expect(ingredients, contains('Coriander'));
      expect(ingredients, contains('Cumin'));
    });
  });
}

