import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

/// Exception thrown when an exact barcode is not found offline,
/// but sibling products from the same GS1 manufacturer/brand were found.
class OfflineVariantMatchException implements Exception {
  final String barcode;
  final String brandName;
  final String? manufacturer;
  final List<Map<String, dynamic>> siblingProducts;
  final String? detectedWrapperText;
  final Map<String, dynamic>? detectedProductData;

  OfflineVariantMatchException({
    required this.barcode,
    required this.brandName,
    this.manufacturer,
    required this.siblingProducts,
    this.detectedWrapperText,
    this.detectedProductData,
  });

  @override
  String toString() =>
      'OfflineVariantMatchException: Barcode $barcode matched brand $brandName with ${siblingProducts.length} siblings.';
}

/// Two-Tier Offline Barcode Repository:
/// - Tier 1: Pre-bundled read-only seed dataset (assets/db/offline_barcodes_seed.json)
/// - Tier 2: Persistent read-write local SQLite & JSON cache (learned & online-fetched products)
/// - GS1 India 890 Prefix & Brand Sibling Matcher
class OfflineBarcodeRepository {
  static OfflineBarcodeRepository? _instance;
  static OfflineBarcodeRepository get instance => _instance ??= OfflineBarcodeRepository();

  final Database? _injectedDb;
  Database? _db;
  bool _isInitialized = false;

  // In-memory O(1) lookup tables (< 1ms latency)
  final Map<String, Map<String, dynamic>> _tier1Seed = {};
  final Map<String, Map<String, dynamic>> _tier2Cache = {};

  // Prefix index: Prefix (7-8 digits) -> Set of barcodes
  final Map<String, Set<String>> _prefixToBarcodes = {};
  // Brand index: Normalized Brand Name -> Set of barcodes
  final Map<String, Set<String>> _brandToBarcodes = {};

  /// Static mapping of known Indian GS1 company prefixes to manufacturers/brands
  static const Map<String, String> knownGs1Prefixes = {
    // Haldiram's (89040044: Haldiram Snacks Food / 89040632: Haldiram Foods International)
    '89040044': "Haldiram's",
    '89040632': "Haldiram's",
    '8904004': "Haldiram's",

    // Bikaji Foods International Ltd.
    '89060055': 'Bikaji Foods',
    '8906005': 'Bikaji Foods',

    // Major Indian FMCG Brands
    '8901063': 'Britannia Industries',
    '8901058': 'Nestlé India',
    '8901719': 'Parle Products',
    '8901725': 'ITC Limited',
    '8901491': 'PepsiCo India',
    '8901499': 'PepsiCo India (Lay\'s / Kurkure)',
    '8901262': 'Amul (GCMMF)',
    '8901112': 'Mondelez India (Cadbury)',
    '8901786': 'Everest Spices',
    '8901036': 'Everest Spices',
    '8901648': 'MDH Spices',
    '8901233': 'MDH Spices',
    '8901207': 'Dabur India',
    '8901088': 'Dabur India',
    '8901157': 'Hamdard Laboratories',
    '8901287': 'Catch Spices (DS Group)',
    '8901131': 'MTR Foods (Orkla)',
    '8901030': 'Hindustan Unilever (Kissan / Horlicks)',
    '8904043': 'Tata Consumer Products (Tata Sampann)',
    '8906007': 'Balaji Wafers',
    '8906010': 'Paper Boat (Hector Beverages)',
    '8901594': "Ching's Secret (Capital Foods)",
    '8901023': 'Marico (Saffola)',
  };

  OfflineBarcodeRepository({
    Database? injectedDb,
  }) : _injectedDb = injectedDb;

  /// Ensure repository is initialized with Tier 1 seed and Tier 2 local store
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;

    // 1. Load Tier 1 pre-bundled seed from assets
    await _loadTier1Seed();

    // 2. Initialize Tier 2 local persistence (SQLite / documents JSON)
    await _initTier2Cache();

    _isInitialized = true;
    debugPrint(
      '[OfflineBarcodeRepository] Initialized with ${_tier1Seed.length} Tier 1 seed products and ${_tier2Cache.length} Tier 2 cached products.',
    );
  }

  /// Lazy loader for Tier 1 seed
  Future<void> _loadTier1Seed() async {
    try {
      final jsonString = await rootBundle.loadString('assets/db/offline_barcodes_seed.json');
      final data = jsonDecode(jsonString);
      if (data is Map && data['products'] is List) {
        final list = data['products'] as List;
        for (final item in list) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            final barcode = map['barcode']?.toString();
            if (barcode != null && barcode.isNotEmpty) {
              _tier1Seed[barcode] = map;
              _indexProduct(barcode, map);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[OfflineBarcodeRepository] Note loading Tier 1 seed asset: $e');
    }
  }

  /// Initialize Tier 2 SQLite table or local file fallback
  Future<void> _initTier2Cache() async {
    try {
      if (_injectedDb != null) {
        _db = _injectedDb;
      } else {
        final dbDir = await getDatabasesPath().timeout(const Duration(milliseconds: 300));
        final dbPath = '$dbDir/veribite_offline_products.db';
        _db = await openDatabase(
          dbPath,
          version: 1,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS local_products_cache (
                barcode TEXT PRIMARY KEY,
                product_name TEXT,
                brand_name TEXT,
                category TEXT,
                serving_size_g REAL,
                pack_weight_g REAL,
                piece_weight_g REAL,
                health_score INTEGER,
                nova_grade INTEGER,
                red_cap_triggered INTEGER,
                nutrition_json TEXT,
                additives_json TEXT,
                ingredients_json TEXT,
                is_user_learned INTEGER DEFAULT 0,
                updated_at INTEGER
              )
            ''');
          },
        ).timeout(const Duration(milliseconds: 500));
      }

      // Read all records from SQLite into _tier2Cache
      if (_db != null && _db!.isOpen) {
        final records = await _db!.query('local_products_cache');
        for (final row in records) {
          final barcode = row['barcode']?.toString();
          if (barcode != null && barcode.isNotEmpty) {
            final map = Map<String, dynamic>.from(row);
            _tier2Cache[barcode] = map;
            _indexProduct(barcode, map);
          }
        }
      }
    } catch (e) {
      debugPrint('[OfflineBarcodeRepository] SQLite init note ($e). Using persistent JSON file fallback.');
      await _loadTier2JsonFile();
    }
  }

  /// Fallback JSON file storage for environments without native SQLite C libraries
  Future<File?> _getTier2JsonFile() async {
    try {
      final dir = await getDatabasesPath().timeout(const Duration(milliseconds: 300));
      return File('$dir/veribite_tier2_products.json');
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadTier2JsonFile() async {
    try {
      final file = await _getTier2JsonFile();
      if (file != null && await file.exists()) {
        final content = await file.readAsString();
        final decoded = jsonDecode(content);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            if (entry.value is Map) {
              final map = Map<String, dynamic>.from(entry.value as Map);
              _tier2Cache[entry.key] = map;
              _indexProduct(entry.key, map);
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[OfflineBarcodeRepository] JSON file load note: $e');
    }
  }

  Future<void> _persistTier2JsonFile() async {
    try {
      final file = await _getTier2JsonFile();
      if (file != null) {
        await file.writeAsString(jsonEncode(_tier2Cache));
      }
    } catch (e) {
      debugPrint('[OfflineBarcodeRepository] JSON file save note: $e');
    }
  }

  /// Index a product by its GS1 company prefix and brand name for fast sibling lookups
  void _indexProduct(String barcode, Map<String, dynamic> product) {
    if (barcode.length >= 7) {
      final prefix7 = barcode.substring(0, 7);
      _prefixToBarcodes.putIfAbsent(prefix7, () => {}).add(barcode);
    }
    if (barcode.length >= 8) {
      final prefix8 = barcode.substring(0, 8);
      _prefixToBarcodes.putIfAbsent(prefix8, () => {}).add(barcode);
    }

    final brand = product['brand_name']?.toString().toLowerCase().trim() ?? '';
    if (brand.isNotEmpty) {
      _brandToBarcodes.putIfAbsent(brand, () => {}).add(barcode);
    }
  }

  /// Exact O(1) Barcode Lookup (< 1ms)
  /// Checks Tier 2 (read-write cache) first, then Tier 1 (pre-bundled seed).
  Future<Map<String, dynamic>?> lookupBarcode(String barcode) async {
    await ensureInitialized();

    // 1. Check Tier 2 persistent cache
    if (_tier2Cache.containsKey(barcode)) {
      return Map<String, dynamic>.from(_tier2Cache[barcode]!);
    }

    // 2. Check Tier 1 pre-bundled seed
    if (_tier1Seed.containsKey(barcode)) {
      return Map<String, dynamic>.from(_tier1Seed[barcode]!);
    }

    return null;
  }

  /// Write-Behind / Self-Learning persistence:
  /// Saves a newly resolved online product or OCR-bound product into Tier 2.
  Future<void> saveProduct({
    required String barcode,
    required Map<String, dynamic> productData,
    bool isUserLearned = false,
  }) async {
    await ensureInitialized();

    final normalized = _normalizeProductData(barcode, productData, isUserLearned);
    _tier2Cache[barcode] = normalized;
    _indexProduct(barcode, normalized);

    // Persist to SQLite if open
    try {
      if (_db != null && _db!.isOpen) {
        await _db!.insert(
          'local_products_cache',
          normalized,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      } else {
        await _persistTier2JsonFile();
      }
    } catch (e) {
      debugPrint('[OfflineBarcodeRepository] Error saving product to SQLite: $e. Writing to JSON file.');
      await _persistTier2JsonFile();
    }
  }

  /// Identify manufacturer / brand name for a given GS1 Indian barcode prefix
  String? getBrandOrManufacturerForBarcode(String barcode) {
    if (barcode.length < 7) return null;

    final prefix7 = barcode.substring(0, 7);
    if (knownGs1Prefixes.containsKey(prefix7)) {
      return knownGs1Prefixes[prefix7];
    }

    final prefix8 = barcode.length >= 8 ? barcode.substring(0, 8) : '';
    if (knownGs1Prefixes.containsKey(prefix8)) {
      return knownGs1Prefixes[prefix8];
    }

    // Check if any indexed product in Tier 1 or Tier 2 shares this prefix
    final barcodesForPrefix = _prefixToBarcodes[prefix7] ?? _prefixToBarcodes[prefix8];
    if (barcodesForPrefix != null && barcodesForPrefix.isNotEmpty) {
      final sampleBarcode = barcodesForPrefix.first;
      final product = _tier2Cache[sampleBarcode] ?? _tier1Seed[sampleBarcode];
      if (product != null && product['brand_name'] != null) {
        return product['brand_name'].toString();
      }
    }

    return null;
  }

  /// GS1 Sibling Matcher:
  /// Finds sibling products sharing the same manufacturer prefix or brand.
  Future<List<Map<String, dynamic>>> findSiblingProducts(String barcode) async {
    await ensureInitialized();

    final Set<String> siblingBarcodes = {};

    // 1. Match by GS1 company prefix (7 & 8 digits)
    if (barcode.length >= 7) {
      final prefix7 = barcode.substring(0, 7);
      if (_prefixToBarcodes.containsKey(prefix7)) {
        siblingBarcodes.addAll(_prefixToBarcodes[prefix7]!);
      }
    }
    if (barcode.length >= 8) {
      final prefix8 = barcode.substring(0, 8);
      if (_prefixToBarcodes.containsKey(prefix8)) {
        siblingBarcodes.addAll(_prefixToBarcodes[prefix8]!);
      }
    }

    // 2. If known brand name maps to prefix, also check brand index
    final identifiedBrand = getBrandOrManufacturerForBarcode(barcode);
    if (identifiedBrand != null) {
      final lowerBrand = identifiedBrand.toLowerCase().trim();
      for (final entry in _brandToBarcodes.entries) {
        if (entry.key.contains(lowerBrand) || lowerBrand.contains(entry.key)) {
          siblingBarcodes.addAll(entry.value);
        }
      }
    }

    // Remove the current barcode if present
    siblingBarcodes.remove(barcode);

    // Retrieve full product maps
    final List<Map<String, dynamic>> results = [];
    for (final b in siblingBarcodes) {
      final p = _tier2Cache[b] ?? _tier1Seed[b];
      if (p != null) {
        results.add(Map<String, dynamic>.from(p));
      }
    }

    return results;
  }

  /// Searches Tier 1 seed and Tier 2 cache by product name, brand, or category
  Future<List<Map<String, dynamic>>> searchByQuery(String query) async {
    await ensureInitialized();
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return [];

    final matchedBarcodes = <String>{};
    final allProducts = {..._tier1Seed, ..._tier2Cache};

    for (final entry in allProducts.entries) {
      final p = entry.value;
      final name = (p['product_name'] ?? '').toString().toLowerCase();
      final brand = (p['brand_name'] ?? '').toString().toLowerCase();
      final cat = (p['category'] ?? '').toString().toLowerCase();

      if (name.contains(clean) || brand.contains(clean) || cat.contains(clean)) {
        matchedBarcodes.add(entry.key);
      }
    }

    return matchedBarcodes.map((b) => Map<String, dynamic>.from(allProducts[b]!)).toList();
  }

  /// Normalize product data to guarantee schema compliance for Tier 2 storage
  Map<String, dynamic> _normalizeProductData(
    String barcode,
    Map<String, dynamic> raw,
    bool isUserLearned,
  ) {
    String nutritionJson = '{}';
    if (raw['nutrition_json'] is String) {
      nutritionJson = raw['nutrition_json'] as String;
    } else if (raw['nutrition'] != null) {
      nutritionJson = jsonEncode(raw['nutrition']);
    }

    String additivesJson = '[]';
    if (raw['additives_json'] is String) {
      additivesJson = raw['additives_json'] as String;
    } else if (raw['additives'] != null) {
      additivesJson = jsonEncode(raw['additives']);
    }

    String ingredientsJson = '[]';
    if (raw['ingredients_json'] is String) {
      ingredientsJson = raw['ingredients_json'] as String;
    } else if (raw['ingredients'] != null) {
      ingredientsJson = jsonEncode(raw['ingredients']);
    }

    return {
      'barcode': barcode,
      'product_name': raw['product_name']?.toString() ?? 'Packaged Food',
      'brand_name': raw['brand_name']?.toString() ?? 'Packaged Brand',
      'category': raw['category']?.toString() ?? 'Packaged Food',
      'serving_size_g': (raw['serving_size_g'] as num?)?.toDouble() ?? 30.0,
      'pack_weight_g': (raw['pack_weight_g'] as num?)?.toDouble() ?? 100.0,
      'piece_weight_g': (raw['piece_weight_g'] as num?)?.toDouble(),
      'health_score': (raw['health_score'] as num?)?.toInt(),
      'nova_grade': (raw['nova_grade'] as num?)?.toInt() ?? 3,
      'red_cap_triggered': raw['red_cap_triggered'] == 1 || raw['red_cap_triggered'] == true ? 1 : 0,
      'nutrition_json': nutritionJson,
      'additives_json': additivesJson,
      'ingredients_json': ingredientsJson,
      'is_user_learned': isUserLearned ? 1 : 0,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Total count of all cached products (Tier 1 + Tier 2)
  int get totalProductCount => _tier1Seed.length + _tier2Cache.length;

  /// Total count of Tier 1 pre-bundled products
  int get tier1Count => _tier1Seed.length;

  /// Total count of Tier 2 learned/cached products
  int get tier2Count => _tier2Cache.length;

  /// For unit test isolation: clear Tier 2 cache and in-memory tables
  @visibleForTesting
  void resetForTesting() {
    _tier1Seed.clear();
    _tier2Cache.clear();
    _prefixToBarcodes.clear();
    _brandToBarcodes.clear();
    _isInitialized = false;
  }
}
