import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/features/profile/application/user_profile_service.dart';
import 'package:mobile_app/features/profile/domain/user_profile_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserProfileService.resetAllCache();
  });

  group('UserProfileModel Tests', () {
    test('default factory creates baseline 65kg adult profile marked as skipped/uncompleted', () {
      final model = UserProfileModel.defaults('user_test_123');

      expect(model.userId, equals('user_test_123'));
      expect(model.weightKg, equals(65.0));
      expect(model.isChild, isFalse);
      expect(model.isDiabetic, isFalse);
      expect(model.isHypertensive, isFalse);
      expect(model.isPregnancySafe, isFalse);
      expect(model.isCompleted, isFalse);
      expect(model.allergens, isEmpty);
    });

    test('toJson and fromJson preserves all fields faithfully', () {
      final now = DateTime.now();
      final model = UserProfileModel(
        userId: 'user_456',
        weightKg: 78.5,
        isChild: true,
        age: 9,
        gender: 'Male',
        heightCm: 135.0,
        isDiabetic: true,
        isHypertensive: false,
        isPregnancySafe: false,
        isLowSugar: true,
        allergens: ['Gluten', 'Peanuts'],
        dietaryPreference: 'Vegetarian',
        language: 'hi',
        isCompleted: true,
        updatedAt: now,
      );

      final jsonStr = model.toJson();
      final decoded = UserProfileModel.fromJson(jsonStr);

      expect(decoded.userId, equals('user_456'));
      expect(decoded.weightKg, equals(78.5));
      expect(decoded.isChild, isTrue);
      expect(decoded.age, equals(9));
      expect(decoded.gender, equals('Male'));
      expect(decoded.isDiabetic, isTrue);
      expect(decoded.allergens, containsAll(['Gluten', 'Peanuts']));
      expect(decoded.dietaryPreference, equals('Vegetarian'));
      expect(decoded.language, equals('hi'));
      expect(decoded.isCompleted, isTrue);
    });

    test('fromMap defends against integer weight and double age without crashing', () {
      final map = {
        'userId': 'user_defensive',
        'weight': 87, // integer instead of double, short key
        'age': 25.0, // double instead of int
        'isChild': false, // camelCase
        'isDiabetic': true, // camelCase
        'isHypertensive': true,
        'allergens': ['Soy'],
      };

      final profile = UserProfileModel.fromMap(map);
      expect(profile.userId, equals('user_defensive'));
      expect(profile.weightKg, equals(87.0));
      expect(profile.age, equals(25));
      expect(profile.isDiabetic, isTrue);
      expect(profile.isHypertensive, isTrue);
      expect(profile.allergens, contains('Soy'));
    });
  });

  group('UserProfileService Strict Account Isolation Tests', () {
    test('User 1 profile is strictly isolated and never leaks to User 2', () async {
      final service = UserProfileService();

      final user1Profile = UserProfileModel(
        userId: 'user_1',
        weightKg: 82.0,
        isChild: false,
        gender: 'Male',
        isDiabetic: true,
        isHypertensive: true,
        allergens: ['Lactose'],
        isCompleted: true,
        updatedAt: DateTime.now(),
      );

      // Save User 1
      await service.saveProfile(user1Profile);

      // Verify User 1 is saved
      final retrieved1 = await service.getProfile('user_1');
      expect(retrieved1, isNotNull);
      expect(retrieved1!.weightKg, equals(82.0));
      expect(retrieved1.isDiabetic, isTrue);
      expect(retrieved1.allergens, contains('Lactose'));

      // Query User 2 -> Must be completely null (zero cross-account contamination)
      final retrieved2 = await service.getProfile('user_2');
      expect(retrieved2, isNull);

      final hasProfile2 = await service.hasCompletedProfile('user_2');
      expect(hasProfile2, isFalse);

      // Save User 2 with distinct child details
      final user2Profile = UserProfileModel(
        userId: 'user_2',
        weightKg: 24.0,
        isChild: true,
        gender: 'Female',
        isDiabetic: false,
        allergens: ['Peanuts'],
        isCompleted: true,
        updatedAt: DateTime.now(),
      );
      await service.saveProfile(user2Profile);

      // Verify User 1 and User 2 remain completely separate
      final checkUser1 = await service.getProfile('user_1');
      final checkUser2 = await service.getProfile('user_2');

      expect(checkUser1!.userId, equals('user_1'));
      expect(checkUser1.weightKg, equals(82.0));
      expect(checkUser1.isChild, isFalse);

      expect(checkUser2!.userId, equals('user_2'));
      expect(checkUser2.weightKg, equals(24.0));
      expect(checkUser2.isChild, isTrue);
    });

    test('clearUserCache removes in-memory state on logout', () async {
      final service = UserProfileService();
      final user = UserProfileModel.defaults('user_logout_test');
      await service.saveProfile(user);

      expect(await service.getProfile('user_logout_test'), isNotNull);

      service.clearUserCache('user_logout_test');

      // Clear shared prefs to simulate fresh load
      SharedPreferences.setMockInitialValues({});
      expect(await service.getProfile('user_logout_test'), isNull);
    });
  });
}

