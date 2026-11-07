import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/home/application/home_dashboard_service.dart';
import 'package:mobile_app/features/profile/domain/user_profile_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeDashboardService Daily Budget & Timezone Tests', () {
    const testUserId = 'user_budget_test_1';
    final adultProfile = UserProfileModel.defaults(testUserId);
    final diabeticProfile = adultProfile.copyWith(isDiabetic: true);
    final childProfile = adultProfile.copyWith(isChild: true);

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('calculateMaxSugar correctly assigns WHO/ICMR safe ceilings', () {
      final service = HomeDashboardService();

      expect(service.calculateMaxSugar(adultProfile), 25.0);
      expect(service.calculateMaxSugar(diabeticProfile), 10.0);
      expect(service.calculateMaxSugar(childProfile), 15.0);
    });

    test('loads today\'s cached consumption budget if cached on the same calendar day', () async {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();

      final cacheData = {
        'consumed_sugar': 14.5,
        'max_sugar': 25.0,
        'red_additives': 1,
        'is_user_history': true,
        'products': [],
        'cached_at': now.toIso8601String(),
      };
      await prefs.setString('veribite_dashboard_cache_$testUserId', jsonEncode(cacheData));

      final service = HomeDashboardService();
      final result = await service.getDashboardData(testUserId, adultProfile);

      expect(result.consumedSugarGrams, 14.5);
      expect(result.redAdditivesToday, 1);
    });

    test('automatically resets consumed sugar and red additives if cached on a previous day', () async {
      final prefs = await SharedPreferences.getInstance();
      final yesterday = DateTime.now().subtract(const Duration(days: 1));

      final cacheData = {
        'consumed_sugar': 22.0,
        'max_sugar': 25.0,
        'red_additives': 2,
        'is_user_history': true,
        'products': [],
        'cached_at': yesterday.toIso8601String(),
      };
      await prefs.setString('veribite_dashboard_cache_$testUserId', jsonEncode(cacheData));

      final service = HomeDashboardService();
      final result = await service.getDashboardData(testUserId, adultProfile);

      // Must be reset to 0 for the new calendar day
      expect(result.consumedSugarGrams, 0.0);
      expect(result.redAdditivesToday, 0);

      // Verify the persisted cache was also refreshed
      final updatedRaw = prefs.getString('veribite_dashboard_cache_$testUserId');
      expect(updatedRaw, isNotNull);
      final updatedMap = jsonDecode(updatedRaw!);
      expect(updatedMap['consumed_sugar'], 0.0);
      expect(updatedMap['red_additives'], 0);
    });

    test('logConsumedProduct resets yesterday\'s tally before recording today\'s item', () async {
      final prefs = await SharedPreferences.getInstance();
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));

      final cacheData = {
        'consumed_sugar': 18.0,
        'max_sugar': 25.0,
        'red_additives': 1,
        'is_user_history': true,
        'products': [],
        'cached_at': twoDaysAgo.toIso8601String(),
      };
      await prefs.setString('veribite_dashboard_cache_$testUserId', jsonEncode(cacheData));

      final service = HomeDashboardService();
      await service.logConsumedProduct(
        userId: testUserId,
        barcode: '8901063012117',
        consumedSugarGrams: 5.5,
        hasRedAdditives: false,
      );

      // After logging today, should be 0 + 5.5 = 5.5g (not 18.0 + 5.5 = 23.5g)
      final raw = prefs.getString('veribite_dashboard_cache_$testUserId');
      final map = jsonDecode(raw!);
      expect(map['consumed_sugar'], 5.5);
      expect(map['red_additives'], 0);
    });
  });
}
