import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/backend_endpoint_resolver.dart';
import '../../../core/scoring/dosage_engine.dart';
import '../../../core/vision/barcode_scanner_service.dart';
import '../../../core/vision/food_web_extractor.dart';
import '../../../core/vision/gemini_vision_service.dart';
import '../../../core/vision/on_device_vision_service.dart';
import '../../../services/product_health_scorer.dart';
import '../../profile/domain/user_profile_model.dart';
import 'offline_barcode_repository.dart';

/// Thrown when a scanned QR code belongs to electronics, laptop support, or non-food services
class NonFoodScanException implements Exception {
  final String message;
  final String? domainOrType;

  NonFoodScanException(this.message, {this.domainOrType});

  @override
  String toString() => message;
}

/// Thrown when a barcode is validly formatted but does not exist in any food database
class ProductNotFoundException implements Exception {
  final String barcode;

  ProductNotFoundException(this.barcode);

  @override
  String toString() => 'Product with barcode $barcode not found in food database';
}

/// Thrown when a food web URL could not be retrieved or parsed into verified nutrition facts
class FoodWebExtractionException implements Exception {
  final String url;
  final String message;

  FoodWebExtractionException(this.url, {this.message = 'Could not extract nutrition facts from this web link.'});

  @override
  String toString() => message;
}

/// Thrown when captured photos or nutrition label cannot be read or analyzed
class VisionExtractionException implements Exception {
  final String message;

  VisionExtractionException([this.message = 'Could not detect readable nutrition facts or packaging text in the photo. Please retake with clearer lighting or enter macros manually.']);

  @override
  String toString() => message;
}

/// Thrown when a packaging QR code points to a recipe video or promotional microsite
/// where structured nutrition tables are absent, carrying extracted Brand and Product context
/// so the camera can guide the user or pass the context to Vision OCR.
class PromotionalQrContextException implements Exception {
  final String url;
  final String? brandName;
  final String? productName;
  final String message;
  final bool isRecipeOrPromo;

  PromotionalQrContextException({
    required this.url,
    this.brandName,
    this.productName,
    required this.message,
    this.isRecipeOrPromo = true,
  });

  @override
  String toString() => message;
}

/// Detailed result of a scanned food product resolved against databases and safety engines
class ScannedProductResult {
  final String barcode;
  final String productName;
  final String brandName;
  final String category;
  final double servingSizeG;
  final double sugarGPer100g;
  final double sugarGPerServing;
  final double caloriesPerServing;
  final double satFatGPer100g;
  final double satFatGPerServing;
  final double sodiumMgPer100g;
  final double sodiumMgPerServing;
  final double packWeightG;
  final int? healthScore;
  final String verdictTag; // 'Nutri Safe 🟢', 'Caution 🟠', 'Toxic / Capped 🔴', 'Insufficient Data'
  final int novaGrade;
  final bool redCapTriggered;
  final int safePortionGrams;
  final int? safePieces;
  final String limitingFactor;
  final String frequencySchedule;
  final List<Map<String, dynamic>> additives;
  final List<String> splitSugars;
  final String portionAdvice;
  final bool isExceededBudget;
  final String? analysisSource;
  final String? scoreBreakdown;
  final bool isIngredientOnlyScore;

  const ScannedProductResult({
    required this.barcode,
    required this.productName,
    required this.brandName,
    required this.category,
    required this.servingSizeG,
    required this.sugarGPer100g,
    required this.sugarGPerServing,
    required this.caloriesPerServing,
    this.satFatGPer100g = 0.0,
    this.satFatGPerServing = 0.0,
    this.sodiumMgPer100g = 0.0,
    this.sodiumMgPerServing = 0.0,
    this.packWeightG = 0.0,
    required this.healthScore,
    required this.verdictTag,
    required this.novaGrade,
    required this.redCapTriggered,
    required this.safePortionGrams,
    this.safePieces,
    required this.limitingFactor,
    required this.frequencySchedule,
    required this.additives,
    required this.splitSugars,
    required this.portionAdvice,
    required this.isExceededBudget,
    this.analysisSource,
    this.scoreBreakdown,
    this.isIngredientOnlyScore = false,
  });
}

/// Service that queries Supabase Cloud, Open Food Facts live API, or built-in verified product registries,
/// and computes personalized safe consumption ceilings and toxicology guardrails.
class ProductScannerService {
  final SupabaseClient? _injectedClient;
  final http.Client? _injectedHttpClient;
  final GeminiVisionService? _injectedVisionService;
  final OfflineBarcodeRepository? _injectedOfflineRepo;
  final BackendEndpointResolver? _injectedBackendResolver;
  final OnDeviceVisionService? _injectedOnDeviceVisionService;

  ProductScannerService({
    SupabaseClient? client,
    http.Client? httpClient,
    GeminiVisionService? visionService,
    OfflineBarcodeRepository? offlineBarcodeRepository,
    BackendEndpointResolver? backendResolver,
    OnDeviceVisionService? onDeviceVisionService,
  })  : _injectedClient = client,
        _injectedHttpClient = httpClient,
        _injectedVisionService = visionService,
        _injectedOfflineRepo = offlineBarcodeRepository,
        _injectedBackendResolver = backendResolver,
        _injectedOnDeviceVisionService = onDeviceVisionService;

  SupabaseClient? get _client {
    if (_injectedClient != null) return _injectedClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  http.Client get _httpClient => _injectedHttpClient ?? http.Client();
  OfflineBarcodeRepository get _offlineRepo =>
      _injectedOfflineRepo ?? OfflineBarcodeRepository.instance;
  BackendEndpointResolver get _backendResolver =>
      _injectedBackendResolver ?? BackendEndpointResolver.instance;
  late final OnDeviceVisionService _onDeviceVisionService =
      _injectedOnDeviceVisionService ?? OnDeviceVisionService();
  late final FoodWebExtractor _webExtractor = FoodWebExtractor(httpClient: _httpClient);
  late final GeminiVisionService _visionService =
      _injectedVisionService ?? GeminiVisionService(httpClient: _httpClient);

  /// Resolve product by any scanned QR code payload, GS1 link, food web URL, or barcode string.
  /// Supports optional camera [frameImage] and intermediate [onStatusUpdate] callbacks.
  Future<ScannedProductResult> resolveScanInput({
    required String rawScan,
    required UserProfileModel userProfile,
    List<int>? frameImage,
    void Function(String message)? onStatusUpdate,
  }) async {
    final parsed = parseQrOrBarcode(rawScan);

    // Guardrail 1: Explicit non-food QR codes (e.g. laptop WhatsApp support, electronics, general links)
    if (parsed.isNonFood) {
      throw NonFoodScanException(
        'This QR code is for an electronic device or service (${parsed.nonFoodReason ?? "Non-food link"}), not a packaged food item.',
        domainOrType: parsed.nonFoodReason,
      );
    }

    // Tier 0: Direct embedded JSON payload inside QR code
    if (parsed.type == QrScanType.productJson && parsed.jsonData != null) {
      final barcode = parsed.barcode ?? 'qr_json_${DateTime.now().millisecondsSinceEpoch}';
      return _evaluateProduct(parsed.jsonData!, userProfile, barcode);
    }

    // Tier 0.5: Web URL (food e-commerce, GS1 link, promotional campaign, or YouTube recipe)
    final isUrl = parsed.type == QrScanType.foodWebUrl ||
        rawScan.startsWith('http://') ||
        rawScan.startsWith('https://');

    if (isUrl) {
      return _resolveWebQrPipeline(
        url: rawScan,
        userProfile: userProfile,
        frameImage: frameImage,
        onStatusUpdate: onStatusUpdate,
      );
    }

    if (parsed.type != QrScanType.barcode || parsed.barcode == null) {
      throw NonFoodScanException(
        'This QR code does not contain a recognized packaged food barcode or nutrition profile.',
      );
    }

    return resolveBarcode(barcode: parsed.barcode!, userProfile: userProfile);
  }

  /// 4-Stage resolution pipeline for packaging web QR codes:
  /// Stage 2: URL unrolling & GS1 GTIN extraction
  /// Stage 3: Entity extraction & Open Food Facts search
  /// Stage 4: Context-enriched Gemini Vision handoff
  Future<ScannedProductResult> _resolveWebQrPipeline({
    required String url,
    required UserProfileModel userProfile,
    List<int>? frameImage,
    void Function(String message)? onStatusUpdate,
  }) async {
    onStatusUpdate?.call('Resolving packaging link...');

    // 1. STAGE 2: URL Redirect Unrolling & GS1 India GTIN Extraction
    final gtin = await unrollUrlAndExtractGtin(url);
    if (gtin != null && gtin.isNotEmpty) {
      onStatusUpdate?.call('Matched product barcode $gtin...');
      try {
        return await resolveBarcode(barcode: gtin, userProfile: userProfile);
      } catch (e) {
        debugPrint('[ProductScannerService] Extracted GTIN barcode lookup notice: $e');
      }
    }

    // 2. Direct Web Nutrition Extraction (if the link is an e-commerce page or has nutrition tables)
    try {
      final directResult = await resolveFoodWebUrl(url: url, userProfile: userProfile);
      return directResult;
    } catch (_) {}

    // 3. STAGE 3: Promotional Video & Recipe Microsite Entity Extraction
    onStatusUpdate?.call('Analyzing packaging details...');
    final identity = await extractProductIdentityFromUrl(url);
    final rawTitle = identity?['title'] ?? '';
    final brand = identity?['brand'] ?? '';
    final cleanedQuery = cleanProductQuery(rawTitle.isNotEmpty ? '$brand $rawTitle' : brand);

    if (cleanedQuery.length >= 3) {
      onStatusUpdate?.call('Searching product catalog for $cleanedQuery...');
      final offMatch = await queryOpenFoodFactsIndia(cleanedQuery);
      if (offMatch != null) {
        final barcodeKey = offMatch['barcode']?.toString() ?? url;
        _writeThroughCache(offMatch);
        return _evaluateProduct(offMatch, userProfile, barcodeKey);
      }
    }

    // 4. STAGE 4: Context-Enriched Live Frame Handoff to Gemini Vision
    if (frameImage != null && frameImage.length >= 50) {
      onStatusUpdate?.call('Analyzing package photo with brand context...');
      try {
        final contextHint = cleanedQuery.isNotEmpty
            ? 'Detected QR Brand/Product context: $cleanedQuery.'
            : (brand.isNotEmpty ? 'Detected QR Brand: $brand.' : null);

        final visionData = await _visionService.analyzeProductPhoto(
          frames: [frameImage],
          hintBarcode: contextHint,
        );
        if (visionData != null) {
          final barcodeKey = visionData['barcode']?.toString() ?? 'vision_${DateTime.now().millisecondsSinceEpoch}';
          _writeThroughCache(visionData);
          return _evaluateProduct(visionData, userProfile, barcodeKey);
        }
      } catch (e) {
        debugPrint('[ProductScannerService] Vision handoff notice: $e');
      }
    }

    // If all stages fail to extract complete nutrition:
    throw PromotionalQrContextException(
      url: url,
      brandName: brand.isNotEmpty ? brand : null,
      productName: rawTitle.isNotEmpty ? cleanProductQuery(rawTitle) : null,
      message: 'Detected ${brand.isNotEmpty ? "$brand " : ""}${rawTitle.isNotEmpty ? cleanProductQuery(rawTitle) : "Product"} Recipe QR — Point camera at the back nutrition table to complete analysis.',
    );
  }

  /// Stage 2: Checks raw URL and performs lightweight HTTP GET unrolling to extract GS1 GTIN/EAN barcodes
  Future<String?> unrollUrlAndExtractGtin(String url) async {
    // 1. Direct pattern check in raw URL
    final direct = extractGtinFromUrl(url);
    if (direct != null) return direct;

    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) return null;

    try {
      final uri = Uri.tryParse(trimmed);
      if (uri == null) return null;

      final request = http.Request('GET', uri)
        ..followRedirects = true
        ..maxRedirects = 5
        ..headers['User-Agent'] =
            'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 VeriBiteApp/1.0'
        ..headers['Range'] = 'bytes=0-32768'
        ..headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,application/json;q=0.8,*/*;q=0.7';

      final streamedResponse = await _httpClient.send(request).timeout(const Duration(seconds: 4));
      final response = await http.Response.fromStream(streamedResponse);

      // Check final redirected URL
      final redirectedUrl = response.request?.url.toString() ?? '';
      final redirectGtin = extractGtinFromUrl(redirectedUrl);
      if (redirectGtin != null) return redirectGtin;

      final body = response.body;
      if (body.isNotEmpty) {
        // Check JSON-LD / schema.org GTIN attributes
        final gtinMatch = RegExp(
          r'"(?:gtin13|gtin14|gtin8|gtin|barcode|sku)"\s*:\s*"?(\d{8,14})"?',
          caseSensitive: false,
        ).firstMatch(body);
        if (gtinMatch != null) {
          var code = gtinMatch.group(1)!;
          if (code.length == 14 && code.startsWith('0')) {
            code = code.substring(1);
          }
          final norm = validateAndNormalizeBarcode(code);
          if (norm != null) return norm;
          if (RegExp(r'^\d{8,14}$').hasMatch(code)) return code;
        }

        // Check for Indian GTIN barcode sequence (starts with 890 or 0890)
        final indianMatch = RegExp(r'\b(0?890\d{9,10})\b').firstMatch(body);
        if (indianMatch != null) {
          var code = indianMatch.group(1)!;
          if (code.length == 14 && code.startsWith('0')) {
            code = code.substring(1);
          }
          final norm = validateAndNormalizeBarcode(code);
          if (norm != null) return norm;
        }
      }
    } catch (e) {
      debugPrint('[ProductScannerService] URL redirect unrolling notice: $e');
    }
    return null;
  }

  /// Stage 3: Extracts product title and brand from YouTube oEmbed or webpage metadata
  Future<Map<String, String>?> extractProductIdentityFromUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    // 1. YouTube recipe video links
    if (isYouTubeUrl(trimmed)) {
      try {
        final oembedUri = Uri.parse('https://www.youtube.com/oembed?url=${Uri.encodeComponent(trimmed)}&format=json');
        final response = await _httpClient.get(oembedUri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 3));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map) {
            final author = (data['author_name'] ?? '').toString().trim();
            final title = (data['title'] ?? '').toString().trim();
            return {
              'brand': author,
              'title': title,
            };
          }
        }
      } catch (e) {
        debugPrint('[ProductScannerService] YouTube oEmbed extraction notice: $e');
      }
    }

    // 2. Brand promotional microsite or recipe webpage
    try {
      final uri = Uri.tryParse(trimmed);
      if (uri != null) {
        final response = await _httpClient.get(
          uri,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36 VeriBiteApp/1.0',
            'Range': 'bytes=0-32768',
            'Accept': 'text/html,*/*',
          },
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode >= 200 && response.statusCode < 400) {
          final html = response.body;

          // OpenGraph & Meta title
          String? title;
          final ogTitle = RegExp(r'''<meta[^>]*property=["']og:title["'][^>]*content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
          if (ogTitle != null) title = ogTitle.group(1);

          if (title == null || title.isEmpty) {
            final twTitle = RegExp(r'''<meta[^>]*name=["']twitter:title["'][^>]*content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
            if (twTitle != null) title = twTitle.group(1);
          }

          if (title == null || title.isEmpty) {
            final tagTitle = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false).firstMatch(html);
            if (tagTitle != null) title = tagTitle.group(1);
          }

          // Brand detection from og:site_name or domain
          String? brand;
          final ogSite = RegExp(r'''<meta[^>]*property=["']og:site_name["'][^>]*content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
          if (ogSite != null) brand = ogSite.group(1);

          if (brand == null || brand.isEmpty) {
            final host = uri.host.toLowerCase();
            if (host.contains('everest')) {
              brand = 'Everest';
            } else if (host.contains('catch')) {
              brand = 'Catch';
            } else if (host.contains('mdh')) {
              brand = 'MDH';
            } else if (host.contains('badshah')) {
              brand = 'Badshah';
            } else if (host.contains('suhana')) {
              brand = 'Suhana';
            } else if (host.contains('amul')) {
              brand = 'Amul';
            } else if (host.contains('mtr')) {
              brand = 'MTR';
            } else if (host.contains('haldiram')) {
              brand = 'Haldiram\'s';
            } else if (host.contains('britannia')) {
              brand = 'Britannia';
            } else if (host.contains('parle')) {
              brand = 'Parle';
            } else if (host.contains('nestle')) {
              brand = 'Nestle';
            }
          }

          if (title != null && title.isNotEmpty) {
            return {
              'brand': brand ?? 'Brand Verified',
              'title': title.trim(),
            };
          }
        }
      }
    } catch (e) {
      debugPrint('[ProductScannerService] Webpage entity extraction notice: $e');
    }

    // 3. Fallback: Parse URL slug
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final segments = uri.pathSegments
          .where((s) => s.isNotEmpty && s != 'p' && s != 'product' && s != 'recipe' && s != 'recipes')
          .toList();
      if (segments.isNotEmpty) {
        final slug = segments.last.replaceAll(RegExp(r'[-_]'), ' ').trim();
        return {
          'brand': uri.host.split('.').length > 2 ? uri.host.split('.')[1] : uri.host.split('.').first,
          'title': slug,
        };
      }
    }

    return null;
  }

  /// Sanitizes product titles by stripping promotional and recipe filler words
  static String cleanProductQuery(String rawTitle) {
    if (rawTitle.trim().isEmpty) return '';

    // Remove HTML entities
    var clean = rawTitle
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');

    // Remove promotional & recipe filler words case-insensitively
    const fillerWords = [
      'how to make', 'step by step', 'official recipe', 'recipe video',
      'recipe', 'recipes', 'official', 'video', 'promo', 'promotional',
      'campaign', 'contest', 'win', 'scan', 'qr code', 'qr', 'welcome to',
      'welcome', 'youtube', 'in hindi', 'in english', 'in tamil', 'in telugu',
      'tasty', 'easy', 'authentic', 'delicious', 'special', 'quick',
      'homemade', 'hotel style', 'restaurant style', 'dhaba style',
      'best', 'ever', 'new', 'watch now', 'subscribe'
    ];

    for (final filler in fillerWords) {
      clean = clean.replaceAll(RegExp(r'\b' + RegExp.escape(filler) + r'\b', caseSensitive: false), ' ');
    }

    // Remove separator pipes, hyphens, brackets, special punctuation
    clean = clean.replaceAll(RegExp(r'[|•\-_—\[\]\(\)\{\}\*!#?]'), ' ');
    // Collapse whitespace
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();

    return clean;
  }

  /// Queries Open Food Facts India Search API for a matching food product
  Future<Map<String, dynamic>?> queryOpenFoodFactsIndia(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return null;

    try {
      final searchUrl = Uri.parse(
        'https://in.openfoodfacts.org/cgi/search.pl?search_terms=${Uri.encodeComponent(trimmed)}&search_simple=1&action=process&json=1&page_size=5&fields=code,product_name,brands,categories,serving_quantity,product_quantity,nutriments,additives_tags,ingredients_text,nova_group',
      );

      final response = await _httpClient.get(
        searchUrl,
        headers: {
          'User-Agent': 'VeriBiteApp/1.0 (contact@veribite.app)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['products'] is List && (data['products'] as List).isNotEmpty) {
          final products = data['products'] as List;

          for (final item in products) {
            if (item is Map<String, dynamic>) {
              final nutriments = (item['nutriments'] as Map<String, dynamic>?) ?? {};
              final hasNutrition = nutriments.containsKey('energy-kcal_100g') ||
                  nutriments.containsKey('energy-kj_100g') ||
                  nutriments.containsKey('sugars_100g');
              final hasIngredients = (item['ingredients_text']?.toString().trim().isNotEmpty ?? false);

              if (hasNutrition || hasIngredients) {
                return _mapOffProductToVeribiteFormat(item, fallbackQuery: trimmed);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ProductScannerService] Open Food Facts India query notice: $e');
    }
    return null;
  }

  Map<String, dynamic> _mapOffProductToVeribiteFormat(
    Map<String, dynamic> p, {
    required String fallbackQuery,
  }) {
    final barcode = p['code']?.toString() ?? 'search_${DateTime.now().millisecondsSinceEpoch}';
    final name = p['product_name']?.toString().trim().isNotEmpty == true
        ? p['product_name'].toString().trim()
        : fallbackQuery;
    final brand = p['brands']?.toString().trim().isNotEmpty == true
        ? p['brands'].toString().trim()
        : 'Brand Verified';
    final category = p['categories']?.toString().split(',').first.trim().isNotEmpty == true
        ? p['categories'].toString().split(',').first.trim()
        : 'Packaged Food';

    final nutriments = (p['nutriments'] as Map<String, dynamic>?) ?? {};
    final sugars = (nutriments['sugars_100g'] as num?)?.toDouble() ?? 0.0;
    final satFat = (nutriments['saturated-fat_100g'] as num?)?.toDouble() ?? 0.0;

    double sodium = 0.0;
    if (nutriments['sodium_100g'] != null) {
      sodium = (nutriments['sodium_100g'] as num).toDouble() * 1000.0;
    } else if (nutriments['salt_100g'] != null) {
      sodium = (nutriments['salt_100g'] as num).toDouble() * 400.0;
    }

    final energyKj = (nutriments['energy-kj_100g'] as num?)?.toDouble() ??
        ((nutriments['energy-kcal_100g'] as num?)?.toDouble() ?? 100.0) * 4.184;

    final servingG = (p['serving_quantity'] as num?)?.toDouble() ?? 30.0;
    final packG = (p['product_quantity'] as num?)?.toDouble() ?? (servingG * 3.0);

    // Extract additives
    final additivesList = <Map<String, dynamic>>[];
    final tags = (p['additives_tags'] as List?) ?? [];
    for (final tag in tags) {
      final cleanTag = tag.toString().replaceAll(RegExp(r'^en:'), '').toUpperCase();
      final insNumber = cleanTag.replaceAll(RegExp(r'[^0-9]'), '');
      additivesList.add({
        'ins_code': insNumber.isNotEmpty ? insNumber : cleanTag,
        'primary_name': cleanTag,
        'risk_tier': 'GREEN',
      });
    }

    // Extract ingredients
    final ingredientsRaw = p['ingredients_text']?.toString() ?? '';
    final ingredientsList = ingredientsRaw.isNotEmpty
        ? ingredientsRaw.split(RegExp(r'[,;]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        : ['Natural Spices & Food Ingredients'];

    return {
      'barcode': barcode,
      'product_name': name,
      'brand_name': brand,
      'category': category,
      'serving_size_g': servingG,
      'pack_weight_g': packG,
      'piece_weight_g': null,
      'nova_grade': (p['nova_group'] as num?)?.toInt() ?? 3,
      'red_cap_triggered': 0,
      'nutrition_json': jsonEncode({
        'energy_kj': energyKj,
        'sugar_g_per_100g': sugars,
        'sat_fat_g_per_100g': satFat,
        'sodium_mg_per_100g': sodium,
        'protein_g': (nutriments['proteins_100g'] as num?)?.toDouble() ?? 2.0,
        'fiber_g': (nutriments['fiber_100g'] as num?)?.toDouble() ?? 1.0,
        'fruit_veg_nut_pct': 0.0,
      }),
      'additives_json': jsonEncode(additivesList),
      'ingredients_json': jsonEncode(ingredientsList),
    };
  }

  /// Resolves a product directly from a food e-commerce or brand product web page
  Future<ScannedProductResult> resolveFoodWebUrl({
    required String url,
    required UserProfileModel userProfile,
  }) async {
    Map<String, dynamic>? productData;

    // 1. Try Supabase Cloud lookup (write-through cache hit)
    try {
      final client = _client;
      if (client != null) {
        final res = await client
            .from('products')
            .select('*')
            .eq('barcode', url)
            .maybeSingle();
        if (res != null) {
          productData = res;
        }
      }
    } catch (e) {
      debugPrint('ProductScannerService: Supabase query notice for web URL: $e');
    }

    // 2. Extract structured nutrition data from web page
    if (productData == null) {
      productData = await _webExtractor.extractProductFromUrl(url);
      if (productData != null) {
        _writeThroughCache(productData);
      }
    }

    if (productData == null) {
      throw FoodWebExtractionException(url);
    }

    return _evaluateProduct(productData, userProfile, url);
  }

  void _writeThroughCache(Map<String, dynamic> productData) {
    final barcode = productData['barcode']?.toString();
    if (barcode != null && barcode.isNotEmpty) {
      unawaited(_offlineRepo.saveProduct(barcode: barcode, productData: productData));
    }
    try {
      final client = _client;
      if (client != null) {
        client.from('products').upsert(productData).ignore();
      }
    } catch (_) {}
  }

  /// Resolves product using 1-4 multi-angle camera frames (for curved bottles, complex packaging, or nutrition labels).
  /// Submits to Google Gemini Multimodal Vision AI, dynamic backend proxy, or local On-Device OCR.
  Future<ScannedProductResult> resolveMultiAngleScan({
    required List<List<int>> frames,
    required UserProfileModel userProfile,
    String? detectedBarcode,
  }) async {
    Map<String, dynamic>? productData;
    String? resolvedSource;

    // 1. If a barcode was also detected in the view, resolve via barcode
    if (detectedBarcode != null && detectedBarcode.isNotEmpty) {
      try {
        return await resolveBarcode(barcode: detectedBarcode, userProfile: userProfile);
      } catch (_) {}
    }

    // 2. Direct Gemini Multimodal Vision AI analysis (with Stage 1 cascade & key rotation)
    try {
      productData = await _visionService.analyzeProductPhoto(
        frames: frames,
        hintBarcode: detectedBarcode,
      );
      if (productData != null) {
        resolvedSource = 'gemini_vision';
      }
    } catch (e) {
      debugPrint('[ProductScannerService] Direct Gemini vision analysis notice: $e');
    }

    // 3. Try Backend Cloud Vision proxy /api/v1/scan/vision via Dynamic Endpoint Resolver
    if (productData == null && frames.isNotEmpty) {
      try {
        final backendBaseUrl = await _backendResolver.resolveActiveBackendUrl();
        if (backendBaseUrl != null && backendBaseUrl.isNotEmpty) {
          final uri = Uri.parse('$backendBaseUrl/api/v1/scan/vision');
          final request = http.MultipartRequest('POST', uri);
          for (int i = 0; i < frames.length; i++) {
            request.files.add(
              http.MultipartFile.fromBytes('images', frames[i], filename: 'frame_$i.jpg'),
            );
          }
          final streamedResponse = await _httpClient.send(request).timeout(const Duration(seconds: 4));
          if (streamedResponse.statusCode == 200) {
            final respStr = await streamedResponse.stream.bytesToString();
            final decoded = jsonDecode(respStr);
            if (decoded is Map<String, dynamic>) {
              productData = decoded;
              resolvedSource = 'backend_proxy';
            }
          }
        }
      } catch (e) {
        debugPrint('[ProductScannerService] Cloud vision proxy notice: $e');
      }
    }

    // 4. Guaranteed On-Device ML Kit OCR + Local Nutrition/Additive Regex Fallback
    if (productData == null && frames.isNotEmpty) {
      try {
        productData = await _onDeviceVisionService.analyzeFrames(frames);
        if (productData != null) {
          resolvedSource = 'on_device_vision';
          debugPrint('[ProductScannerService] Successfully resolved product via On-Device Vision Engine!');
        }
      } catch (e) {
        debugPrint('[ProductScannerService] On-device vision fallback notice: $e');
      }
    }

    // 5. If neither Gemini Vision, backend proxy, nor on-device OCR could identify the product from photos:
    // Do NOT substitute fake food facts! Throw VisionExtractionException
    if (productData == null) {
      throw VisionExtractionException(
        'Could not detect readable nutrition facts or packaging details. Please retake the photo with clearer lighting or enter macros via the quick sliders.',
      );
    }

    // Cache the resolved product in offline repository & Supabase catalog
    final barcodeKey = productData['barcode']?.toString() ?? 'vision_${DateTime.now().millisecondsSinceEpoch}';
    productData['barcode'] = barcodeKey;
    _writeThroughCache(productData);

    return _evaluateProduct(productData, userProfile, barcodeKey, analysisSource: resolvedSource);
  }

  /// Resolve product by barcode string and evaluate against user biometrics
  Future<ScannedProductResult> resolveBarcode({
    required String barcode,
    required UserProfileModel userProfile,
  }) async {
    Map<String, dynamic>? productData;

    // 1. Check built-in verified catalog fallback (Instant 0ms resolution)
    productData = _getCatalogProduct(barcode);

    // 2. Check Offline Barcode Repository (Tier 2 local persistent cache, then Tier 1 pre-bundled seed - < 1ms)
    if (productData == null) {
      try {
        productData = await _offlineRepo.lookupBarcode(barcode);
      } catch (e) {
        debugPrint('[ProductScannerService] Offline repository lookup notice: $e');
      }
    }

    // 3. Try Supabase Cloud lookup
    if (productData == null) {
      try {
        final client = _client;
        if (client != null) {
          final res = await client
              .from('products')
              .select('*')
              .eq('barcode', barcode)
              .maybeSingle();
          if (res != null) {
            productData = res;
            _writeThroughCache(res);
          }
        }
      } catch (e) {
        debugPrint('ProductScannerService: Supabase query failed: $e');
      }
    }

    // 4. Try Open Food Facts Live Global API (v2) for uncatalogued products
    if (productData == null) {
      try {
        final offData = await _fetchFromOpenFoodFacts(barcode);
        if (offData != null) {
          productData = offData;
          _writeThroughCache(offData);
        }
      } catch (e) {
        debugPrint('ProductScannerService: Open Food Facts query notice: $e');
      }
    }

    // 5. If barcode is still not found, check GS1 India 890 manufacturer prefix & pack-size siblings!
    if (productData == null) {
      try {
        final siblings = await _offlineRepo.findSiblingProducts(barcode);
        if (siblings.isNotEmpty) {
          final brandName = _offlineRepo.getBrandOrManufacturerForBarcode(barcode) ??
              (siblings.first['brand_name']?.toString() ?? 'Packaged Brand');
          throw OfflineVariantMatchException(
            barcode: barcode,
            brandName: brandName,
            siblingProducts: siblings,
          );
        }
      } catch (e) {
        if (e is OfflineVariantMatchException) rethrow;
        debugPrint('[ProductScannerService] Sibling matcher notice: $e');
      }

      throw ProductNotFoundException(barcode);
    }

    return _evaluateProduct(productData, userProfile, barcode);
  }

  /// Live query to Open Food Facts v2 API
  Future<Map<String, dynamic>?> _fetchFromOpenFoodFacts(String barcode) async {
    final url = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode');
    try {
      final response = await _httpClient.get(
        url,
        headers: {
          'User-Agent': 'VeriBiteApp/1.0 (contact@veribite.app)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['status'] == 1 && data['product'] is Map) {
          final p = data['product'] as Map<String, dynamic>;
          final nutriments = (p['nutriments'] as Map<String, dynamic>?) ?? {};

          // Extract additives
          final additivesList = <Map<String, dynamic>>[];
          final tags = (p['additives_tags'] as List?) ?? (p['additives_original_tags'] as List?) ?? [];
          for (final tag in tags) {
            final cleanTag = tag.toString().replaceAll(RegExp(r'^en:'), '').toUpperCase();
            final insNumber = cleanTag.replaceAll(RegExp(r'[^0-9]'), '');
            additivesList.add({
              'ins_code': insNumber.isNotEmpty ? insNumber : cleanTag,
              'primary_name': cleanTag,
              'risk_tier': 'GREEN',
            });
          }

          // Impute nutrition values
          final sugars = (nutriments['sugars_100g'] as num?)?.toDouble() ?? 0.0;
          final satFat = (nutriments['saturated-fat_100g'] as num?)?.toDouble() ?? 0.0;
          double sodium = 0.0;
          if (nutriments['sodium_100g'] != null) {
            sodium = (nutriments['sodium_100g'] as num).toDouble() * 1000.0;
          } else if (nutriments['salt_100g'] != null) {
            sodium = (nutriments['salt_100g'] as num).toDouble() * 400.0;
          }
          final energyKj = (nutriments['energy-kj_100g'] as num?)?.toDouble() ??
              ((nutriments['energy-kcal_100g'] as num?)?.toDouble() ?? 100.0) * 4.184;

          final servingG = (p['serving_quantity'] as num?)?.toDouble() ?? 30.0;
          final packG = (p['product_quantity'] as num?)?.toDouble() ?? (servingG * 3.0);

          return {
            'barcode': barcode,
            'product_name': p['product_name'] ?? p['product_name_en'] ?? 'Packaged Food Item',
            'brand_name': p['brands'] ?? 'Brand Verified',
            'category': p['categories'] ?? 'Packaged Food',
            'serving_size_g': servingG,
            'pack_weight_g': packG,
            'piece_weight_g': null,
            'nova_grade': (p['nova_group'] as num?)?.toInt() ?? 3,
            'red_cap_triggered': 0,
            'nutrition_json': jsonEncode({
              'energy_kj': energyKj,
              'sugar_g_per_100g': sugars,
              'sat_fat_g_per_100g': satFat,
              'sodium_mg_per_100g': sodium,
              'fiber_g': (nutriments['fiber_100g'] as num?)?.toDouble() ?? 1.5,
              'protein_g': (nutriments['proteins_100g'] as num?)?.toDouble() ?? 3.0,
              'fruit_veg_nut_pct': 0.0,
            }),
            'additives_json': jsonEncode(additivesList),
            'ingredients_json': jsonEncode(
              (p['ingredients_text'] ?? 'Wheat flour, Sugar, Vegetable fat')
                  .toString()
                  .split(RegExp(r'[,;]'))
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(),
            ),
          };
        }
      }
    } catch (_) {}
    return null;
  }

  /// Resolve manual nutrition input (from Quick Macro Sliders)
  ScannedProductResult resolveManualNutrition({
    required Map<String, double> macros,
    required UserProfileModel userProfile,
  }) {
    final sugar = macros['sugar'] ?? 10.0;
    final satFat = macros['sat_fat'] ?? 5.0;
    final sodium = macros['sodium'] ?? 200.0;

    final mockData = {
      'barcode': 'manual_${DateTime.now().millisecondsSinceEpoch}',
      'product_name': 'Manual Custom Food',
      'brand_name': 'Custom Entry',
      'category': 'Custom Snack',
      'serving_size_g': 30.0,
      'nutrition_json': jsonEncode({
        'energy_kj': 450.0,
        'sugar_g_per_100g': sugar,
        'sat_fat_g_per_100g': satFat,
        'sodium_mg_per_100g': sodium,
        'fiber_g': 1.5,
        'protein_g': 2.0,
        'fruit_veg_nut_pct': 0.0,
      }),
      'additives_json': jsonEncode([]),
      'ingredients_json': jsonEncode(['Wheat Flour', 'Sugar', 'Vegetable Oil']),
    };

    return _evaluateProduct(mockData, userProfile, mockData['barcode'] as String);
  }

  /// Directly evaluate a raw or cached product map against user biometrics
  ScannedProductResult evaluateProductData({
    required Map<String, dynamic> productData,
    required UserProfileModel userProfile,
    String? barcode,
  }) {
    final code = barcode ??
        productData['barcode']?.toString() ??
        'product_${DateTime.now().millisecondsSinceEpoch}';
    return _evaluateProduct(productData, userProfile, code);
  }

  /// Internal deterministic evaluation of product with scoring & dosage engines
  ScannedProductResult _evaluateProduct(
    Map<String, dynamic> raw,
    UserProfileModel profile,
    String barcode, {
    String? analysisSource,
  }) {
    final productName = raw['product_name']?.toString() ?? 'Packaged Food';
    final brandName = raw['brand_name']?.toString() ?? 'Brand Verified';
    final category = raw['category']?.toString() ?? 'Packaged Food';
    final servingSize = (raw['serving_size_g'] as num?)?.toDouble() ?? 30.0;
    final unitPieceWeight = (raw['piece_weight_g'] as num?)?.toDouble();

    // Parse nutrition JSON or direct nutrition map
    Map<String, dynamic> nutritionMap = {};
    if (raw['nutrition'] is Map) {
      nutritionMap = Map<String, dynamic>.from(raw['nutrition'] as Map);
    } else if (raw['nutrition_json'] is String) {
      try {
        nutritionMap = jsonDecode(raw['nutrition_json'] as String);
      } catch (_) {}
    } else if (raw['nutrition_json'] is Map) {
      nutritionMap = Map<String, dynamic>.from(raw['nutrition_json'] as Map);
    }

    final sugarPer100 = (nutritionMap['sugar_g_per_100g'] ?? nutritionMap['total_sugars_g'] ?? 0.0 as num).toDouble();
    final sugarPerServing = double.parse((sugarPer100 * (servingSize / 100.0)).toStringAsFixed(1));
    final energyKj = (nutritionMap['energy_kj'] as num?)?.toDouble() ?? 500.0;
    final caloriesPerServing = double.parse(((energyKj / 4.184) * (servingSize / 100.0)).toStringAsFixed(0));

    // Parse real saturated fat & sodium per 100g and calculate per-serving values
    final satFatPer100 = (nutritionMap['sat_fat_g_per_100g'] ?? nutritionMap['sat_fat_g'] ?? 0.0 as num).toDouble();
    final satFatPerServing = double.parse((satFatPer100 * (servingSize / 100.0)).toStringAsFixed(1));

    double sodiumPer100 = 0.0;
    if (nutritionMap['sodium_mg_per_100g'] != null) {
      sodiumPer100 = (nutritionMap['sodium_mg_per_100g'] as num).toDouble();
    } else if (nutritionMap['sodium_mg'] != null) {
      sodiumPer100 = (nutritionMap['sodium_mg'] as num).toDouble();
    } else if (nutritionMap['salt_g_per_100g'] != null) {
      sodiumPer100 = (nutritionMap['salt_g_per_100g'] as num).toDouble() * 400.0;
    } else if (nutritionMap['salt_g'] != null) {
      sodiumPer100 = (nutritionMap['salt_g'] as num).toDouble() * 400.0;
    }
    final sodiumPerServing = (sodiumPer100 * (servingSize / 100.0)).roundToDouble();

    // Parse package net weight for dynamic whole pack calculations
    final packWeight = (raw['pack_weight_g'] as num?)?.toDouble() ??
        (raw['net_weight_g'] as num?)?.toDouble() ??
        (servingSize * 3.0);

    // Parse additives
    List<Map<String, dynamic>> additivesList = [];
    if (raw['additives'] is List) {
      additivesList = (raw['additives'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } else if (raw['additives_json'] is String) {
      try {
        final decoded = jsonDecode(raw['additives_json'] as String);
        if (decoded is List) {
          additivesList = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        }
      } catch (_) {}
    } else if (raw['additives_json'] is List) {
      additivesList = (raw['additives_json'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    // Parse ingredients to detect split sugars & whole food markers
    List<String> ingredientsList = [];
    if (raw['ingredients'] is List) {
      ingredientsList = (raw['ingredients'] as List).map((e) => e.toString()).toList();
    } else if (raw['ingredients_json'] is String) {
      try {
        final decoded = jsonDecode(raw['ingredients_json'] as String);
        if (decoded is List) {
          ingredientsList = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    } else if (raw['ingredients_json'] is List) {
      ingredientsList = (raw['ingredients_json'] as List).map((e) => e.toString()).toList();
    }

    // Check for split sugars
    const knownSugarTerms = [
      'sugar',
      'invert sugar',
      'glucose syrup',
      'fructose',
      'maltodextrin',
      'corn syrup',
      'dextrose',
      'malt extract',
      'honey',
      'caramel',
      'sucrose'
    ];
    final splitSugarsFound = <String>[];
    for (final ing in ingredientsList) {
      final lower = ing.toLowerCase();
      for (final st in knownSugarTerms) {
        if (lower.contains(st) && !splitSugarsFound.contains(st)) {
          splitSugarsFound.add(st);
        }
      }
    }

    // Dosage & Consumption Engine
    final dosageResult = calculatePrescribedDosage(
      nutrition: {
        'sugar_g_per_100g': sugarPer100,
        'sat_fat_g_per_100g': satFatPer100,
        'sodium_mg_per_100g': sodiumPer100,
      },
      additives: additivesList,
      userWeightKg: profile.weightKg,
      isChild: profile.isChild,
      unitPieceWeightG: unitPieceWeight,
    );

    final safePortionGrams = (dosageResult['safe_portion_grams'] as num?)?.toInt() ?? 30;
    final limitingFactor = dosageResult['limiting_factor']?.toString() ?? 'Sugar';
    final frequencySchedule = dosageResult['frequency_schedule']?.toString() ?? 'Max 2-3x per week';
    int? safePieces = (dosageResult['safe_pieces'] as num?)?.toInt();
    if (safePieces != null && safePieces < 1) safePieces = 1;

    // Dynamic Scientific Health Score & Verdict via ProductHealthScorer
    final scoreResult = ProductHealthScorer.calculate(
      nutrition: nutritionMap.isNotEmpty ? nutritionMap : {
        'sugar_g_per_100g': sugarPer100,
        'sat_fat_g_per_100g': satFatPer100,
        'sodium_mg_per_100g': sodiumPer100,
        'calories': servingSize > 0 ? (caloriesPerServing * (100.0 / servingSize)) : caloriesPerServing,
      },
      additives: additivesList,
      ingredients: ingredientsList,
      novaGrade: (raw['nova_grade'] as num?)?.toInt(),
      redCapTriggered: raw['red_cap_triggered'] == 1 || raw['red_cap_triggered'] == true,
    );

    int? finalScore;
    String verdictTag;
    final String scoreBreakdown = scoreResult.scoreBreakdownSummary;
    final bool isIngredientOnly = scoreResult.isIngredientOnlyScore;

    // Honor explicit verified scores (e.g. curated offline catalog) only if NOT the fake 65 fallback
    final explicitScore = (raw['health_score'] as num?)?.toInt();
    if (explicitScore != null && explicitScore != 65) {
      finalScore = explicitScore;
      if (scoreResult.isRedCapped && finalScore > 39) {
        finalScore = 39;
      }
      if (finalScore >= 70 && !scoreResult.isRedCapped) {
        verdictTag = 'Nutri Safe 🟢';
      } else if (finalScore >= 40 && !scoreResult.isRedCapped) {
        verdictTag = 'Caution 🟠';
      } else {
        verdictTag = 'Toxic / Capped 🔴';
      }
    } else {
      finalScore = scoreResult.score;
      verdictTag = scoreResult.verdictTag;
    }

    final isRedCap = scoreResult.isRedCapped;

    // Advice text
    final portionAdvice = safePieces != null && safePieces > 0
        ? 'Safe consumption portion: $safePortionGrams g (~$safePieces pieces). Limiting constraint: $limitingFactor.'
        : 'Safe consumption portion: $safePortionGrams g (max ${(safePortionGrams / servingSize).toStringAsFixed(1)} serving). Limiting constraint: $limitingFactor.';

    // Budget check (WHO 25g adult limit, 10g diabetic cap)
    final maxSugar = profile.isDiabetic ? 10.0 : (profile.isChild ? 15.0 : 25.0);
    final isExceededBudget = sugarPerServing > maxSugar;

    return ScannedProductResult(
      barcode: barcode,
      productName: productName,
      brandName: brandName,
      category: category,
      servingSizeG: servingSize,
      sugarGPer100g: sugarPer100,
      sugarGPerServing: sugarPerServing,
      caloriesPerServing: caloriesPerServing,
      satFatGPer100g: satFatPer100,
      satFatGPerServing: satFatPerServing,
      sodiumMgPer100g: sodiumPer100,
      sodiumMgPerServing: sodiumPerServing,
      packWeightG: packWeight,
      healthScore: finalScore,
      verdictTag: verdictTag,
      novaGrade: (raw['nova_grade'] as num?)?.toInt() ?? 3,
      redCapTriggered: isRedCap,
      safePortionGrams: safePortionGrams,
      safePieces: safePieces,
      limitingFactor: limitingFactor,
      frequencySchedule: frequencySchedule,
      additives: additivesList,
      splitSugars: splitSugarsFound,
      portionAdvice: portionAdvice,
      isExceededBudget: isExceededBudget,
      analysisSource: analysisSource ?? raw['source']?.toString(),
      scoreBreakdown: scoreBreakdown,
      isIngredientOnlyScore: isIngredientOnly,
    );
  }

  /// Built-in rich offline catalog for instant demo scans & offline fallback
  Map<String, dynamic>? _getCatalogProduct(String barcode) {
    final catalog = {
      // 1. Britannia Good Day Butter Cookies
      '8901063012117': {
        'barcode': '8901063012117',
        'product_name': 'Good Day Butter Cookies',
        'brand_name': 'Britannia',
        'category': 'Biscuits & Cookies',
        'serving_size_g': 25.0,
        'pack_weight_g': 75.0,
        'piece_weight_g': 7.5,
        'health_score': 48,
        'nova_grade': 4,
        'red_cap_triggered': 0,
        'nutrition_json': jsonEncode({
          'energy_kj': 2100.0,
          'sugar_g_per_100g': 24.5,
          'sat_fat_g_per_100g': 11.2,
          'sodium_mg_per_100g': 280.0,
          'fiber_g': 1.8,
          'protein_g': 6.5,
          'fruit_veg_nut_pct': 0.0,
        }),
        'additives_json': jsonEncode([
          {'ins_code': '500(ii)', 'primary_name': 'Sodium Bicarbonate', 'risk_tier': 'GREEN'},
          {'ins_code': '503(ii)', 'primary_name': 'Ammonium Bicarbonate', 'risk_tier': 'GREEN'},
          {'ins_code': '322', 'primary_name': 'Lecithin (Soy)', 'risk_tier': 'GREEN'},
        ]),
        'ingredients_json': jsonEncode(['Refined Wheat Flour (Maida)', 'Sugar', 'Butter (2%)', 'Invert Sugar Syrup', 'Edible Vegetable Oil']),
      },
      // 2. Maggi 2-Minute Masala Noodles
      '8901058852339': {
        'barcode': '8901058852339',
        'product_name': '2-Minute Masala Noodles',
        'brand_name': 'Maggi',
        'category': 'Instant Noodles',
        'serving_size_g': 70.0,
        'pack_weight_g': 70.0,
        'piece_weight_g': null,
        'health_score': 32,
        'nova_grade': 4,
        'red_cap_triggered': 1,
        'nutrition_json': jsonEncode({
          'energy_kj': 1750.0,
          'sugar_g_per_100g': 3.2,
          'sat_fat_g_per_100g': 6.8,
          'sodium_mg_per_100g': 860.0,
          'fiber_g': 3.5,
          'protein_g': 8.0,
          'fruit_veg_nut_pct': 5.0,
        }),
        'additives_json': jsonEncode([
          {'ins_code': '635', 'primary_name': 'Disodium 5-Ribonucleotides', 'risk_tier': 'RED', 'triggers_red_cap': 1},
          {'ins_code': '451(i)', 'primary_name': 'Pentasodium Triphosphate', 'risk_tier': 'CAUTION'},
        ]),
        'ingredients_json': jsonEncode(['Wheat Flour (Maida)', 'Palm Oil', 'Iodized Salt', 'Hydrolyzed Groundnut Protein', 'Spices']),
      },
      // 3. Quaker Rolled Oats
      '8901491101837': {
        'barcode': '8901491101837',
        'product_name': '100% Whole Grain Rolled Oats',
        'brand_name': 'Quaker',
        'category': 'Breakfast Cereals',
        'serving_size_g': 40.0,
        'pack_weight_g': 400.0,
        'piece_weight_g': null,
        'health_score': 88,
        'nova_grade': 1,
        'red_cap_triggered': 0,
        'nutrition_json': jsonEncode({
          'energy_kj': 1600.0,
          'sugar_g_per_100g': 1.1,
          'sat_fat_g_per_100g': 1.5,
          'sodium_mg_per_100g': 10.0,
          'fiber_g': 10.5,
          'protein_g': 12.0,
          'fruit_veg_nut_pct': 100.0,
        }),
        'additives_json': jsonEncode([]),
        'ingredients_json': jsonEncode(['100% Whole Grain Rolled Oats']),
      },
      // 4. Lay's Classic Salted Potato Chips
      '8901491101844': {
        'barcode': '8901491101844',
        'product_name': 'Classic Salted Potato Chips',
        'brand_name': 'Lay\'s',
        'category': 'Chips & Crisps',
        'serving_size_g': 30.0,
        'pack_weight_g': 50.0,
        'piece_weight_g': null,
        'health_score': 54,
        'nova_grade': 3,
        'red_cap_triggered': 0,
        'nutrition_json': jsonEncode({
          'energy_kj': 2250.0,
          'sugar_g_per_100g': 1.5,
          'sat_fat_g_per_100g': 12.5,
          'sodium_mg_per_100g': 550.0,
          'fiber_g': 3.2,
          'protein_g': 6.8,
          'fruit_veg_nut_pct': 0.0,
        }),
        'additives_json': jsonEncode([]),
        'ingredients_json': jsonEncode(['Potato', 'Edible Vegetable Oil (Palmolein)', 'Iodized Salt']),
      },
      // 5. Nutella Hazelnut Cocoa Spread
      '3017620422003': {
        'barcode': '3017620422003',
        'product_name': 'Hazelnut Spread with Cocoa',
        'brand_name': 'Nutella',
        'category': 'Spreads',
        'serving_size_g': 15.0,
        'pack_weight_g': 350.0,
        'piece_weight_g': null,
        'health_score': 38,
        'nova_grade': 4,
        'red_cap_triggered': 1,
        'nutrition_json': jsonEncode({
          'energy_kj': 2252.0,
          'sugar_g_per_100g': 56.3,
          'sat_fat_g_per_100g': 10.6,
          'sodium_mg_per_100g': 42.0,
          'fiber_g': 3.0,
          'protein_g': 6.3,
          'fruit_veg_nut_pct': 13.0,
        }),
        'additives_json': jsonEncode([
          {'ins_code': '322', 'primary_name': 'Lecithin (Soy)', 'risk_tier': 'GREEN'},
          {'ins_code': 'vanillin', 'primary_name': 'Vanillin (Artificial Flavor)', 'risk_tier': 'CAUTION'},
        ]),
        'ingredients_json': jsonEncode(['Sugar', 'Palm Oil', 'Hazelnuts (13%)', 'Skimmed Milk Powder', 'Fat-Reduced Cocoa (7.4%)', 'Lecithin', 'Vanillin']),
      },
    };

    if (catalog.containsKey(barcode)) {
      return catalog[barcode];
    }
    return null;
  }
}
