import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/scoring/dosage_engine.dart';
import '../../../core/vision/barcode_scanner_service.dart';
import '../../profile/domain/user_profile_model.dart';

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
  final int healthScore;
  final String verdictTag; // 'Nutri Safe 🟢', 'Caution 🟠', 'Toxic / Capped 🔴'
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
  });
}

/// Service that queries Supabase Cloud, Open Food Facts live API, or built-in verified product registries,
/// and computes personalized safe consumption ceilings and toxicology guardrails.
class ProductScannerService {
  final SupabaseClient? _injectedClient;
  final http.Client? _injectedHttpClient;

  ProductScannerService({SupabaseClient? client, http.Client? httpClient})
      : _injectedClient = client,
        _injectedHttpClient = httpClient;

  SupabaseClient? get _client {
    if (_injectedClient != null) return _injectedClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  http.Client get _httpClient => _injectedHttpClient ?? http.Client();

  /// Resolve product by any scanned QR code payload, GS1 link, or barcode string
  Future<ScannedProductResult> resolveScanInput({
    required String rawScan,
    required UserProfileModel userProfile,
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

    if (parsed.type != QrScanType.barcode || parsed.barcode == null) {
      throw NonFoodScanException(
        'This QR code does not contain a recognized packaged food barcode or nutrition profile.',
      );
    }

    return resolveBarcode(barcode: parsed.barcode!, userProfile: userProfile);
  }

  /// Resolve product by barcode string and evaluate against user biometrics
  Future<ScannedProductResult> resolveBarcode({
    required String barcode,
    required UserProfileModel userProfile,
  }) async {
    Map<String, dynamic>? productData;

    // 1. Try Supabase Cloud lookup
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
        }
      }
    } catch (e) {
      debugPrint('ProductScannerService: Supabase query failed: $e');
    }

    // 2. Check built-in verified catalog (Instant 0ms resolution for verified products)
    productData ??= _getCatalogProduct(barcode);

    // 3. Try Open Food Facts Live Global API (v2) for uncatalogued products
    if (productData == null) {
      try {
        final offData = await _fetchFromOpenFoodFacts(barcode);
        if (offData != null) {
          productData = offData;
        }
      } catch (e) {
        debugPrint('ProductScannerService: Open Food Facts query notice: $e');
      }
    }

    // If product is not registered in any food database, do NOT invent fake food facts!
    if (productData == null) {
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
            'health_score': 65,
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

  /// Internal deterministic evaluation of product with scoring & dosage engines
  ScannedProductResult _evaluateProduct(
    Map<String, dynamic> raw,
    UserProfileModel profile,
    String barcode,
  ) {
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

    // Health Score & Verdict
    int score = (raw['health_score'] as num?)?.toInt() ?? 65;
    final isRedCap = raw['red_cap_triggered'] == 1 ||
        raw['red_cap_triggered'] == true ||
        additivesList.any((a) => a['risk_tier'] == 'RED' || a['triggers_red_cap'] == 1);

    if (isRedCap && score > 39) {
      score = 39; // Enforce strict Red-tier additive cap
    }

    String verdictTag;
    if (score >= 70 && !isRedCap) {
      verdictTag = 'Nutri Safe 🟢';
    } else if (score >= 40 && !isRedCap) {
      verdictTag = 'Caution 🟠';
    } else {
      verdictTag = 'Toxic / Capped 🔴';
    }

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
      healthScore: score,
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
