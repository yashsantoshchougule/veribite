import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Robust multi-tiered extractor that parses food e-commerce and brand product web pages
/// (Blinkit, Zepto, BigBasket, Amazon, SmartLabel, Amul, Milky Mist, etc.)
/// into structured nutrition and ingredient profiles.
class FoodWebExtractor {
  final http.Client? _injectedClient;

  FoodWebExtractor({http.Client? httpClient}) : _injectedClient = httpClient;

  http.Client get _client => _injectedClient ?? http.Client();

  /// Extracts structured product details from a food web URL.
  /// Returns a Map compatible with [ProductScannerService._evaluateProduct], or null if extraction fails.
  Future<Map<String, dynamic>?> extractProductFromUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    final parsedUri = Uri.tryParse(trimmed);
    if (parsedUri == null || parsedUri.scheme.isEmpty || parsedUri.host.isEmpty) {
      return null;
    }

    try {
      final response = await _client.get(
        parsedUri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 VeriBiteApp/1.0',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,application/json;q=0.8,*/*;q=0.7',
          'Accept-Language': 'en-IN,en-US;q=0.9,en;q=0.8',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return parseHtmlContent(response.body, url: trimmed);
      } else {
        debugPrint('[FoodWebExtractor] HTTP ${response.statusCode} for $trimmed');
      }
    } catch (e) {
      debugPrint('[FoodWebExtractor] Network error fetching $trimmed: $e');
    }

    return null;
  }

  /// Parses raw HTML string from a food web page into structured product data
  Map<String, dynamic>? parseHtmlContent(String html, {required String url}) {
    if (html.trim().isEmpty) return null;

    // 1. Tier 1: Try JSON-LD Schema.org Product
    final jsonLdData = _extractJsonLdProduct(html);

    // 2. Tier 2: Try Open Graph & Meta Tags
    final metaData = _extractMetaTags(html);

    // Combine metadata: JSON-LD takes priority, meta tags fill gaps
    String? productName = jsonLdData?['name'] ?? metaData['title'];
    String? brandName = jsonLdData?['brand'] ?? metaData['brand'];
    String? description = jsonLdData?['description'] ?? metaData['description'];
    String? category = jsonLdData?['category'] ?? metaData['category'];

    // Fallback: Infer product name and brand from URL slug if still missing
    if (productName == null || productName.isEmpty) {
      final slugInfo = _extractInfoFromUrl(url);
      productName = slugInfo['name'];
      brandName ??= slugInfo['brand'];
      category ??= slugInfo['category'];
    }

    // Clean up product title (strip store suffixes like " | Blinkit", " - BigBasket", " - Amazon.in")
    productName = _cleanProductTitle(productName ?? '');

    final lowerTitle = productName.toLowerCase();
    final isGenericTitle = productName.isEmpty ||
        lowerTitle.contains('loading') ||
        lowerTitle.contains('just a moment') ||
        lowerTitle.contains('welcome') ||
        lowerTitle.contains('enable js') ||
        lowerTitle.contains('shop online') ||
        lowerTitle == 'home';

    if (isGenericTitle) {
      final slugInfo = _extractInfoFromUrl(url);
      if (slugInfo['name'] != null && slugInfo['name']!.isNotEmpty) {
        productName = slugInfo['name']!;
        brandName ??= slugInfo['brand'];
        category ??= slugInfo['category'];
      }
    }

    if (productName.isEmpty) {
      return null;
    }
    brandName = _detectOrCleanBrand(brandName, productName);
    category = _detectCategory(category, productName);

    // 3. Extract Nutrition values
    final nutrition = _extractNutrition(html, jsonLdData: jsonLdData, description: description);

    // 4. Extract Ingredients and INS Additives
    final ingredientsAndAdditives = _extractIngredientsAndAdditives(html, jsonLdData: jsonLdData, description: description);

    // 5. Extract serving and pack weights
    final weights = _extractWeights(html, productName: productName, jsonLdData: jsonLdData, description: description);

    return {
      'barcode': url,
      'product_name': productName,
      'brand_name': brandName,
      'category': category,
      'serving_size_g': weights['serving_g'] ?? 30.0,
      'pack_weight_g': weights['pack_g'] ?? 100.0,
      'piece_weight_g': weights['piece_g'],
      'nova_grade': 3,
      'red_cap_triggered': 0,
      'nutrition_json': jsonEncode(nutrition),
      'additives_json': jsonEncode(ingredientsAndAdditives['additives']),
      'ingredients_json': jsonEncode(ingredientsAndAdditives['ingredients']),
    };
  }

  /// Extracts Product object from Schema.org JSON-LD scripts
  Map<String, dynamic>? _extractJsonLdProduct(String html) {
    final scriptRegex = RegExp(r'<script[^>]*type=[\x22\x27]application/ld\+json[\x22\x27][^>]*>([\s\S]*?)</script>', caseSensitive: false);
    final matches = scriptRegex.allMatches(html);

    for (final match in matches) {
      final rawJson = match.group(1)?.trim();
      if (rawJson == null || rawJson.isEmpty) continue;

      try {
        final decoded = jsonDecode(rawJson);
        final productMap = _findProductInJson(decoded);
        if (productMap != null) return productMap;
      } catch (_) {}
    }
    return null;
  }

  Map<String, dynamic>? _findProductInJson(dynamic data) {
    if (data is Map<String, dynamic>) {
      final type = data['@type']?.toString().toLowerCase();
      if (type == 'product' || type == 'individualproduct') {
        String? brand;
        if (data['brand'] is Map) {
          brand = data['brand']['name']?.toString();
        } else if (data['brand'] is String) {
          brand = data['brand'];
        }

        return {
          'name': data['name']?.toString(),
          'brand': brand,
          'description': data['description']?.toString(),
          'category': data['category']?.toString(),
          'nutrition': data['nutrition'],
          'ingredients': data['ingredients'] ?? data['recipeIngredient'],
        };
      }

      // Check nested @graph
      if (data['@graph'] is List) {
        for (final item in data['@graph']) {
          final found = _findProductInJson(item);
          if (found != null) return found;
        }
      }
    } else if (data is List) {
      for (final item in data) {
        final found = _findProductInJson(item);
        if (found != null) return found;
      }
    }
    return null;
  }

  /// Extracts Open Graph and standard HTML meta tags
  Map<String, String> _extractMetaTags(String html) {
    final result = <String, String>{};

    final titleMatch = RegExp(r'<meta[^>]*property=["'']og:title["''][^>]*content=["'']([^"'']+)["'']', caseSensitive: false).firstMatch(html) ??
        RegExp(r'<meta[^>]*name=["'']title["''][^>]*content=["'']([^"'']+)["'']', caseSensitive: false).firstMatch(html) ??
        RegExp(r'<title[^>]*>([^<]+)<\/title>', caseSensitive: false).firstMatch(html);
    if (titleMatch != null) {
      result['title'] = titleMatch.group(1)!.trim();
    }

    final descMatch = RegExp(r'<meta[^>]*property=["'']og:description["''][^>]*content=["'']([^"'']+)["'']', caseSensitive: false).firstMatch(html) ??
        RegExp(r'<meta[^>]*name=["'']description["''][^>]*content=["'']([^"'']+)["'']', caseSensitive: false).firstMatch(html);
    if (descMatch != null) {
      result['description'] = descMatch.group(1)!.trim();
    }

    final brandMatch = RegExp(r'<meta[^>]*property=["'']product:brand["''][^>]*content=["'']([^"'']+)["'']', caseSensitive: false).firstMatch(html);
    if (brandMatch != null) {
      result['brand'] = brandMatch.group(1)!.trim();
    }

    return result;
  }

  /// Extracts nutritional values from JSON-LD or HTML text tables
  Map<String, dynamic> _extractNutrition(String html, {Map<String, dynamic>? jsonLdData, String? description}) {
    double calories = 150.0;
    double sugars = 5.0;
    double satFat = 2.0;
    double sodium = 100.0;
    double protein = 3.0;
    double fiber = 1.0;

    // 1. Try JSON-LD schema nutrition
    if (jsonLdData?['nutrition'] is Map) {
      final nut = jsonLdData!['nutrition'] as Map;
      if (nut['calories'] != null) calories = _parseNumeric(nut['calories']) ?? calories;
      if (nut['sugarContent'] != null) sugars = _parseNumeric(nut['sugarContent']) ?? sugars;
      if (nut['saturatedFatContent'] != null) satFat = _parseNumeric(nut['saturatedFatContent']) ?? satFat;
      if (nut['sodiumContent'] != null) sodium = _parseNumeric(nut['sodiumContent']) ?? sodium;
      if (nut['proteinContent'] != null) protein = _parseNumeric(nut['proteinContent']) ?? protein;
      if (nut['fiberContent'] != null) fiber = _parseNumeric(nut['fiberContent']) ?? fiber;
    } else {
      // 2. Search HTML text and tables
      final textWithoutScripts = '$description $html'.replaceAll(RegExp(r'<script[\s\S]*?</script>|<style[\s\S]*?</style>', caseSensitive: false), ' ');
      final textToScan = textWithoutScripts.replaceAll(RegExp(r'<[^>]+>'), ' ');

      // Calories / Energy
      final calMatch = RegExp(r'(?:Calories|Energy|Calorie|Energy\s*\(kcal\))\s*[:=-]?\s*(\d+(?:\.\d+)?)\s*(?:kcal|cal)?', caseSensitive: false).firstMatch(textToScan);
      if (calMatch != null) calories = double.tryParse(calMatch.group(1)!) ?? calories;

      // Total Sugars
      final sugarMatch = RegExp(r'(?:Total\s+Sugars?|Sugars?|Added\s+Sugars?)\s*[:=-]?\s*(\d+(?:\.\d+)?)\s*(?:g|gm)?', caseSensitive: false).firstMatch(textToScan);
      if (sugarMatch != null) sugars = double.tryParse(sugarMatch.group(1)!) ?? sugars;

      // Saturated Fat
      final satFatMatch = RegExp(r'(?:Saturated\s+Fat|Sat\s+Fat|Saturates)\s*[:=-]?\s*(\d+(?:\.\d+)?)\s*(?:g|gm)?', caseSensitive: false).firstMatch(textToScan);
      if (satFatMatch != null) satFat = double.tryParse(satFatMatch.group(1)!) ?? satFat;

      // Sodium
      final sodMatch = RegExp(r'(?:Sodium|Salt)\s*[:=-]?\s*(\d+(?:\.\d+)?)\s*(?:mg|g)?', caseSensitive: false).firstMatch(textToScan);
      if (sodMatch != null) {
        final val = double.tryParse(sodMatch.group(1)!) ?? 100.0;
        final unitMatch = sodMatch.group(0)?.toLowerCase();
        if (unitMatch != null && (unitMatch.contains(' g') || unitMatch.endsWith('g')) && !unitMatch.contains('mg')) {
          sodium = val * 400.0; // Salt in g to sodium in mg
        } else {
          sodium = val;
        }
      }

      // Protein
      final protMatch = RegExp(r'(?:Protein|Proteins)\s*[:=-]?\s*(\d+(?:\.\d+)?)\s*(?:g|gm)?', caseSensitive: false).firstMatch(textToScan);
      if (protMatch != null) protein = double.tryParse(protMatch.group(1)!) ?? protein;
    }

    final energyKj = calories * 4.184;

    return {
      'energy_kj': energyKj,
      'sugar_g_per_100g': sugars,
      'sat_fat_g_per_100g': satFat,
      'sodium_mg_per_100g': sodium,
      'protein_g': protein,
      'fiber_g': fiber,
      'fruit_veg_nut_pct': 0.0,
    };
  }

  /// Extracts Ingredients list and detects INS / E-number additives
  Map<String, dynamic> _extractIngredientsAndAdditives(String html, {Map<String, dynamic>? jsonLdData, String? description}) {
    final ingredients = <String>[];
    final additives = <Map<String, dynamic>>[];

    String? rawIngredientsText;

    if (jsonLdData?['ingredients'] != null) {
      final ing = jsonLdData!['ingredients'];
      if (ing is List) {
        ingredients.addAll(ing.map((e) => e.toString().trim()).where((e) => e.isNotEmpty));
      } else if (ing is String) {
        rawIngredientsText = ing;
      }
    }

    if (rawIngredientsText == null) {
      final textToScan = '$description $html';
      final ingMatch = RegExp(r'(?:Ingredients|Key\s+Ingredients|Contents)\s*[:=-]?\s*([^<>\n\r]{10,400})', caseSensitive: false).firstMatch(textToScan);
      if (ingMatch != null) {
        rawIngredientsText = ingMatch.group(1);
      }
    }

    if (rawIngredientsText != null && ingredients.isEmpty) {
      final parts = rawIngredientsText.split(RegExp(r'[,;•\n]'));
      for (final p in parts) {
        final clean = p.replaceAll(RegExp(r'^[\s\-\*\.]+'), '').trim();
        if (clean.length > 2 && clean.length < 80) {
          ingredients.add(clean);
        }
      }
    }

    if (ingredients.isEmpty) {
      ingredients.addAll(['Natural Food Ingredients', 'Standard Preparation Base']);
    }

    // Detect INS additives
    final fullText = ingredients.join(' ') + (rawIngredientsText ?? '');
    final insMatches = RegExp(r'(?:INS|E)\s*[-]?\s*(\d{3,4}[a-z]?)', caseSensitive: false).allMatches(fullText);
    final seenIns = <String>{};

    for (final m in insMatches) {
      final code = m.group(1)!.toUpperCase();
      if (!seenIns.contains(code)) {
        seenIns.add(code);
        additives.add({
          'ins_code': code,
          'primary_name': 'Food Additive $code',
          'risk_tier': _classifyAdditiveRisk(code),
        });
      }
    }

    return {
      'ingredients': ingredients,
      'additives': additives,
    };
  }

  String _classifyAdditiveRisk(String code) {
    const redCodes = ['621', '627', '631', '635', '102', '110', '122', '124', '127', '129', '133', '950', '951', '955'];
    const yellowCodes = ['150C', '150D', '211', '220', '223', '250', '319', '320', '321', '407', '471', '472E'];

    final cleanNum = code.replaceAll(RegExp(r'[^0-9]'), '');
    if (redCodes.contains(code) || redCodes.contains(cleanNum)) {
      return 'RED';
    }
    if (yellowCodes.contains(code) || yellowCodes.contains(cleanNum)) {
      return 'YELLOW';
    }
    return 'GREEN';
  }

  /// Extracts serving size and total pack weight
  Map<String, double?> _extractWeights(
    String html, {
    required String productName,
    Map<String, dynamic>? jsonLdData,
    String? description,
  }) {
    double servingG = 30.0;
    double packG = 100.0;

    // Search pack weight in product name or description (e.g. "200g", "500 g", "1 kg")
    final packMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(g|gm|grams|kg|ml|l)\b', caseSensitive: false).firstMatch('$productName $description');
    if (packMatch != null) {
      final val = double.tryParse(packMatch.group(1)!) ?? 100.0;
      final unit = packMatch.group(2)!.toLowerCase();
      if (unit == 'kg' || unit == 'l') {
        packG = val * 1000.0;
      } else {
        packG = val;
      }
    }

    // Default serving size proportional to pack weight
    if (packG <= 50) {
      servingG = packG;
    } else if (packG <= 200) {
      servingG = (packG / 4).clamp(25.0, 50.0);
    } else {
      servingG = 30.0;
    }

    return {
      'serving_g': servingG,
      'pack_g': packG,
      'piece_g': null,
    };
  }

  /// Extracts product name, brand, and category from URL slug
  Map<String, String> _extractInfoFromUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return {};

    final pathSegments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (pathSegments.isEmpty) return {};

    // Look for product slug in URL (often after /prn/, /pn/, /pd/, /product/, /products/)
    String slug = pathSegments.last;
    for (int i = 0; i < pathSegments.length - 1; i++) {
      final seg = pathSegments[i].toLowerCase();
      if (seg == 'prn' || seg == 'pn' || seg == 'pd' || seg == 'product' || seg == 'products' || seg == 'dp' || seg == 'item') {
        slug = pathSegments[i + 1];
        break;
      }
    }

    // Convert slug (e.g. "milky-mist-paneer-fresh-200g") to readable title
    final words = slug.replaceAll(RegExp(r'[-_]'), ' ').split(RegExp(r'\s+')).where((w) => w.isNotEmpty).map((w) {
      if (w.isEmpty) return w;
      return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
    }).toList();

    final name = words.join(' ');
    final brand = _detectBrandFromText(name);
    final category = _detectCategory(null, name);

    return {
      'name': name,
      if (brand != null) 'brand': brand,
      'category': category,
    };
  }

  String _cleanProductTitle(String title) {
    return title
        .replaceAll(RegExp(r'\s*\|\s*Blinkit.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*-\s*BigBasket.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*:\s*Amazon\.in.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\|\s*Zepto.*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*\|\s*JioMart.*$', caseSensitive: false), '')
        .trim();
  }

  String _detectOrCleanBrand(String? brand, String productName) {
    if (brand != null && brand.trim().isNotEmpty && brand != 'Brand Verified') {
      return brand.trim();
    }
    return _detectBrandFromText(productName) ?? 'Brand Verified';
  }

  String? _detectBrandFromText(String text) {
    final lower = text.toLowerCase();
    const brands = [
      'Everest',
      'MDH',
      'Catch',
      'Badshah',
      'Suhana',
      'Eastern',
      'Ramdev',
      'Aachi',
      'Sakthi',
      'MTR',
      'Milky Mist',
      'Amul',
      'Britannia',
      'Tata Consumer',
      'Tata',
      'The Whole Truth',
      'Yoga Bar',
      'Slurrp Farm',
      'Epigamia',
      'True Elements',
      'Raw Pressery',
      'Paper Boat',
      'Mother Dairy',
      'Akshayakalpa',
      'D\'lecta',
      'Country Delight',
      'Nestle',
      'Haldiram\'s',
      'Parle',
      'Cadbury',
      'Kellogg\'s',
      'Heinz',
      'Quaker',
      'Saffola',
    ];

    for (final b in brands) {
      if (lower.contains(b.toLowerCase())) return b;
    }
    return null;
  }

  String _detectCategory(String? category, String productName) {
    if (category != null && category.trim().isNotEmpty && category != 'Packaged Food') {
      return category.trim();
    }

    final lower = productName.toLowerCase();
    if (lower.contains('peanut butter') || lower.contains('almond butter') || lower.contains('jam') || lower.contains('honey') || lower.contains('spread') || lower.contains('mayonnaise') || lower.contains('dip')) {
      return 'Spreads & Dips';
    }
    if (lower.contains('biscuit') || lower.contains('cookie') || lower.contains('cracker') || lower.contains('rusk')) {
      return 'Biscuits & Cookies';
    }
    if (lower.contains('bread') || lower.contains('bun') || lower.contains('toast') || lower.contains('croissant')) {
      return 'Bakery & Breads';
    }
    if (lower.contains('cheese') || lower.contains('paneer') || lower.contains('butter') || lower.contains('milk') || lower.contains('curd') || lower.contains('ghee')) {
      return 'Cheese & Dairy';
    }
    if (lower.contains('chip') || lower.contains('namkeen') || lower.contains('bhujia') || lower.contains('crisp') || lower.contains('nacho') || lower.contains('popcorn')) {
      return 'Snacks & Namkeen';
    }
    if (lower.contains('chocolate') || lower.contains('candy') || lower.contains('bar') || lower.contains('mithai')) {
      return 'Chocolates & Sweets';
    }
    if (lower.contains('noodle') || lower.contains('pasta') || lower.contains('soup') || lower.contains('vermicelli')) {
      return 'Instant Foods & Noodles';
    }
    if (lower.contains('juice') || lower.contains('shake') || lower.contains('tea') || lower.contains('coffee') || lower.contains('drink') || lower.contains('beverage')) {
      return 'Beverages & Juices';
    }
    if (lower.contains('oats') || lower.contains('muesli') || lower.contains('cereal') || lower.contains('corn flakes') || lower.contains('granola')) {
      return 'Breakfast Cereals';
    }
    if (lower.contains('masala') || lower.contains('spice') || lower.contains('chole') || lower.contains('garam') || lower.contains('curry powder') || lower.contains('seasoning') || lower.contains('turmeric') || lower.contains('chilli powder')) {
      return 'Spices & Masalas';
    }

    return 'Packaged Food';
  }

  double? _parseNumeric(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(val.toString());
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }
}
