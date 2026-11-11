import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/features/camera/application/product_scanner_service.dart';
import 'package:mobile_app/features/home/application/daily_consumption_tracker.dart';
import 'package:mobile_app/features/profile/domain/user_profile_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DailyConsumptionTracker.resetInstanceForTesting();
  });

  group('DailyConsumptionTracker Tests', () {
    test('initializes with clean slate and 25g adult ceiling by default', () async {
      final tracker = DailyConsumptionTracker.instance;
      await tracker.initialize();

      expect(tracker.consumedSugarGrams, 0.0);
      expect(tracker.dailySugarCeilingGrams, 25.0);
      expect(tracker.redTierAdditivesCount, 0);
      expect(tracker.entries, isEmpty);
      expect(tracker.percentageOfCeiling, 0.0);
    });

    test('initializes with 10g ceiling for diabetic and 15g for child profile', () async {
      final tracker = DailyConsumptionTracker.instance;

      final diabeticProfile = UserProfileModel.defaults('user_1').copyWith(isDiabetic: true);
      await tracker.initialize(profile: diabeticProfile);
      expect(tracker.dailySugarCeilingGrams, 10.0);

      final childProfile = UserProfileModel.defaults('user_2').copyWith(isChild: true);
      tracker.updateProfile(childProfile);
      expect(tracker.dailySugarCeilingGrams, 15.0);
    });

    test('logs product intake with portion scaling and updates reactive values', () async {
      final tracker = DailyConsumptionTracker.instance;
      await tracker.initialize();

      int listenerNotificationCount = 0;
      tracker.addListener(() {
        listenerNotificationCount++;
      });

      // Product: 24.5g sugar per 100g, 25g serving
      const testProduct = ScannedProductResult(
        barcode: '8901063012117',
        productName: 'Good Day Butter Cookies',
        brandName: 'Britannia',
        category: 'Biscuits & Cookies',
        servingSizeG: 25.0,
        packWeightG: 75.0,
        caloriesPerServing: 125.0,
        caloriesPer100g: 500.0,
        sugarGPer100g: 24.5,
        sugarGPerServing: 6.1,
        satFatGPer100g: 11.2,
        sodiumMgPer100g: 280.0,
        totalFatGPer100g: 22.0,
        carbsGPer100g: 68.0,
        proteinGPer100g: 6.0,
        fiberGPer100g: 1.8,
        addedSugarGPer100g: 20.0,
        transFatGPer100g: 0.1,
        cholesterolMgPer100g: 10.0,
        healthScore: 48,
        novaGrade: 4,
        redCapTriggered: false,
        additives: [],
        splitSugars: [],
        safePortionGrams: 25,
        limitingFactor: 'Sugar',
        verdictTag: 'Moderate',
        frequencySchedule: '2-3 times/week',
        portionAdvice: 'Safe portion advice',
        isExceededBudget: false,
      );

      // Log 1 serving (25g)
      await tracker.logProductIntake(testProduct, portionGrams: 25.0);

      // Math: 24.5 * (25 / 100) = 6.125 -> 6.1g
      expect(tracker.consumedSugarGrams, 6.1);
      expect(tracker.redTierAdditivesCount, 0);
      expect(tracker.entries.length, 1);
      expect(tracker.entries.first.productName, 'Good Day Butter Cookies');
      expect(tracker.entries.first.portionGrams, 25.0);
      expect(tracker.entries.first.sugarGrams, 6.1);
      expect(listenerNotificationCount, greaterThan(0));
      expect(tracker.percentageOfCeiling, closeTo(24.4, 0.5));
    });

    test('logs product with red-tier additive and flags redTierAdditivesCount', () async {
      final tracker = DailyConsumptionTracker.instance;
      await tracker.initialize();

      const redProduct = ScannedProductResult(
        barcode: '8901491101831',
        productName: 'Kurkure Masala Munch',
        brandName: 'PepsiCo',
        category: 'Extruded Snacks',
        servingSizeG: 30.0,
        packWeightG: 85.0,
        caloriesPerServing: 165.0,
        caloriesPer100g: 550.0,
        sugarGPer100g: 1.5,
        sugarGPerServing: 0.45,
        satFatGPer100g: 14.0,
        sodiumMgPer100g: 890.0,
        totalFatGPer100g: 34.0,
        carbsGPer100g: 56.0,
        proteinGPer100g: 6.0,
        fiberGPer100g: 2.0,
        addedSugarGPer100g: 0.0,
        transFatGPer100g: 0.1,
        cholesterolMgPer100g: 0.0,
        healthScore: 32,
        novaGrade: 4,
        redCapTriggered: true,
        additives: [
          {'ins_code': '635', 'primary_name': 'Disodium 5-ribonucleotides', 'risk_tier': 'RED'},
        ],
        splitSugars: [],
        safePortionGrams: 20,
        limitingFactor: 'Sodium & Additives',
        verdictTag: 'Ultra-Processed',
        frequencySchedule: 'Rarely',
        portionAdvice: 'Safe portion advice',
        isExceededBudget: false,
      );

      await tracker.logProductIntake(redProduct, portionGrams: 30.0);

      expect(tracker.redTierAdditivesCount, 1);
      expect(tracker.entries.first.redTierAdditivesCount, 1);
      // Math: 1.5 * (30 / 100) = 0.45 -> 0.4g (due to floating point .toStringAsFixed)
      expect(tracker.consumedSugarGrams, 0.4);
    });

    test('removeEntry and resetToday update counters and entries properly', () async {
      final tracker = DailyConsumptionTracker.instance;
      await tracker.initialize();

      const testProduct = ScannedProductResult(
        barcode: '123',
        productName: 'Juice',
        brandName: 'Brand',
        category: 'Beverages',
        servingSizeG: 100.0,
        packWeightG: 100.0,
        caloriesPerServing: 50.0,
        caloriesPer100g: 50.0,
        sugarGPer100g: 12.0,
        sugarGPerServing: 12.0,
        satFatGPer100g: 0.0,
        sodiumMgPer100g: 10.0,
        totalFatGPer100g: 0.0,
        carbsGPer100g: 12.0,
        proteinGPer100g: 0.0,
        fiberGPer100g: 0.0,
        addedSugarGPer100g: 10.0,
        transFatGPer100g: 0.0,
        cholesterolMgPer100g: 0.0,
        healthScore: 60,
        novaGrade: 3,
        redCapTriggered: false,
        additives: [],
        splitSugars: [],
        safePortionGrams: 100,
        limitingFactor: 'Sugar',
        verdictTag: 'Moderate',
        frequencySchedule: 'Daily',
        portionAdvice: 'Safe portion advice',
        isExceededBudget: false,
      );

      await tracker.logProductIntake(testProduct, portionGrams: 100.0);
      expect(tracker.consumedSugarGrams, 12.0);
      expect(tracker.entries.length, 1);

      await tracker.removeEntry(0);
      expect(tracker.consumedSugarGrams, 0.0);
      expect(tracker.entries, isEmpty);

      // Re-add and reset today
      await tracker.logProductIntake(testProduct, portionGrams: 100.0);
      expect(tracker.consumedSugarGrams, 12.0);

      await tracker.resetToday();
      expect(tracker.consumedSugarGrams, 0.0);
      expect(tracker.redTierAdditivesCount, 0);
      expect(tracker.entries, isEmpty);
    });
  });
}
