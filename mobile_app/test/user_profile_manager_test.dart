import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/features/profile/application/user_profile_manager.dart';
import 'package:mobile_app/features/profile/domain/user_profile_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserProfileManager.instance.resetForTesting();
  });

  group('UserProfileManager Unit & Persistence Tests', () {
    test('initializes with default 65.0 kg adult when storage is empty', () async {
      final manager = UserProfileManager.instance;
      await manager.init();

      expect(manager.isInitialized, isTrue);
      expect(manager.weightKg, equals(65.0));
      expect(manager.isChild, isFalse);
      expect(manager.baselineSummary, equals('Safe Baseline'));
    });

    test('updating profile to 87 kg persists to primary JSON and primitive backup keys', () async {
      final manager = UserProfileManager.instance;
      await manager.init();

      int notificationCount = 0;
      manager.addListener(() {
        notificationCount++;
      });

      final customProfile = UserProfileModel(
        userId: 'local_user',
        weightKg: 87.0,
        age: 34,
        isChild: false,
        isDiabetic: true,
        isCompleted: true,
        updatedAt: DateTime.now(),
      );

      await manager.updateProfile(customProfile);

      expect(notificationCount, equals(1));
      expect(manager.weightKg, equals(87.0));
      expect(manager.age, equals(34));
      expect(manager.isDiabetic, isTrue);
      expect(manager.baselineSummary, equals('Diabetic Guard Active'));
      expect(manager.maxSugarCeilingG, equals(10.0));

      // Verify SharedPreferences persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(UserProfileManager.primaryStorageKey), isNotNull);
      expect(prefs.getDouble(UserProfileManager.backupWeightKey), equals(87.0));
      expect(prefs.getInt(UserProfileManager.backupAgeKey), equals(34));
      expect(prefs.getStringList(UserProfileManager.backupConditionsKey), contains('diabetic'));
    });

    test('reloading UserProfileManager after simulated restart restores 87 kg correctly', () async {
      // Step 1: Save 87 kg
      final manager = UserProfileManager.instance;
      await manager.init();
      await manager.updateWeight(87.0);

      // Step 2: Simulate app restart (reset in-memory instance, keep SharedPreferences)
      manager.resetForTesting();
      expect(manager.isInitialized, isFalse);

      // Step 3: Re-initialize from storage
      await manager.init();
      expect(manager.isInitialized, isTrue);
      expect(manager.weightKg, equals(87.0));
    });

    test('defensive recovery restores 87 kg from primitive keys if JSON profile is wiped', () async {
      final prefs = await SharedPreferences.getInstance();
      // Only set primitive backup keys (JSON missing)
      await prefs.setDouble(UserProfileManager.backupWeightKey, 87.0);
      await prefs.setInt(UserProfileManager.backupAgeKey, 40);
      await prefs.setStringList(UserProfileManager.backupConditionsKey, ['hypertensive']);

      final manager = UserProfileManager.instance;
      await manager.init(prefs: prefs);

      expect(manager.weightKg, equals(87.0));
      expect(manager.age, equals(40));
      expect(manager.isHypertensive, isTrue);
      expect(manager.baselineSummary, equals('Hypertension Guard'));
    });

    test('subsequent calls to init() never overwrite already loaded 87 kg with defaults', () async {
      final manager = UserProfileManager.instance;
      await manager.init();
      await manager.updateWeight(87.0);

      // Repeated calls (e.g. from tab switching or screen initialization)
      await manager.init();
      await manager.init(userId: 'local_user');
      await manager.init(userId: 'guest_user');

      expect(manager.weightKg, equals(87.0));
    });
  });
}

