import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../profile/domain/user_profile_model.dart';
import '../domain/home_dashboard_data.dart';

/// Service responsible for querying live database metrics, scan history,
/// and products catalog for the VeriBite Home Dashboard.
class HomeDashboardService {
  final SupabaseClient? _injectedClient;
  static const String _cachePrefix = 'veribite_dashboard_cache_';

  HomeDashboardService({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient? get _client {
    if (_injectedClient != null) {
      return _injectedClient;
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Calculates dynamic WHO / ICMR safe daily sugar ceiling based on user's active health profile
  double calculateMaxSugar(UserProfileModel profile) {
    if (profile.isDiabetic) {
      return 10.0; // Strict Type-2 Diabetes ceiling
    }
    if (profile.isChild) {
      return 15.0; // Southampton / Child hyperactivity ceiling
    }
    return 25.0; // Standard adult WHO 25g daily free sugar limit
  }

  /// Loads live dashboard data from Supabase Cloud with offline cache fallback
  Future<HomeDashboardData> getDashboardData(String userId, UserProfileModel profile) async {
    final maxSugar = calculateMaxSugar(profile);

    try {
      final client = _client;
      if (client == null) {
        return await _loadFromCache(userId, maxSugar, profile);
      }

      // 1. Query user's scan history joined with products
      final historyResponse = await client
          .from('scan_history')
          .select('barcode, scanned_at, products(*)')
          .eq('device_id', userId)
          .order('scanned_at', ascending: false)
          .limit(10);

      final List<dynamic> historyRows = historyResponse;

      double consumedSugar = 0.0;
      int redAdditivesCount = 0;
      final nowLocal = DateTime.now().toLocal();
      final List<DashboardProductItem> historyProducts = [];

      for (final row in historyRows) {
        if (row is! Map<String, dynamic>) continue;
        final scannedAtStr = (row['scanned_at'] ?? '').toString();
        final scannedAtDate = DateTime.tryParse(scannedAtStr)?.toLocal();
        final productMap = row['products'] as Map<String, dynamic>?;

        if (productMap != null) {
          final item = DashboardProductItem.fromDatabaseRow(productMap);
          historyProducts.add(item);

          // Compare against user's local calendar day
          final isSameDay = scannedAtDate != null &&
              scannedAtDate.year == nowLocal.year &&
              scannedAtDate.month == nowLocal.month &&
              scannedAtDate.day == nowLocal.day;

          // If scanned today in local time, add to today's consumption budget
          if (isSameDay) {
            final nutrition = productMap['nutrition_json'];
            double sugarPer100 = 0.0;
            if (nutrition is Map) {
              final rawSugar = nutrition['sugar_g_per_100g'] ?? nutrition['total_sugars_g'];
              sugarPer100 = (rawSugar is num) ? rawSugar.toDouble() : (double.tryParse(rawSugar?.toString() ?? '0') ?? 0.0);
            }

            final servingSize = (productMap['serving_size_g'] is num)
                ? (productMap['serving_size_g'] as num).toDouble()
                : (double.tryParse(productMap['serving_size_g']?.toString() ?? '30') ?? 30.0);

            consumedSugar += (sugarPer100 * (servingSize / 100.0));

            final isRedCap = productMap['red_cap_triggered'] == 1 || productMap['red_cap_triggered'] == true;
            if (isRedCap) {
              redAdditivesCount++;
            }
          }
        }
      }

      // 2. If user has history, display recent scans
      if (historyProducts.isNotEmpty) {
        final data = HomeDashboardData(
          consumedSugarGrams: double.parse(consumedSugar.toStringAsFixed(1)),
          maxSugarGrams: maxSugar,
          redAdditivesToday: redAdditivesCount,
          recentProducts: historyProducts.take(5).toList(),
          isUserHistory: true,
        );
        await _saveToCache(userId, data);
        return data;
      }

      // 3. If user has 0 scans yet, query the master database catalog (Featured Products)
      final catalogResponse = await client
          .from('products')
          .select('*')
          .limit(5);

      final List<dynamic> catalogRows = catalogResponse;
      final List<DashboardProductItem> featuredProducts = [];

      for (final row in catalogRows) {
        if (row is Map<String, dynamic>) {
          featuredProducts.add(DashboardProductItem.fromDatabaseRow(row));
        }
      }

      final data = HomeDashboardData(
        consumedSugarGrams: 0.0,
        maxSugarGrams: maxSugar,
        redAdditivesToday: 0,
        recentProducts: featuredProducts,
        isUserHistory: false,
      );
      await _saveToCache(userId, data);
      return data;
    } catch (e) {
      debugPrint('HomeDashboardService network error: $e. Falling back to cache.');
      return _loadFromCache(userId, maxSugar, profile);
    }
  }

  /// Log a new product scan in the Supabase database
  Future<void> recordScan({
    required String userId,
    required String barcode,
  }) async {
    try {
      final client = _client;
      if (client == null) return;

      await client.from('scan_history').insert({
        'device_id': userId,
        'barcode': barcode,
        'scanned_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error recording scan: $e');
    }
  }

  /// Log consumed product portion and deduct from today's safe sugar ceiling
  Future<void> logConsumedProduct({
    required String userId,
    required String barcode,
    required double consumedSugarGrams,
    required bool hasRedAdditives,
  }) async {
    // 1. Record scan entry in database history
    await recordScan(userId: userId, barcode: barcode);

    // 2. Update local cache immediately for offline responsiveness
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$userId');
      if (raw != null) {
        final Map<String, dynamic> cacheMap = jsonDecode(raw);

        // Reset if cache is from a previous calendar day
        final cachedAtStr = cacheMap['cached_at'] as String?;
        if (cachedAtStr != null) {
          final cachedDate = DateTime.tryParse(cachedAtStr)?.toLocal();
          final today = DateTime.now().toLocal();
          final isSameDay = cachedDate != null &&
              cachedDate.year == today.year &&
              cachedDate.month == today.month &&
              cachedDate.day == today.day;
          if (!isSameDay) {
            cacheMap['consumed_sugar'] = 0.0;
            cacheMap['red_additives'] = 0;
          }
        }

        final currentSugar = (cacheMap['consumed_sugar'] as num?)?.toDouble() ?? 0.0;
        final currentRed = (cacheMap['red_additives'] as num?)?.toInt() ?? 0;
        cacheMap['consumed_sugar'] = double.parse((currentSugar + consumedSugarGrams).toStringAsFixed(1));
        if (hasRedAdditives) {
          cacheMap['red_additives'] = currentRed + 1;
        }
        cacheMap['cached_at'] = DateTime.now().toIso8601String();
        await prefs.setString('$_cachePrefix$userId', jsonEncode(cacheMap));
      }
    } catch (e) {
      debugPrint('Dashboard logConsumedProduct error: $e');
    }
  }

  Future<void> _saveToCache(String userId, HomeDashboardData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheMap = {
        'consumed_sugar': data.consumedSugarGrams,
        'max_sugar': data.maxSugarGrams,
        'red_additives': data.redAdditivesToday,
        'is_user_history': data.isUserHistory,
        'products': data.recentProducts.map((p) => p.toMap()).toList(),
        'cached_at': DateTime.now().toIso8601String(),
      };
      await prefs.setString('$_cachePrefix$userId', jsonEncode(cacheMap));
    } catch (e) {
      debugPrint('Dashboard cache save error: $e');
    }
  }

  Future<HomeDashboardData> _loadFromCache(
    String userId,
    double maxSugar,
    UserProfileModel profile,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_cachePrefix$userId');
      if (raw != null) {
        final Map<String, dynamic> cacheMap = jsonDecode(raw);

        // Reset daily consumed counters if cache belongs to a past calendar day
        final cachedAtStr = cacheMap['cached_at'] as String?;
        if (cachedAtStr != null) {
          final cachedDate = DateTime.tryParse(cachedAtStr)?.toLocal();
          final today = DateTime.now().toLocal();
          final isSameDay = cachedDate != null &&
              cachedDate.year == today.year &&
              cachedDate.month == today.month &&
              cachedDate.day == today.day;
          if (!isSameDay) {
            cacheMap['consumed_sugar'] = 0.0;
            cacheMap['red_additives'] = 0;
            cacheMap['cached_at'] = DateTime.now().toIso8601String();
            await prefs.setString('$_cachePrefix$userId', jsonEncode(cacheMap));
          }
        }

        final rawProducts = cacheMap['products'] as List<dynamic>? ?? [];
        final products = rawProducts
            .map((p) => DashboardProductItem.fromCacheMap(p as Map<String, dynamic>))
            .toList();

        return HomeDashboardData(
          consumedSugarGrams: (cacheMap['consumed_sugar'] as num?)?.toDouble() ?? 0.0,
          maxSugarGrams: maxSugar, // Always use active profile's computed ceiling
          redAdditivesToday: (cacheMap['red_additives'] as num?)?.toInt() ?? 0,
          recentProducts: products,
          isUserHistory: cacheMap['is_user_history'] == true,
        );
      }
    } catch (e) {
      debugPrint('Dashboard cache read error: $e');
    }
    return HomeDashboardData.defaults(profile);
  }

  /// Utility to clear cache in unit tests
  static Future<void> resetAllCache() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_cachePrefix));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

