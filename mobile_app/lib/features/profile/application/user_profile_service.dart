import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/user_profile_model.dart';

/// Service managing strict per-user profile persistence and account isolation.
/// Profile data for user A is NEVER accessible or mixed with user B.
class UserProfileService {
  final SupabaseClient? _supabaseClient;
  final SharedPreferences? _injectedPrefs;

  // In-memory cache strictly partitioned by userId
  static final Map<String, UserProfileModel> _memoryCache = {};

  UserProfileService({
    SupabaseClient? supabaseClient,
    SharedPreferences? prefs,
  })  : _supabaseClient = supabaseClient,
        _injectedPrefs = prefs;

  SupabaseClient? get _client {
    if (_supabaseClient != null) return _supabaseClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<SharedPreferences> _getPrefs() async {
    if (_injectedPrefs != null) return _injectedPrefs;
    return await SharedPreferences.getInstance();
  }

  String _storageKey(String userId) => 'veribite_user_profile_$userId';

  /// Check whether the specific user has already completed/saved their details.
  Future<bool> hasCompletedProfile(String userId) async {
    if (userId.isEmpty) return false;

    // 1. Check memory cache first
    if (_memoryCache.containsKey(userId)) {
      return _memoryCache[userId]!.isCompleted;
    }

    // 2. Check local SharedPreferences
    final prefs = await _getPrefs();
    final jsonStr = prefs.getString(_storageKey(userId));
    if (jsonStr != null) {
      try {
        final profile = UserProfileModel.fromJson(jsonStr);
        _memoryCache[userId] = profile;
        return profile.isCompleted;
      } catch (_) {}
    }

    // 3. Check Supabase cloud if online (handles cross-device login for same Gmail)
    final client = _client;
    if (client != null && client.auth.currentUser?.id == userId) {
      final userMetadata = client.auth.currentUser?.userMetadata;
      if (userMetadata != null &&
          (userMetadata['profile_completed'] == true ||
           userMetadata['is_completed'] == true)) {
        return true;
      }

      try {
        final res = await client
            .from('user_profiles')
            .select()
            .eq('device_id', userId)
            .maybeSingle();

        if (res != null) {
          final profile = UserProfileModel.fromMap(res);
          _memoryCache[userId] = profile;
          await prefs.setString(_storageKey(userId), profile.toJson());
          return profile.isCompleted;
        }
      } catch (e) {
        debugPrint('Supabase profile fetch notice: $e');
      }
    }

    return false;
  }

  /// Retrieve the isolated profile for the given [userId].
  Future<UserProfileModel?> getProfile(String userId) async {
    if (userId.isEmpty) return null;

    // 1. Check memory cache
    if (_memoryCache.containsKey(userId)) {
      return _memoryCache[userId];
    }

    // 2. Check local SharedPreferences
    final prefs = await _getPrefs();
    final jsonStr = prefs.getString(_storageKey(userId));
    if (jsonStr != null) {
      try {
        final profile = UserProfileModel.fromJson(jsonStr);
        _memoryCache[userId] = profile;
        return profile;
      } catch (_) {}
    }

    // 3. Check Supabase cloud if online
    final client = _client;
    if (client != null && client.auth.currentUser?.id == userId) {
      try {
        final res = await client
            .from('user_profiles')
            .select()
            .eq('device_id', userId)
            .maybeSingle();

        if (res != null) {
          final profile = UserProfileModel.fromMap(res);
          _memoryCache[userId] = profile;
          await prefs.setString(_storageKey(userId), profile.toJson());
          return profile;
        }
      } catch (e) {
        debugPrint('Supabase profile fetch error: $e');
      }
    }

    return null;
  }

  /// Persist the profile strictly under [profile.userId].
  Future<void> saveProfile(UserProfileModel profile) async {
    final userId = profile.userId;
    if (userId.isEmpty) throw ArgumentError('Cannot save profile with empty userId');

    // 1. Update isolated in-memory cache
    _memoryCache[userId] = profile;

    // 2. Save to isolated SharedPreferences
    final prefs = await _getPrefs();
    await prefs.setString(_storageKey(userId), profile.toJson());

    // 3. Sync to Supabase cloud table if authenticated
    final client = _client;
    if (client != null && client.auth.currentUser?.id == userId) {
      try {
        await client.from('user_profiles').upsert({
          'device_id': userId,
          'weight_kg': profile.weightKg,
          'is_child': profile.isChild,
          'is_diabetic': profile.isDiabetic,
          'is_hypertensive': profile.isHypertensive,
          'is_completed': profile.isCompleted,
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'device_id');

        // When saved, mark profile_completed on user metadata for cross-device sync
        if (profile.isCompleted) {
          await client.auth.updateUser(
            UserAttributes(data: {'profile_completed': true}),
          );
        }
      } catch (e) {
        debugPrint('Supabase cloud profile upsert notice (offline fallback preserved): $e');
      }
    }
  }

  /// Clears in-memory cache for a user on logout to prevent cross-account leak
  void clearUserCache(String userId) {
    _memoryCache.remove(userId);
  }

  /// Clears all caches (useful for testing or full app reset)
  static void resetAllCache() {
    _memoryCache.clear();
  }
}
