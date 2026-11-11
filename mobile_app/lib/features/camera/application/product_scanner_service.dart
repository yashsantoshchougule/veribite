import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/network/backend_endpoint_resolver.dart';
import '../../../core/scoring/dosage_engine.dart';
import '../../../core/vision/barcode_scanner_service.dart';
import '../../../core/vision/food_web_extractor.dart';
import '../../../core/vision/gemini_vision_service.dart';
import '../../../core/vision/on_device_vision_service.dart';
import '../../../core/intelligence/web_health_intelligence_enricher.dart';
import '../../../services/multi_provider_ai_router.dart';
import '../../health_intelligence/domain/health_intelligence_model.dart';
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
  final double caloriesPer100g;
  final double proteinGPer100g;
  final double carbsGPer100g;
  final double fiberGPer100g;
  final double addedSugarGPer100g;
  final double transFatGPer100g;
  final double totalFatGPer100g;
  final double cholesterolMgPer100g;
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
  final HealthIntelligence? healthIntelligence;

  double get effectiveCaloriesPer100g {
    if (caloriesPer100g > 0.0) return caloriesPer100g;
    if (servingSizeG > 0.0) return (caloriesPerServing * (100.0 / servingSizeG)).roundToDouble();
    return caloriesPerServing;
  }

  /// Universal validator ensuring product has verified non-zero nutritional macronutrients.
  /// Rejects empty or partial stub records (e.g. only NOVA group or ingredients text reported).
  bool get hasValidMacros {
    final lowerName = productName.toLowerCase();
    final lowerCat = category.toLowerCase();
    final isZeroCalExempt = lowerName.contains('water') ||
        lowerName.contains('black coffee') ||
        lowerName.contains('green tea') ||
        lowerName.contains('soda water') ||
        lowerCat.contains('water') ||
        lowerCat.contains('tea');

    if (isZeroCalExempt) return true;

    final energy = effectiveCaloriesPer100g;
    final hasMacro = carbsGPer100g > 0.0 ||
        totalFatGPer100g > 0.0 ||
        proteinGPer100g > 0.0 ||
        sugarGPer100g > 0.0;

    return energy > 0.0 && hasMacro;
  }

  const ScannedProductResult({
    required this.barcode,
    required this.productName,
    required this.brandName,
    required this.category,
    required this.servingSizeG,
    required this.sugarGPer100g,
    required this.sugarGPerServing,
    required this.caloriesPerServing,
    this.caloriesPer100g = 0.0,
    this.proteinGPer100g = 0.0,
    this.carbsGPer100g = 0.0,
    this.fiberGPer100g = 0.0,
    this.addedSugarGPer100g = 0.0,
    this.transFatGPer100g = 0.0,
    this.totalFatGPer100g = 0.0,
    this.cholesterolMgPer100g = 0.0,
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
    this.healthIntelligence,
  });

  ScannedProductResult copyWith({
    String? barcode,
    String? productName,
    String? brandName,
    String? category,
    double? servingSizeG,
    double? sugarGPer100g,
    double? sugarGPerServing,
    double? caloriesPerServing,
    double? caloriesPer100g,
    double? proteinGPer100g,
    double? carbsGPer100g,
    double? fiberGPer100g,
    double? addedSugarGPer100g,
    double? transFatGPer100g,
    double? totalFatGPer100g,
    double? cholesterolMgPer100g,
    double? satFatGPer100g,
    double? satFatGPerServing,
    double? sodiumMgPer100g,
    double? sodiumMgPerServing,
    double? packWeightG,
    int? healthScore,
    String? verdictTag,
    int? novaGrade,
    bool? redCapTriggered,
    int? safePortionGrams,
    int? safePieces,
    String? limitingFactor,
    String? frequencySchedule,
    List<Map<String, dynamic>>? additives,
    List<String>? splitSugars,
    String? portionAdvice,
    bool? isExceededBudget,
    String? analysisSource,
    String? scoreBreakdown,
    bool? isIngredientOnlyScore,
    HealthIntelligence? healthIntelligence,
  }) {
    return ScannedProductResult(
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      brandName: brandName ?? this.brandName,
      category: category ?? this.category,
      servingSizeG: servingSizeG ?? this.servingSizeG,
      sugarGPer100g: sugarGPer100g ?? this.sugarGPer100g,
      sugarGPerServing: sugarGPerServing ?? this.sugarGPerServing,
      caloriesPerServing: caloriesPerServing ?? this.caloriesPerServing,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      proteinGPer100g: proteinGPer100g ?? this.proteinGPer100g,
      carbsGPer100g: carbsGPer100g ?? this.carbsGPer100g,
      fiberGPer100g: fiberGPer100g ?? this.fiberGPer100g,
      addedSugarGPer100g: addedSugarGPer100g ?? this.addedSugarGPer100g,
      transFatGPer100g: transFatGPer100g ?? this.transFatGPer100g,
      totalFatGPer100g: totalFatGPer100g ?? this.totalFatGPer100g,
      cholesterolMgPer100g: cholesterolMgPer100g ?? this.cholesterolMgPer100g,
      satFatGPer100g: satFatGPer100g ?? this.satFatGPer100g,
      satFatGPerServing: satFatGPerServing ?? this.satFatGPerServing,
      sodiumMgPer100g: sodiumMgPer100g ?? this.sodiumMgPer100g,
      sodiumMgPerServing: sodiumMgPerServing ?? this.sodiumMgPerServing,
      packWeightG: packWeightG ?? this.packWeightG,
      healthScore: healthScore ?? this.healthScore,
      verdictTag: verdictTag ?? this.verdictTag,
      novaGrade: novaGrade ?? this.novaGrade,
      redCapTriggered: redCapTriggered ?? this.redCapTriggered,
      safePortionGrams: safePortionGrams ?? this.safePortionGrams,
      safePieces: safePieces ?? this.safePieces,
      limitingFactor: limitingFactor ?? this.limitingFactor,
      frequencySchedule: frequencySchedule ?? this.frequencySchedule,
      additives: additives ?? this.additives,
      splitSugars: splitSugars ?? this.splitSugars,
      portionAdvice: portionAdvice ?? this.portionAdvice,
      isExceededBudget: isExceededBudget ?? this.isExceededBudget,
      analysisSource: analysisSource ?? this.analysisSource,
      scoreBreakdown: scoreBreakdown ?? this.scoreBreakdown,
      isIngredientOnlyScore: isIngredientOnlyScore ?? this.isIngredientOnlyScore,
      healthIntelligence: healthIntelligence ?? this.healthIntelligence,
    );
  }

  /// Serializes ScannedProductResult to a raw map suitable for OfflineBarcodeRepository Tier 2 persistence
  Map<String, dynamic> toRawProductMap() {
    return {
      'barcode': barcode,
      'product_name': productName,
      'brand_name': brandName,
      'category': category,
      'serving_size_g': servingSizeG,
      'pack_weight_g': packWeightG,
      'nutrition': {
        'energy_kcal': effectiveCaloriesPer100g,
        'sugars_100g': sugarGPer100g,
        'saturated-fat_100g': satFatGPer100g,
        'total_fat_g': totalFatGPer100g,
        'sodium_mg': sodiumMgPer100g,
        'proteins_100g': proteinGPer100g,
        'carbohydrates_100g': carbsGPer100g,
        'fiber_100g': fiberGPer100g,
        'added_sugars_100g': addedSugarGPer100g,
        'trans_fat_100g': transFatGPer100g,
        'cholesterol_mg': cholesterolMgPer100g,
      },
      'additives': additives,
      'nova_grade': novaGrade,
      'health_score': healthScore,
      'verdict_tag': verdictTag,
      'red_cap_triggered': redCapTriggered ? 1 : 0,
      'safe_portion_grams': safePortionGrams,
      'limiting_factor': limitingFactor,
      'frequency_schedule': frequencySchedule,
      'health_intelligence': healthIntelligence?.toJson(),
      'source': analysisSource ?? 'veribite_scanner',
    };
  }
}

/// Clean type alias for ScannedProductResult matching domain naming
typedef Product = ScannedProductResult;

/// Service that queries Supabase Cloud, Open Food Facts live API, or built-in verified product registries,
/// and computes personalized safe consumption ceilings and toxicology guardrails.
class ProductScannerService {
  /// Universal validator for raw nutriments maps from Open Food Facts, caches, or API responses.
  /// Returns true only if valid energy and at least one core macro are present.
  static bool hasValidNutrimentsMap(
    Map<String, dynamic>? nutriments, {
    String? productName,
    String? category,
  }) {
    if (nutriments == null || nutriments.isEmpty) return false;

    final name = (productName ?? '').toLowerCase();
    final cat = (category ?? '').toLowerCase();
    final isZeroCalExempt = name.contains('water') ||
        name.contains('black coffee') ||
        name.contains('green tea') ||
        name.contains('soda water') ||
        cat.contains('water') ||
        cat.contains('tea');
    if (isZeroCalExempt) return true;

    final energy = (nutriments['energy-kcal_100g'] as num?)?.toDouble() ??
        (nutriments['energy-kcal'] as num?)?.toDouble() ??
        (nutriments['energy_kcal'] as num?)?.toDouble() ??
        (((nutriments['energy-kj_100g'] as num?)?.toDouble() ??
                (nutriments['energy_kj'] as num?)?.toDouble() ??
                0.0) /
            4.184);

    final carbs = (nutriments['carbohydrates_100g'] as num?)?.toDouble() ??
        (nutriments['carbohydrates'] as num?)?.toDouble() ??
        (nutriments['carbs_100g'] as num?)?.toDouble() ??
        (nutriments['carbs_g'] as num?)?.toDouble() ??
        (nutriments['carbohydrates_g_per_100g'] as num?)?.toDouble() ??
        0.0;

    final fat = (nutriments['fat_100g'] as num?)?.toDouble() ??
        (nutriments['total-fat_100g'] as num?)?.toDouble() ??
        (nutriments['fat'] as num?)?.toDouble() ??
        (nutriments['total_fat_g'] as num?)?.toDouble() ??
        (nutriments['total_fat_g_per_100g'] as num?)?.toDouble() ??
        0.0;

    final protein = (nutriments['proteins_100g'] as num?)?.toDouble() ??
        (nutriments['protein_100g'] as num?)?.toDouble() ??
        (nutriments['proteins'] as num?)?.toDouble() ??
        (nutriments['protein'] as num?)?.toDouble() ??
        (nutriments['protein_g'] as num?)?.toDouble() ??
        0.0;

    final sugars = (nutriments['sugars_100g'] as num?)?.toDouble() ??
        (nutriments['sugars'] as num?)?.toDouble() ??
        (nutriments['sugar_g_per_100g'] as num?)?.toDouble() ??
        0.0;

    return energy > 0.0 && (carbs > 0.0 || fat > 0.0 || protein > 0.0 || sugars > 0.0);
  }

  /// Dynamically cleans and formats a domain or URL host into a clean Brand Name.
  /// e.g. "www.chingssecret.com" -> "Chings Secret", "urbanplatter.in" -> "Urban Platter"
  static String cleanDomainToBrand(String rawHostOrUrl) {
    if (rawHostOrUrl.trim().isEmpty) return 'Brand Not Listed';

    var host = rawHostOrUrl.trim();
    if (host.startsWith('http://') || host.startsWith('https://')) {
      final uri = Uri.tryParse(host);
      if (uri != null && uri.host.isNotEmpty) {
        host = uri.host;
      }
    }

    // Strip port
    if (host.contains(':')) {
      host = host.split(':').first;
    }

    // Strip subdomains
    host = host.toLowerCase();
    if (host.startsWith('www.')) host = host.substring(4);
    if (host.startsWith('m.')) host = host.substring(2);

    // Strip common TLDs
    final tldRegex = RegExp(r'\.(?:co\.in|com\.au|org\.in|com|in|org|net|co|io|app|store|shop|me)$');
    host = host.replaceAll(tldRegex, '');

    // If subdomains remain (e.g. "subdomain.maggi"), take the relevant main domain part
    if (host.contains('.')) {
      final parts = host.split('.');
      host = parts.last;
    }

    if (host.isEmpty) return 'Brand Not Listed';

    // Separate words: split camelCase, underscores, dashes
    var words = host.split(RegExp(r'[-_]')).where((w) => w.isNotEmpty).toList();

    // If single word, check for common compound brand words
    if (words.length == 1) {
      final single = words.first;
      const compoundPatterns = [
        'secret', 'spices', 'foods', 'organics', 'organic', 'kitchen',
        'chutney', 'sauces', 'mills', 'dairy', 'farms', 'farm', 'platter', 'treats', 'delight'
      ];
      for (final suffix in compoundPatterns) {
        if (single.endsWith(suffix) && single.length > suffix.length) {
          final prefix = single.substring(0, single.length - suffix.length);
          words = [prefix, suffix];
          break;
        }
      }
    }

    // Title case each word
    final capitalized = words.map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : '');
    }).join(' ').trim();

    return capitalized.isNotEmpty ? capitalized : 'Brand Not Listed';
  }
  final SupabaseClient? _injectedClient;
  final http.Client? _injectedHttpClient;
  final GeminiVisionService? _injectedVisionService;
  final OfflineBarcodeRepository? _injectedOfflineRepo;
  final BackendEndpointResolver? _injectedBackendResolver;
  final OnDeviceVisionService? _injectedOnDeviceVisionService;
  final MultiProviderAiRouter? _injectedAiRouter;

  ProductScannerService({
    SupabaseClient? client,
    http.Client? httpClient,
    GeminiVisionService? visionService,
    OfflineBarcodeRepository? offlineBarcodeRepository,
    BackendEndpointResolver? backendResolver,
    OnDeviceVisionService? onDeviceVisionService,
    MultiProviderAiRouter? aiRouter,
  })  : _injectedClient = client,
        _injectedHttpClient = httpClient,
        _injectedVisionService = visionService,
        _injectedOfflineRepo = offlineBarcodeRepository,
        _injectedBackendResolver = backendResolver,
        _injectedOnDeviceVisionService = onDeviceVisionService,
        _injectedAiRouter = aiRouter;

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
  late final MultiProviderAiRouter _aiRouter = _injectedAiRouter ??
      MultiProviderAiRouter(
        httpClient: _httpClient,
        backendResolver: _backendResolver,
        onDeviceVisionService: _onDeviceVisionService,
      );
  late final FoodWebExtractor _webExtractor = FoodWebExtractor(httpClient: _httpClient);
  late final GeminiVisionService _visionService =
      _injectedVisionService ?? GeminiVisionService(httpClient: _httpClient);
  late final WebHealthIntelligenceEnricher _intelligenceEnricher =
      WebHealthIntelligenceEnricher(httpClient: _httpClient);

  /// Enriches a scanned product result with live internet grounding or offline knowledge
  Future<ScannedProductResult> enrichProductWithWebIntelligence({
    required ScannedProductResult product,
    bool forceRefresh = false,
  }) async {
    final enriched = await _intelligenceEnricher.enrichProduct(
      productName: product.productName,
      brandName: product.brandName,
      category: product.category,
      barcode: product.barcode,
      calories: product.caloriesPer100g,
      sugarsG: product.sugarGPer100g,
      satFatG: product.satFatGPer100g,
      sodiumMg: product.sodiumMgPer100g,
      proteinG: product.proteinGPer100g,
      carbsG: product.carbsGPer100g,
      totalFatG: product.totalFatGPer100g,
      forceRefresh: forceRefresh,
    );

    final recalculated = ProductHealthScorer.calculate(
      nutrition: {
        'energy_kcal': product.caloriesPer100g,
        'sugars_100g': product.sugarGPer100g,
        'saturated-fat_100g': product.satFatGPer100g,
        'total_fat_g': product.totalFatGPer100g,
        'sodium_mg': product.sodiumMgPer100g,
        'proteins_100g': product.proteinGPer100g,
        'fiber_100g': product.fiberGPer100g,
      },
      additives: product.additives,
      novaGrade: product.novaGrade,
      redCapTriggered: product.redCapTriggered,
      healthIntelligence: enriched,
      productName: product.productName,
      category: product.category,
    );

    return product.copyWith(
      healthIntelligence: enriched,
      healthScore: recalculated.score,
      verdictTag: recalculated.verdictTag,
      redCapTriggered: recalculated.isRedCapped,
      scoreBreakdown: recalculated.scoreBreakdownSummary,
    );
  }

  /// Resolve product by any scanned QR code payload, GS1 link, food web URL, or barcode string.
  /// Supports optional camera [frameImage] and intermediate [onStatusUpdate] callbacks.
  Future<ScannedProductResult> resolveScanInput({
    required String rawScan,
    required UserProfileModel userProfile,
    List<int>? frameImage,
    void Function(String message)? onStatusUpdate,
  }) async {
    final parsed = parseQrOrBarcode(rawScan);

    // Guardrail 1: Explicit non-food QR codes rejected locally in 0ms (e.g. laptop WhatsApp support, electronics, wifi)
    if (parsed.isNonFood) {
      throw NonFoodScanException(
        'This QR code is for an electronic device or service (${parsed.nonFoodReason ?? "Non-food link"}), not a packaged food item.',
        domainOrType: parsed.nonFoodReason,
      );
    }

    // Tier 0: Direct embedded JSON payload inside QR code (0ms)
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

    return resolveBarcode(
      barcode: parsed.barcode!,
      userProfile: userProfile,
      frameImage: frameImage,
      onStatusUpdate: onStatusUpdate,
    );
  }

  /// 4-Phase strictly timed parallel pipeline for packaging web QR codes (<= 3000ms ceiling):
  /// Phase 0: Instant Cache Hit (<20ms)
  /// Phase 1: Parallel URL Unroll (Task A) + Same-Frame OCR (Task B) + Image Resize (Task C) (strict 1200ms)
  /// Phase 2: Parallel Fast Cloud AI + Database Race (strict 1500ms)
  /// Phase 3: Hard 3.0-Second Navigation Guarantee & Tier 2 Local Caching
  Future<ScannedProductResult> _resolveWebQrPipeline({
    required String url,
    required UserProfileModel userProfile,
    List<int>? frameImage,
    void Function(String message)? onStatusUpdate,
  }) async {
    // -------------------------------------------------------------------------
    // PHASE 0 — INSTANT CACHE HIT (<20ms)
    // -------------------------------------------------------------------------
    try {
      final cached = await _offlineRepo.lookupBarcode(url);
      if (cached != null) {
        final evaluated = _evaluateProduct(cached, userProfile, url);
        if (evaluated.hasValidMacros) {
          debugPrint('[ProductScannerService] Phase 0 instant cache hit for QR URL (<20ms)');
          return evaluated;
        }
      }
    } catch (_) {}

    onStatusUpdate?.call('Resolving packaging link...');

    // 0ms synchronous check for GTIN in raw URL
    final directGtin = extractGtinFromUrl(url);

    // -------------------------------------------------------------------------
    // PHASE 1 — PARALLEL URL UNROLL + SAME-FRAME OCR + IMAGE RESIZE (max 1200ms)
    // -------------------------------------------------------------------------
    final phase1Stopwatch = Stopwatch()..start();
    String? unrolledGtin = directGtin;
    String rawTitle = '';
    String brand = '';
    Map<String, dynamic>? ocrResult;
    Uint8List? compressedFrame;

    // Task A: Fast URL & Title Unroll (strict 1200ms timeout)
    final taskA = () async {
      try {
        if (unrolledGtin == null || unrolledGtin!.isEmpty) {
          unrolledGtin = await unrollUrlAndExtractGtin(url, timeoutMs: 1200);
        }
        final identity = await extractProductIdentityFromUrl(url, timeoutMs: 1200);
        if (identity != null) {
          rawTitle = identity['title'] ?? '';
          brand = identity['brand'] ?? '';
        }
      } catch (e) {
        debugPrint('[ProductScannerService] Task A unroll notice: $e');
      }
    }();

    // Task B: Simultaneous Same-Frame On-Device OCR (~120ms)
    final taskB = () async {
      if (frameImage == null || frameImage.length < 50) return;
      try {
        ocrResult = await _onDeviceVisionService.analyzeFrames([frameImage]);
      } catch (e) {
        debugPrint('[ProductScannerService] Task B OCR notice: $e');
      }
    }();

    // Task C: In-Memory Image Compression (~40ms)
    final taskC = () async {
      if (frameImage == null || frameImage.length < 50) return;
      try {
        compressedFrame = MultiProviderAiRouter.precompressFrame(frameImage, maxDimension: 1280, quality: 75);
      } catch (e) {
        debugPrint('[ProductScannerService] Task C compression notice: $e');
      }
    }();

    // Wait for Phase 1 parallel tasks (capped at 1200ms)
    await Future.wait([taskA, taskB, taskC]).timeout(
      const Duration(milliseconds: 1200),
      onTimeout: () => [],
    );

    debugPrint('[ProductScannerService] Phase 1 completed in ${phase1Stopwatch.elapsedMilliseconds}ms');

    // Fast path 1: Extracted GTIN barcode lookup (e.g. GS1 link or URL GTIN)
    if (unrolledGtin != null && unrolledGtin!.isNotEmpty) {
      onStatusUpdate?.call('Matched product barcode $unrolledGtin...');
      try {
        final barcodeRes = await resolveBarcode(barcode: unrolledGtin!, userProfile: userProfile);
        if (barcodeRes.hasValidMacros) {
          _saveToLocalTier2(url, barcodeRes);
          return barcodeRes;
        }
      } catch (e) {
        debugPrint('[ProductScannerService] Extracted GTIN barcode lookup notice: $e');
      }
    }

    // Fast path 2: If Task A + Task B already extracted complete nutrition table from back label!
    if (ocrResult != null) {
      final ocrNutriments = (ocrResult!['nutrition'] as Map<String, dynamic>?) ?? {};
      final ocrName = ocrResult!['product_name']?.toString() ?? rawTitle;
      if (hasValidNutrimentsMap(ocrNutriments, productName: ocrName)) {
        debugPrint('[ProductScannerService] Task B OCR extracted valid macros directly in ${phase1Stopwatch.elapsedMilliseconds}ms!');
        final barcodeKey = unrolledGtin ?? url;
        _writeThroughCache(ocrResult!);
        final evaluated = _evaluateProduct(ocrResult!, userProfile, barcodeKey, analysisSource: 'on_device_ocr');
        _saveToLocalTier2(url, evaluated);
        return evaluated;
      }
    }

    // Fast path 3: Direct Web Nutrition extraction check if e-commerce link
    if (unrolledGtin == null && !isYouTubeUrl(url)) {
      try {
        final directResult = await resolveFoodWebUrl(url: url, userProfile: userProfile).timeout(const Duration(milliseconds: 600));
        if (directResult.hasValidMacros) {
          _saveToLocalTier2(url, directResult);
          return directResult;
        }
      } catch (_) {}
    }

    final cleanedQuery = cleanProductQuery(rawTitle.isNotEmpty ? '$brand $rawTitle' : brand);

    onStatusUpdate?.call('Analyzing nutrition profile...');

    // -------------------------------------------------------------------------
    // PHASE 2 — PARALLEL FAST AI + DATABASE RACE (strict 1500ms timeout)
    // -------------------------------------------------------------------------
    ScannedProductResult? resolvedMatch;

    // Branch 1: Fast Cloud AI Resolution via MultiProviderAiRouter
    Future<void> runBranch1() async {
      try {
        final contextHint = cleanedQuery.isNotEmpty
            ? 'Detected QR Brand/Product: $cleanedQuery.'
            : (brand.isNotEmpty ? 'Detected QR Brand: $brand.' : null);

        final frameToUse = compressedFrame ?? (frameImage != null ? Uint8List.fromList(frameImage) : null);

        Map<String, dynamic>? aiData;
        if (frameToUse != null && frameToUse.length >= 50) {
          aiData = await _aiRouter.analyzePackagingPhoto(
            frames: [frameToUse],
            hintBarcode: contextHint,
          ).timeout(const Duration(milliseconds: 1400)).catchError((_) => null);

          aiData ??= await _visionService.analyzeProductPhoto(
            frames: [frameToUse],
            hintBarcode: contextHint,
          ).timeout(const Duration(milliseconds: 1400)).catchError((_) => null);
        }

        if (aiData == null && rawTitle.isNotEmpty && cleanedQuery.length >= 3) {
          aiData = await _aiRouter.enrichProductNutrition(
            productName: cleanProductQuery(rawTitle),
            brandName: brand.isNotEmpty ? brand : null,
          ).timeout(const Duration(milliseconds: 1400)).catchError((_) => null);
        }

        if (aiData != null && resolvedMatch == null) {
          final nutriments = (aiData['nutrition'] as Map<String, dynamic>?) ?? {};
          final pName = aiData['product_name']?.toString() ?? cleanedQuery;
          if (hasValidNutrimentsMap(nutriments, productName: pName)) {
            final barcodeKey = aiData['barcode']?.toString() ?? url;
            _writeThroughCache(aiData);
            resolvedMatch ??= _evaluateProduct(
              aiData,
              userProfile,
              barcodeKey,
              analysisSource: aiData['source']?.toString() ?? 'ai_router',
            );
          }
        }
      } catch (e) {
        debugPrint('[ProductScannerService] Branch 1 AI race notice: $e');
      }
    }

    // Branch 2: Capped Open Food Facts Lookup (max 1200ms)
    Future<void> runBranch2() async {
      try {
        if (rawTitle.isNotEmpty && cleanedQuery.length >= 3) {
          final offMatch = await queryOpenFoodFactsIndia(cleanedQuery).timeout(const Duration(milliseconds: 1200)).catchError((_) => null);
          if (offMatch != null && resolvedMatch == null) {
            Map<String, dynamic>? nutMap;
            try {
              if (offMatch['nutrition_json'] is String) {
                nutMap = jsonDecode(offMatch['nutrition_json'] as String);
              }
            } catch (_) {}
            if (hasValidNutrimentsMap(nutMap, productName: offMatch['product_name']?.toString())) {
              final barcodeKey = offMatch['barcode']?.toString() ?? url;
              _writeThroughCache(offMatch);
              resolvedMatch ??= _evaluateProduct(
                offMatch,
                userProfile,
                barcodeKey,
                analysisSource: 'open_food_facts',
              );
            }
          }
        }
      } catch (e) {
        debugPrint('[ProductScannerService] Branch 2 OFF race notice: $e');
      }
    }

    // Run Branch 1 & Branch 2 concurrently with strict 1500ms cap
    await Future.wait([runBranch1(), runBranch2()]).timeout(
      const Duration(milliseconds: 1500),
      onTimeout: () => [],
    );

    if (resolvedMatch != null) {
      _saveToLocalTier2(url, resolvedMatch!);
      return resolvedMatch!;
    }

    // -------------------------------------------------------------------------
    // PHASE 3 — HARD 3.0-SECOND NAVIGATION GUARANTEE
    // -------------------------------------------------------------------------
    final pName = rawTitle.isNotEmpty
        ? cleanProductQuery(rawTitle)
        : (cleanedQuery.isNotEmpty ? cleanedQuery : 'Product');

    throw PromotionalQrContextException(
      url: url,
      brandName: brand.isNotEmpty ? brand : null,
      productName: pName,
      message: 'Detected ${brand.isNotEmpty ? "$brand " : ""}$pName — Point camera at the back nutrition table to capture macros.',
    );
  }

  void _saveToLocalTier2(String key, ScannedProductResult product) {
    try {
      unawaited(_offlineRepo.saveProduct(
        barcode: key,
        productData: product.toRawProductMap(),
        isUserLearned: true,
      ));
    } catch (e) {
      debugPrint('[ProductScannerService] Local Tier 2 cache write notice: $e');
    }
  }

  /// Stage 2: Checks raw URL and performs lightweight HTTP GET unrolling to extract GS1 GTIN/EAN barcodes
  Future<String?> unrollUrlAndExtractGtin(String url, {int timeoutMs = 1200}) async {
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
        ..headers['Range'] = 'bytes=0-16384'
        ..headers['Accept'] = 'text/html,application/xhtml+xml,application/xml;q=0.9,application/json;q=0.8,*/*;q=0.7';

      final streamedResponse = await _httpClient.send(request).timeout(Duration(milliseconds: timeoutMs));
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
  Future<Map<String, String>?> extractProductIdentityFromUrl(String url, {int timeoutMs = 1200}) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return null;

    // 1. YouTube recipe video links
    if (isYouTubeUrl(trimmed)) {
      try {
        final oembedUri = Uri.parse('https://www.youtube.com/oembed?url=${Uri.encodeComponent(trimmed)}&format=json');
        final response = await _httpClient.get(oembedUri, headers: {'Accept': 'application/json'}).timeout(Duration(milliseconds: math.min(timeoutMs, 1100)));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data is Map) {
            final author = (data['author_name'] ?? '').toString().trim();
            final title = (data['title'] ?? '').toString().trim();
            return {
              'brand': author.isNotEmpty ? author : cleanDomainToBrand(trimmed),
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
            'Range': 'bytes=0-16384',
            'Accept': 'text/html,*/*',
          },
        ).timeout(Duration(milliseconds: timeoutMs));

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

          // Brand detection from og:site_name, author meta, or dynamic domain cleaning
          String? brand;
          final ogSite = RegExp(r'''<meta[^>]*property=["']og:site_name["'][^>]*content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
          if (ogSite != null) brand = ogSite.group(1);

          if (brand == null || brand.isEmpty) {
            final authorMatch = RegExp(r'''<meta[^>]*(?:name|property)=["']author["'][^>]*content=["']([^"']+)["']''', caseSensitive: false).firstMatch(html);
            if (authorMatch != null) brand = authorMatch.group(1);
          }

          if (brand == null || brand.isEmpty) {
            brand = cleanDomainToBrand(uri.host);
          }

          if (title != null && title.isNotEmpty) {
            return {
              'brand': (brand.isNotEmpty && brand != 'Brand Not Listed')
                  ? brand
                  : cleanDomainToBrand(uri.host),
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
          'brand': cleanDomainToBrand(uri.host),
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
              final pName = item['product_name']?.toString() ?? trimmed;
              final hasNutrition = hasValidNutrimentsMap(nutriments, productName: pName);

              if (hasNutrition) {
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
        : 'Brand Not Listed';
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

    // 2. Multi-Provider Cloud AI Pool (Gemini -> Groq -> OpenRouter -> Edge OCR)
    try {
      productData = await _aiRouter.analyzePackagingPhoto(
        frames: frames,
        hintBarcode: detectedBarcode,
      );
      if (productData != null) {
        resolvedSource = productData['source']?.toString() ?? 'ai_router';
      }
    } catch (e) {
      debugPrint('[ProductScannerService] Multi-provider AI router vision notice: $e');
    }

    // 3. Guaranteed On-Device ML Kit OCR fallback if router returned null
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
  /// Stage A: Exact lookup (Catalog -> Tier 1/2 Local DB -> Supabase -> Open Food Facts)
  /// Stage B: Same-Frame Wrapper OCR + GS1 Brand + Internet Grounding
  Future<ScannedProductResult> resolveBarcode({
    required String barcode,
    required UserProfileModel userProfile,
    List<int>? frameImage,
    void Function(String message)? onStatusUpdate,
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

    // Ensure productData actually has valid macros; if not and a camera frame is present, proceed to Stage B
    if (productData != null) {
      Map<String, dynamic>? nutMap;
      if (productData['nutrition'] is Map) {
        nutMap = Map<String, dynamic>.from(productData['nutrition'] as Map);
      } else if (productData['nutrition_json'] is String) {
        try {
          final decoded = jsonDecode(productData['nutrition_json'] as String);
          if (decoded is Map) nutMap = Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
      final pName = productData['product_name']?.toString();
      final pCat = productData['category']?.toString();
      if (!hasValidNutrimentsMap(nutMap, productName: pName, category: pCat)) {
        if (frameImage != null && frameImage.length >= 50) {
          debugPrint('[ProductScannerService] Found data without valid macros for $barcode; analyzing camera frame to complete macros.');
          productData = null;
        }
      }
    }

    // 5. Stage B: Same-Frame Wrapper OCR + GS1 Brand + Internet Grounding (when exact barcode misses DB)
    String? detectedWrapperText;
    Map<String, dynamic>? ocrProductData;
    final gs1Brand = _offlineRepo.getBrandOrManufacturerForBarcode(barcode);

    if (productData == null && frameImage != null && frameImage.length >= 50) {
      onStatusUpdate?.call('Analyzing package details with brand context...');
      try {
        final ocr = await _onDeviceVisionService.analyzeFrames([frameImage]);
        if (ocr != null) {
          ocrProductData = ocr;
          final ocrName = ocr['product_name']?.toString() ?? '';
          List<dynamic> additivesList = [];
          if (ocr['additives_json'] is String) {
            try {
              final decoded = jsonDecode(ocr['additives_json'] as String);
              if (decoded is List) additivesList = decoded;
            } catch (_) {}
          }
          final insCodes = additivesList
              .map((a) => a is Map ? a['ins_code']?.toString() : null)
              .where((c) => c != null && c.isNotEmpty)
              .take(4)
              .map((c) => 'INS $c')
              .join(', ');

          final parts = <String>[];
          if (ocrName.isNotEmpty && ocrName != 'Scanned Food Product (On-Device OCR)') {
            parts.add(ocrName);
          }
          if (insCodes.isNotEmpty) {
            parts.add('Additives: $insCodes');
          }
          if (parts.isNotEmpty) {
            detectedWrapperText = parts.join(' • ');
          }
        }
      } catch (e) {
        debugPrint('[ProductScannerService] Frame OCR notice: $e');
      }

      // If online, query Gemini with Google Search Grounding to resolve exact product
      try {
        final hintContext = [
          'Barcode: $barcode',
          if (gs1Brand != null) 'GS1 Manufacturer: $gs1Brand',
          if (detectedWrapperText != null) 'Wrapper details: $detectedWrapperText',
        ].join('. ');

        final visionData = await _aiRouter.analyzePackagingPhoto(
          frames: [frameImage],
          hintBarcode: hintContext,
        );
        if (visionData != null) {
          visionData['barcode'] = barcode;
          if (gs1Brand != null && (visionData['brand_name'] == null || visionData['brand_name'] == 'Packaged Food')) {
            visionData['brand_name'] = gs1Brand;
          }
          _writeThroughCache(visionData);
          final src = visionData['source']?.toString() ?? 'ai_router';
          return _evaluateProduct(visionData, userProfile, barcode, analysisSource: src);
        }
      } catch (e) {
        debugPrint('[ProductScannerService] Gemini vision search grounding notice: $e');
      }
    }

    // 6. If still not found online, check GS1 India 890 manufacturer prefix & pack-size siblings!
    if (productData == null) {
      try {
        final siblings = await _offlineRepo.findSiblingProducts(barcode);
        if (siblings.isNotEmpty) {
          final brandName = gs1Brand ??
              (siblings.first['brand_name']?.toString() ?? 'Packaged Brand');
          throw OfflineVariantMatchException(
            barcode: barcode,
            brandName: brandName,
            siblingProducts: siblings,
            detectedWrapperText: detectedWrapperText,
            detectedProductData: ocrProductData,
          );
        }
      } catch (e) {
        if (e is OfflineVariantMatchException) rethrow;
        debugPrint('[ProductScannerService] Sibling matcher notice: $e');
      }

      // Fallback: If on-device OCR extracted nutrition facts from frame, evaluate it directly
      if (ocrProductData != null) {
        ocrProductData['barcode'] = barcode;
        if (gs1Brand != null && (ocrProductData['brand_name'] == null || ocrProductData['brand_name'] == 'Packaged Food')) {
          ocrProductData['brand_name'] = gs1Brand;
        }
        _writeThroughCache(ocrProductData);
        return _evaluateProduct(ocrProductData, userProfile, barcode, analysisSource: 'on_device_vision');
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
          final sugars = (nutriments['sugars_100g'] as num?)?.toDouble() ??
              (nutriments['sugars'] as num?)?.toDouble() ?? 0.0;
          final satFat = (nutriments['saturated-fat_100g'] as num?)?.toDouble() ??
              (nutriments['saturated-fat'] as num?)?.toDouble() ?? 0.0;
          double sodium = 0.0;
          if (nutriments['sodium_100g'] != null) {
            sodium = (nutriments['sodium_100g'] as num).toDouble() * 1000.0;
          } else if (nutriments['salt_100g'] != null) {
            sodium = (nutriments['salt_100g'] as num).toDouble() * 400.0;
          } else if (nutriments['sodium_mg'] != null) {
            sodium = (nutriments['sodium_mg'] as num).toDouble();
          }

          final totalFat = (nutriments['fat_100g'] as num?)?.toDouble() ??
              (nutriments['total-fat_100g'] as num?)?.toDouble() ??
              (nutriments['fat'] as num?)?.toDouble() ??
              (nutriments['total_fat_g'] as num?)?.toDouble() ??
              (nutriments['total_fat'] as num?)?.toDouble() ?? 0.0;

          final carbs = (nutriments['carbohydrates_100g'] as num?)?.toDouble() ??
              (nutriments['carbohydrates'] as num?)?.toDouble() ??
              (nutriments['carbs_100g'] as num?)?.toDouble() ??
              (nutriments['carbs_g'] as num?)?.toDouble() ??
              (nutriments['total_carbohydrates_g'] as num?)?.toDouble() ?? 0.0;

          final protein = (nutriments['proteins_100g'] as num?)?.toDouble() ??
              (nutriments['protein_100g'] as num?)?.toDouble() ??
              (nutriments['proteins'] as num?)?.toDouble() ??
              (nutriments['protein'] as num?)?.toDouble() ?? 0.0;

          final fiber = (nutriments['fiber_100g'] as num?)?.toDouble() ??
              (nutriments['fibre_100g'] as num?)?.toDouble() ??
              (nutriments['dietary_fiber_g'] as num?)?.toDouble() ??
              (nutriments['fiber'] as num?)?.toDouble() ?? 0.0;

          final addedSugar = (nutriments['added-sugars_100g'] as num?)?.toDouble() ??
              (nutriments['added-sugars'] as num?)?.toDouble() ??
              (nutriments['added_sugars_g'] as num?)?.toDouble() ??
              (nutriments['added_sugar'] as num?)?.toDouble() ?? 0.0;

          final transFat = (nutriments['trans-fat_100g'] as num?)?.toDouble() ??
              (nutriments['trans-fat'] as num?)?.toDouble() ??
              (nutriments['trans_fat'] as num?)?.toDouble() ?? 0.0;

          double chol = 0.0;
          if (nutriments['cholesterol_100g'] != null) {
            final rawChol = (nutriments['cholesterol_100g'] as num).toDouble();
            chol = rawChol < 1.0 ? rawChol * 1000.0 : rawChol;
          } else if (nutriments['cholesterol_mg'] != null) {
            chol = (nutriments['cholesterol_mg'] as num).toDouble();
          }

          final energyKcal = (nutriments['energy-kcal_100g'] as num?)?.toDouble() ??
              (nutriments['energy-kcal'] as num?)?.toDouble() ??
              (((nutriments['energy-kj_100g'] as num?)?.toDouble() ?? 0.0) / 4.184);

          final energyKj = (nutriments['energy-kj_100g'] as num?)?.toDouble() ??
              (energyKcal > 0 ? energyKcal * 4.184 : 0.0);

          final servingG = (p['serving_quantity'] as num?)?.toDouble() ?? 30.0;
          final packG = (p['product_quantity'] as num?)?.toDouble() ?? (servingG * 3.0);

          final pName = (p['product_name'] ?? p['product_name_en'] ?? 'Packaged Food Item').toString();
          final pCat = (p['categories'] ?? 'Packaged Food').toString();
          if (!hasValidNutrimentsMap(nutriments, productName: pName, category: pCat)) {
            debugPrint('[ProductScannerService] Open Food Facts record for $barcode lacks valid macros. Rejecting stub.');
            return null;
          }

          return {
            'barcode': barcode,
            'product_name': p['product_name'] ?? p['product_name_en'] ?? 'Packaged Food Item',
            'brand_name': p['brands'] ?? 'Brand Not Listed',
            'category': p['categories'] ?? 'Packaged Food',
            'serving_size_g': servingG,
            'pack_weight_g': packG,
            'piece_weight_g': null,
            'nova_grade': (p['nova_group'] as num?)?.toInt() ?? 3,
            'red_cap_triggered': 0,
            'nutrition_json': jsonEncode({
              'energy_kj': energyKj,
              'energy_kcal': energyKcal,
              'calories': energyKcal,
              'sugar_g_per_100g': sugars,
              'sat_fat_g_per_100g': satFat,
              'sodium_mg_per_100g': sodium,
              'total_fat_g_per_100g': totalFat,
              'carbohydrates_g_per_100g': carbs,
              'protein_g': protein,
              'fiber_g': fiber,
              'added_sugar_g_per_100g': addedSugar,
              'trans_fat_g_per_100g': transFat,
              'cholesterol_mg_per_100g': chol,
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

  /// Public deterministic evaluation of product with scoring & dosage engines
  ScannedProductResult evaluateProduct(
    Map<String, dynamic> raw,
    UserProfileModel profile,
    String barcode, {
    String? analysisSource,
  }) {
    return _evaluateProduct(raw, profile, barcode, analysisSource: analysisSource);
  }

  /// Internal deterministic evaluation of product with scoring & dosage engines
  ScannedProductResult _evaluateProduct(
    Map<String, dynamic> raw,
    UserProfileModel profile,
    String barcode, {
    String? analysisSource,
  }) {
    final productName = raw['product_name']?.toString() ?? 'Packaged Food';
    final brandName = raw['brand_name']?.toString() ?? 'Brand Not Listed';
    final category = raw['category']?.toString() ?? 'Packaged Food';
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

    // Dynamic serving size calculation from % RDA per Serve / % RDA per 100g if missing or 0
    double servingSize = (raw['serving_size_g'] as num?)?.toDouble() ?? 0.0;
    if (servingSize <= 0.0) {
      final rdaServe = (nutritionMap['rda_per_serve'] as num?)?.toDouble() ??
          (raw['rda_per_serve'] as num?)?.toDouble();
      final rda100 = (nutritionMap['rda_per_100g'] as num?)?.toDouble() ??
          (raw['rda_per_100g'] as num?)?.toDouble();
      if (rdaServe != null && rda100 != null && rda100 > 0) {
        servingSize = double.parse(((rdaServe / rda100) * 100.0).toStringAsFixed(1));
      } else {
        servingSize = 30.0;
      }
    }

    final sugarPer100 = (nutritionMap['sugar_g_per_100g'] ?? nutritionMap['total_sugars_g'] ?? 0.0 as num).toDouble();
    final sugarPerServing = double.parse((sugarPer100 * (servingSize / 100.0)).toStringAsFixed(1));

    double caloriesPer100;
    if (nutritionMap['energy_kcal'] != null) {
      caloriesPer100 = (nutritionMap['energy_kcal'] as num).toDouble();
    } else if (nutritionMap['calories'] != null) {
      caloriesPer100 = (nutritionMap['calories'] as num).toDouble();
    } else if (nutritionMap['energy_kj'] != null) {
      caloriesPer100 = (nutritionMap['energy_kj'] as num).toDouble() / 4.184;
    } else {
      caloriesPer100 = 120.0;
    }
    caloriesPer100 = double.parse(caloriesPer100.toStringAsFixed(1));
    final caloriesPerServing = double.parse((caloriesPer100 * (servingSize / 100.0)).toStringAsFixed(0));

    // Parse real saturated fat & sodium per 100g and calculate per-serving values
    var satFatPer100 = (nutritionMap['sat_fat_g_per_100g'] ?? nutritionMap['sat_fat_g'] ?? 0.0 as num).toDouble();
    var satFatPerServing = double.parse((satFatPer100 * (servingSize / 100.0)).toStringAsFixed(1));

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

    // Secondary extracted nutrients per 100g
    final proteinPer100 = (nutritionMap['protein_g'] ??
            nutritionMap['proteins_100g'] ??
            nutritionMap['protein'] ??
            0.0 as num)
        .toDouble();
    var carbsPer100 = (nutritionMap['carbohydrates_g_per_100g'] ??
            nutritionMap['carbohydrate_g'] ??
            nutritionMap['carbs_100g'] ??
            nutritionMap['carbohydrates'] ??
            nutritionMap['carbs_g'] ??
            nutritionMap['total_carbohydrates_g'] ??
            0.0 as num)
        .toDouble();
    final fiberPer100 = (nutritionMap['fiber_g'] ??
            nutritionMap['fiber_100g'] ??
            nutritionMap['fibre_100g'] ??
            nutritionMap['dietary_fibre_g'] ??
            0.0 as num)
        .toDouble();
    final addedSugarPer100 = (nutritionMap['added_sugar_g_per_100g'] ??
            nutritionMap['added_sugars_g'] ??
            nutritionMap['added-sugars_100g'] ??
            nutritionMap['added_sugar'] ??
            0.0 as num)
        .toDouble();
    final transFatPer100 = (nutritionMap['trans_fat_g_per_100g'] ??
            nutritionMap['trans_fat_g'] ??
            nutritionMap['trans-fat_100g'] ??
            nutritionMap['trans_fat'] ??
            0.0 as num)
        .toDouble();
    var totalFatPer100 = (nutritionMap['total_fat_g_per_100g'] ??
            nutritionMap['total_fat_g'] ??
            nutritionMap['fat_100g'] ??
            nutritionMap['total-fat_100g'] ??
            nutritionMap['fat'] ??
            nutritionMap['total_fat'] ??
            0.0 as num)
        .toDouble();
    final cholesterolPer100 = (nutritionMap['cholesterol_mg_per_100g'] ??
            nutritionMap['cholesterol_mg'] ??
            nutritionMap['cholesterol_100g'] ??
            nutritionMap['cholesterol'] ??
            0.0 as num)
        .toDouble();

    // Biochemical Consistency Floor Rule 1: Total Fat >= Saturated Fat + Trans Fat
    final minFatFloor = satFatPer100 + transFatPer100;
    if (totalFatPer100 < minFatFloor) {
      totalFatPer100 = minFatFloor;
    }

    // Biochemical Consistency Floor Rule 2: Carbohydrates >= Total Sugar + Dietary Fiber
    final minCarbsFloor = sugarPer100 + fiberPer100;
    if (carbsPer100 < minCarbsFloor) {
      carbsPer100 = minCarbsFloor;
    }

    // Category Plausibility Guards: Paneer / Ready-to-Eat Paneer Makhani / Rich Dairy Gravies
    final lowerName = productName.toLowerCase();
    final lowerCat = category.toLowerCase();
    final isPaneerOrMakhani = lowerName.contains('paneer') ||
        lowerName.contains('panner') ||
        lowerName.contains('makhani') ||
        lowerCat.contains('paneer');

    if (isPaneerOrMakhani) {
      // In crowdsourced OFF entries, paneer gravies or blocks often omit total fat or calories.
      // A paneer dish with < 4g fat and < 80 kcal is implausible; apply category baseline
      if (totalFatPer100 < 4.0 && satFatPer100 < 2.0 && caloriesPer100 < 80.0) {
        totalFatPer100 = 9.5;
        satFatPer100 = 4.5;
        satFatPerServing = double.parse((satFatPer100 * (servingSize / 100.0)).toStringAsFixed(1));
        if (caloriesPer100 < 130.0) {
          caloriesPer100 = 145.0;
        }
      }
    }

    // Biochemical Consistency Floor Rule 3: Energy Kcal >= Atwater macroeconomic sum
    final atwaterMinKcal = (proteinPer100 * 4.0) + (carbsPer100 * 4.0) + (totalFatPer100 * 9.0);
    if (caloriesPer100 < atwaterMinKcal && atwaterMinKcal > 0) {
      caloriesPer100 = double.parse(atwaterMinKcal.toStringAsFixed(1));
    }

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

    // Parse or resolve rich HealthIntelligence
    HealthIntelligence? healthIntelligence;
    if (raw['health_intelligence'] is Map) {
      healthIntelligence = HealthIntelligence.fromJson(
        Map<String, dynamic>.from(raw['health_intelligence'] as Map),
      );
    } else if (raw['health_intelligence_json'] is String) {
      healthIntelligence = HealthIntelligence.fromJsonString(raw['health_intelligence_json'] as String);
    } else {
      healthIntelligence = WebHealthIntelligenceEnricher.resolveOfflineKnowledge(
        productName: productName,
        brandName: brandName,
        category: category,
        ingredients: ingredientsList,
        sugarsG: sugarPer100,
        sodiumMg: sodiumPer100,
        proteinG: proteinPer100,
        carbsG: carbsPer100,
        totalFatG: totalFatPer100,
      );
    }

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
      healthIntelligence: healthIntelligence,
      productName: productName,
      category: category,
    );

    int? finalScore;
    String verdictTag;
    final String scoreBreakdown = scoreResult.scoreBreakdownSummary;
    final bool isIngredientOnly = scoreResult.isIngredientOnlyScore;

    // Honor explicit verified scores (e.g. curated offline catalog) only if NOT the fake 65 fallback
    // and ONLY if the product has sufficient data (never award a score to an all-zero empty stub)
    final explicitScore = (raw['health_score'] as num?)?.toInt();
    if (!scoreResult.hasSufficientData) {
      finalScore = null;
      verdictTag = scoreResult.verdictTag;
    } else if (explicitScore != null && explicitScore != 65) {
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
      caloriesPer100g: caloriesPer100,
      proteinGPer100g: proteinPer100,
      carbsGPer100g: carbsPer100,
      fiberGPer100g: fiberPer100,
      addedSugarGPer100g: addedSugarPer100,
      transFatGPer100g: transFatPer100,
      totalFatGPer100g: totalFatPer100,
      cholesterolMgPer100g: cholesterolPer100,
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
      healthIntelligence: healthIntelligence,
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
