import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/user_profile_model.dart';

/// Central singleton manager and reactive state container for user profile details.
///
/// Dual-layer persistence:
/// 1. Primary full JSON profile under [primaryStorageKey] (`veribite_user_profile_v1`)
/// 2. Backward-compatible per-user JSON key (`veribite_user_profile_<userId>`)
/// 3. Defensive primitive backup keys (`veribite_user_weight_kg`, `veribite_user_age`, etc.)
///    ensuring that even if a JSON schema corruption occurs, the user's personal
///    biometrics and guardrails never reset back to 65 kg defaults.
class UserProfileManager extends ChangeNotifier {
  UserProfileManager._internal();

  /// The active singleton instance
  static final UserProfileManager instance = UserProfileManager._internal();

  static const String primaryStorageKey = 'veribite_user_profile_v1';
  static const String backupWeightKey = 'veribite_user_weight_kg';
  static const String backupAgeKey = 'veribite_user_age';
  static const String backupBaselineKey = 'veribite_user_baseline';
  static const String backupConditionsKey = 'veribite_user_conditions';
  static const String backupSugarCeilingKey = 'veribite_user_sugar_ceiling_g';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  UserProfileModel _profile = UserProfileModel.defaults('local_user');
  UserProfileModel get profile => _profile;

  // Convenient reactive getters
  double get weightKg => _profile.weightKg;
  bool get isChild => _profile.isChild;
  int? get age => _profile.age;
  String? get gender => _profile.gender;
  double? get heightCm => _profile.heightCm;
  bool get isDiabetic => _profile.isDiabetic;
  bool get isHypertensive => _profile.isHypertensive;
  bool get isPregnancySafe => _profile.isPregnancySafe;
  bool get isLowSugar => _profile.isLowSugar;
  List<String> get allergens => _profile.allergens;
  String? get dietaryPreference => _profile.dietaryPreference;
  String get language => _profile.language;
  bool get isCompleted => _profile.isCompleted;

  String get baselineSummary {
    if (_profile.isDiabetic) return 'Diabetic Guard Active';
    if (_profile.isHypertensive) return 'Hypertension Guard';
    if (_profile.isChild) return 'Child Guard Active';
    return 'Safe Baseline';
  }

  double get maxSugarCeilingG {
    if (_profile.isDiabetic) return 10.0;
    if (_profile.isChild) return 15.0;
    return 25.0;
  }

  /// Initializes the singleton manager.
  /// Guarded by [_isInitialized] unless [forceReload] is true.
  Future<void> init({
    String? userId,
    SharedPreferences? prefs,
    bool forceReload = false,
  }) async {
    if (_isInitialized && !forceReload) return;

    final p = prefs ?? await SharedPreferences.getInstance();
    final effectiveUserId = userId ?? _profile.userId;

    UserProfileModel? loadedProfile;

    // 1. Try reading primary storage key first
    final primaryJson = p.getString(primaryStorageKey);
    if (primaryJson != null && primaryJson.isNotEmpty) {
      try {
        loadedProfile = UserProfileModel.fromJson(primaryJson);
      } catch (e) {
        debugPrint('[UserProfileManager] Primary JSON parsing notice: $e');
      }
    }

    // 2. Try per-user storage key if primary was missing
    if (loadedProfile == null && effectiveUserId.isNotEmpty) {
      final userJson = p.getString('veribite_user_profile_$effectiveUserId');
      if (userJson != null && userJson.isNotEmpty) {
        try {
          loadedProfile = UserProfileModel.fromJson(userJson);
        } catch (e) {
          debugPrint('[UserProfileManager] User-specific JSON parsing notice: $e');
        }
      }
    }

    // 3. Defensive Primitive Key Recovery
    final backupWeight = p.getDouble(backupWeightKey);
    final backupAge = p.getInt(backupAgeKey);
    final backupConditions = p.getStringList(backupConditionsKey) ?? const [];

    if (loadedProfile != null) {
      // Reconcile: If primitive backup has a valid non-default weight and loaded had 65, prefer backup
      if (backupWeight != null &&
          backupWeight > 0 &&
          loadedProfile.weightKg == 65.0 &&
          backupWeight != 65.0) {
        loadedProfile = loadedProfile.copyWith(weightKg: backupWeight);
      }
      _profile = loadedProfile;
    } else if (backupWeight != null && backupWeight > 0) {
      // Reconstruct from primitive keys if JSON was absent or wiped
      _profile = UserProfileModel(
        userId: effectiveUserId,
        weightKg: backupWeight,
        age: backupAge,
        isChild: backupConditions.contains('child'),
        isDiabetic: backupConditions.contains('diabetic'),
        isHypertensive: backupConditions.contains('hypertensive'),
        isPregnancySafe: backupConditions.contains('pregnancy_safe'),
        isLowSugar: backupConditions.contains('low_sugar'),
        isCompleted: true,
        updatedAt: DateTime.now(),
      );
    } else {
      _profile = UserProfileModel.defaults(effectiveUserId);
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Updates the profile in-memory and persistently saves to SharedPreferences.
  Future<void> updateProfile(
    UserProfileModel newProfile, {
    bool notify = true,
    SharedPreferences? prefs,
  }) async {
    _profile = newProfile;
    _isInitialized = true;
    if (notify) notifyListeners();

    try {
      final p = prefs ?? await SharedPreferences.getInstance();

      // 1. Primary full JSON key
      await p.setString(primaryStorageKey, newProfile.toJson());

      // 2. Backward-compatible per-user JSON key
      if (newProfile.userId.isNotEmpty) {
        await p.setString(
          'veribite_user_profile_${newProfile.userId}',
          newProfile.toJson(),
        );
      }

      // 3. Individual primitive backup keys
      await p.setDouble(backupWeightKey, newProfile.weightKg);
      if (newProfile.age != null) {
        await p.setInt(backupAgeKey, newProfile.age!);
      }
      await p.setString(backupBaselineKey, baselineSummary);

      final conditions = <String>[];
      if (newProfile.isChild) conditions.add('child');
      if (newProfile.isDiabetic) conditions.add('diabetic');
      if (newProfile.isHypertensive) conditions.add('hypertensive');
      if (newProfile.isPregnancySafe) conditions.add('pregnancy_safe');
      if (newProfile.isLowSugar) conditions.add('low_sugar');
      await p.setStringList(backupConditionsKey, conditions);

      await p.setDouble(backupSugarCeilingKey, maxSugarCeilingG);
    } catch (e) {
      debugPrint('[UserProfileManager] Error persisting profile: $e');
    }
  }

  /// Fast helper to update weight with validation and immediate persistence.
  Future<void> updateWeight(double newWeightKg) async {
    if (newWeightKg < 15.0 || newWeightKg > 250.0) return;
    final updated = _profile.copyWith(
      weightKg: newWeightKg,
      updatedAt: DateTime.now(),
    );
    await updateProfile(updated);
  }

  /// Reset the singleton state (for logout or testing purposes).
  void resetState() {
    _isInitialized = false;
    _profile = UserProfileModel.defaults('local_user');
  }

  /// Reset the singleton state for testing purposes.
  @visibleForTesting
  void resetForTesting() => resetState();
}

