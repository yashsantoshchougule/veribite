import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../camera/application/offline_barcode_repository.dart';
import '../../camera/application/product_scanner_service.dart';
import '../../profile/application/user_profile_manager.dart';
import '../../profile/domain/user_profile_model.dart';
import '../domain/logged_food_entry.dart';

/// Reactive Singleton State Manager tracking today's consumed sugar and red-tier additives.
/// Automatically resets at local midnight and persists across app restarts using SharedPreferences.
class DailyConsumptionTracker extends ChangeNotifier {
  static DailyConsumptionTracker? _instance;
  static DailyConsumptionTracker get instance => _instance ??= DailyConsumptionTracker();

  DailyConsumptionTracker() {
    UserProfileManager.instance.addListener(_onUserProfileChanged);
  }

  void _onUserProfileChanged() {
    if (UserProfileManager.instance.isInitialized) {
      updateProfile(UserProfileManager.instance.profile);
    }
  }

  @override
  void dispose() {
    UserProfileManager.instance.removeListener(_onUserProfileChanged);
    super.dispose();
  }

  @visibleForTesting
  static void resetInstanceForTesting() {
    _instance?.dispose();
    _instance = null;
  }

  static const String _keyPrefix = 'veribite_daily_intake_';

  double _consumedSugarGrams = 0.0;
  double _dailySugarCeilingGrams = 25.0;
  int _redTierAdditivesCount = 0;
  List<LoggedFoodEntry> _entries = [];
  bool _isInitialized = false;
  String _activeDateKey = '';

  double get consumedSugarGrams => _consumedSugarGrams;
  double get dailySugarCeilingGrams => _dailySugarCeilingGrams;
  int get redTierAdditivesCount => _redTierAdditivesCount;
  List<LoggedFoodEntry> get entries => List.unmodifiable(_entries);
  bool get isInitialized => _isInitialized;

  double get percentageOfCeiling => _dailySugarCeilingGrams > 0
      ? ((_consumedSugarGrams / _dailySugarCeilingGrams) * 100.0)
      : 0.0;

  String _formatDateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$_keyPrefix$y-$m-$d';
  }

  /// Calculates dynamic WHO / ICMR safe daily sugar ceiling based on user profile
  double calculateCeilingFromProfile(UserProfileModel? profile) {
    final active = profile ??
        (UserProfileManager.instance.isInitialized
            ? UserProfileManager.instance.profile
            : null);
    if (active == null) return 25.0;
    if (active.isDiabetic) return 10.0;
    if (active.isLowSugar) return 10.0;
    if (active.isChild) return 15.0;
    return 25.0;
  }

  /// Updates ceiling threshold from active profile and notifies listeners
  void updateProfile(UserProfileModel profile) {
    _dailySugarCeilingGrams = calculateCeilingFromProfile(profile);
    notifyListeners();
  }

  /// Synchronizes baseline metrics from cloud/dashboard history if local entries are not yet cached
  void syncFromDashboardData({
    required double consumedSugar,
    required int redAdditives,
  }) {
    if (_entries.isEmpty && (_consumedSugarGrams == 0.0 || _consumedSugarGrams != consumedSugar)) {
      _consumedSugarGrams = consumedSugar;
      _redTierAdditivesCount = redAdditives;
      notifyListeners();
    }
  }

  /// Initializes daily intake from SharedPreferences. Automatically checks date rollover.
  Future<void> initialize({UserProfileModel? profile}) async {
    final todayKey = _formatDateKey(DateTime.now().toLocal());
    final active = profile ??
        (UserProfileManager.instance.isInitialized
            ? UserProfileManager.instance.profile
            : null);
    _dailySugarCeilingGrams = calculateCeilingFromProfile(active);

    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(todayKey);

      if (raw != null) {
        final Map<String, dynamic> data = jsonDecode(raw);
        _consumedSugarGrams = (data['consumed_sugar'] as num?)?.toDouble() ?? 0.0;
        _redTierAdditivesCount = (data['red_additives'] as num?)?.toInt() ?? 0;
        final rawEntries = data['entries'] as String?;
        if (rawEntries != null) {
          _entries = LoggedFoodEntry.decodeList(rawEntries);
        } else {
          _entries = [];
        }
      } else {
        // Fresh day: clean slate
        _consumedSugarGrams = 0.0;
        _redTierAdditivesCount = 0;
        _entries = [];
      }
      _activeDateKey = todayKey;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('[DailyConsumptionTracker] Notice initializing from SharedPreferences: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Computes red-tier additive count from product additives and redCapTriggered
  int countRedTierAdditives(ScannedProductResult product) {
    int count = 0;
    for (final additive in product.additives) {
      final tier = additive['risk_tier']?.toString().toUpperCase() ?? '';
      final hazard = additive['hazard_level']?.toString().toUpperCase() ?? '';
      final isHazard = additive['is_hazardous'] == true || additive['hazard_tier'] == 'RED';
      if (tier == 'RED' || hazard == 'HIGH' || isHazard) {
        count++;
      }
    }
    if (count == 0 && product.redCapTriggered) {
      count = 1;
    }
    return count;
  }

  /// Logs a consumed product portion into today's budget with exact macro scaling
  Future<void> logProductIntake(
    ScannedProductResult product, {
    double? portionGrams,
    UserProfileModel? profile,
  }) async {
    final todayKey = _formatDateKey(DateTime.now().toLocal());

    // Midnight Rollover Check: if todayKey changed since last load, start fresh
    if (_activeDateKey.isNotEmpty && _activeDateKey != todayKey) {
      _consumedSugarGrams = 0.0;
      _redTierAdditivesCount = 0;
      _entries = [];
      _activeDateKey = todayKey;
    }

    if (profile != null) {
      _dailySugarCeilingGrams = calculateCeilingFromProfile(profile);
    }

    // 1. Determine effective portion in grams
    final double effectivePortionGrams = (portionGrams != null && portionGrams > 0)
        ? portionGrams
        : (product.servingSizeG > 0 ? product.servingSizeG : 100.0);

    // 2. Determine per-100g sugar with totalSugar vs addedSugar fallback
    final double per100gSugar = product.sugarGPer100g > 0
        ? product.sugarGPer100g
        : product.addedSugarGPer100g;

    // 3. Compute scaled sugar for this portion
    final double addedSugarForPortion = double.parse(
      (per100gSugar * (effectivePortionGrams / 100.0)).toStringAsFixed(1),
    );

    // 4. Count red-tier additives
    final int productRedCount = countRedTierAdditives(product);

    // 5. Append to entries
    final entry = LoggedFoodEntry(
      productName: product.productName.isNotEmpty ? product.productName : 'Packaged Food',
      barcode: product.barcode,
      portionGrams: effectivePortionGrams,
      sugarGrams: addedSugarForPortion,
      redTierAdditivesCount: productRedCount,
      timestamp: DateTime.now().toLocal(),
      productJson: product.toJson(),
      product: product,
    );

    _entries.add(entry);
    _consumedSugarGrams = double.parse((_consumedSugarGrams + addedSugarForPortion).toStringAsFixed(1));
    _redTierAdditivesCount += productRedCount;

    // 6. Immediately notify listeners for instant 0ms UI update
    notifyListeners();

    // 7. Persist to SharedPreferences asynchronously
    await _saveToStorage(todayKey);
  }

  /// Resolves the full Product model for an entry to navigate to VerdictReportScreen.
  /// Priority 1 (0ms): Embedded Product / ProductJson
  /// Priority 2 (< 5ms): OfflineBarcodeRepository Tier 1/2 lookup by barcode or product name
  /// Priority 3 (Fallback): Reconstruct valid Product model from logged macros
  Future<Product> resolveLoggedProduct(
    LoggedFoodEntry entry, {
    UserProfileModel? profile,
    ProductScannerService? scannerService,
  }) async {
    final activeProfile = profile ??
        (UserProfileManager.instance.isInitialized
            ? UserProfileManager.instance.profile
            : UserProfileModel.defaults('guest_user'));
    final service = scannerService ?? ProductScannerService();

    // Priority 1: Embedded Product / ProductJson (0ms)
    if (entry.product != null) {
      return entry.product!;
    }
    if (entry.productJson != null && entry.productJson!.isNotEmpty) {
      try {
        return Product.fromJson(entry.productJson!);
      } catch (e) {
        debugPrint('[DailyConsumptionTracker] Notice deserializing productJson: $e');
      }
    }

    // Priority 2: Local Seed & Tier 2 Cache Lookup by Barcode or Name
    try {
      final offlineRepo = OfflineBarcodeRepository.instance;
      await offlineRepo.ensureInitialized();

      // Check by barcode first
      if (entry.barcode.isNotEmpty) {
        final cached = await offlineRepo.lookupBarcode(entry.barcode);
        if (cached != null) {
          return service.evaluateProductData(
            productData: cached,
            userProfile: activeProfile,
            barcode: entry.barcode,
          );
        }
      }

      // Check by product name in local repository
      if (entry.productName.isNotEmpty && entry.productName != 'Packaged Food') {
        final matches = await offlineRepo.searchByQuery(entry.productName);
        if (matches.isNotEmpty) {
          final bestMatch = matches.first;
          return service.evaluateProductData(
            productData: bestMatch,
            userProfile: activeProfile,
            barcode: bestMatch['barcode']?.toString() ?? entry.barcode,
          );
        }
      }
    } catch (e) {
      debugPrint('[DailyConsumptionTracker] Notice resolving product from offline repo: $e');
    }

    // Priority 3: Fallback Reconstruction
    final portion = entry.portionGrams > 0 ? entry.portionGrams : 100.0;
    final sugarPer100g = double.parse((entry.sugarGrams / (portion / 100.0)).toStringAsFixed(1));
    final estimatedCalories = (sugarPer100g * 4.0) + 150.0;

    final rawFallback = {
      'barcode': entry.barcode.isNotEmpty ? entry.barcode : 'logged_${entry.timestamp.millisecondsSinceEpoch}',
      'product_name': entry.productName,
      'brand_name': 'Packaged Brand',
      'category': 'Packaged Food',
      'serving_size_g': portion,
      'pack_weight_g': portion,
      'nutrition': {
        'energy_kcal': estimatedCalories,
        'sugar_g_per_100g': sugarPer100g,
        'sugars_100g': sugarPer100g,
        'added_sugar_g_per_100g': sugarPer100g,
        'added_sugars_100g': sugarPer100g,
      },
      'additives': entry.redTierAdditivesCount > 0
          ? [
              {
                'ins_code': 'INS ???',
                'name': 'Red-tier Additive',
                'risk_tier': 'RED',
                'hazard_level': 'HIGH',
                'is_hazardous': true,
              }
            ]
          : <Map<String, dynamic>>[],
      'nova_grade': entry.redTierAdditivesCount > 0 ? 4 : 3,
      'red_cap_triggered': entry.redTierAdditivesCount > 0 ? 1 : 0,
      'health_score': entry.redTierAdditivesCount > 0 ? 35 : 65,
      'verdict_tag': entry.redTierAdditivesCount > 0 ? 'Toxic / Capped 🔴' : 'Caution 🟠',
      'safe_portion_grams': portion.round(),
      'limiting_factor': entry.redTierAdditivesCount > 0 ? 'Toxic Additives' : 'Sugar Content',
      'frequency_schedule': 'Consume with Caution',
    };

    return service.evaluateProductData(
      productData: rawFallback,
      userProfile: activeProfile,
      barcode: entry.barcode,
    );
  }

  /// Removes a logged item at [index], subtracting its sugar and red-tier count
  Future<void> removeEntry(int index) async {
    if (index < 0 || index >= _entries.length) return;
    final removed = _entries.removeAt(index);
    _consumedSugarGrams = double.parse(
      (_consumedSugarGrams - removed.sugarGrams).clamp(0.0, 9999.0).toStringAsFixed(1),
    );
    _redTierAdditivesCount = (_redTierAdditivesCount - removed.redTierAdditivesCount).clamp(0, 999);

    notifyListeners();

    final todayKey = _formatDateKey(DateTime.now().toLocal());
    await _saveToStorage(todayKey);
  }

  /// Completely resets today's intake log back to zero
  Future<void> resetToday() async {
    _consumedSugarGrams = 0.0;
    _redTierAdditivesCount = 0;
    _entries.clear();

    notifyListeners();

    final todayKey = _formatDateKey(DateTime.now().toLocal());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(todayKey);
    } catch (_) {}
  }

  Future<void> _saveToStorage(String dateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = {
        'consumed_sugar': _consumedSugarGrams,
        'red_additives': _redTierAdditivesCount,
        'entries': LoggedFoodEntry.encodeList(_entries),
        'saved_at': DateTime.now().toUtc().toIso8601String(),
      };
      await prefs.setString(dateKey, jsonEncode(map));
    } catch (e) {
      debugPrint('[DailyConsumptionTracker] Error persisting to SharedPreferences: $e');
    }
  }
}
