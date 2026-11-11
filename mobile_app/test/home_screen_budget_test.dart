import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/features/camera/application/product_scanner_service.dart';
import 'package:mobile_app/features/home/application/daily_consumption_tracker.dart';
import 'package:mobile_app/features/home/application/home_dashboard_service.dart';
import 'package:mobile_app/features/home/domain/home_dashboard_data.dart';
import 'package:mobile_app/features/home/presentation/home_screen.dart';

class StubHomeDashboardService extends HomeDashboardService {
  @override
  Future<HomeDashboardData> getDashboardData(String userId, dynamic profile) async {
    return const HomeDashboardData(
      consumedSugarGrams: 0.0,
      maxSugarGrams: 25.0,
      redAdditivesToday: 0,
      recentProducts: [],
      isUserHistory: false,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DailyConsumptionTracker.resetInstanceForTesting();
  });

  const testCookieProduct = ScannedProductResult(
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
    healthScore: 48,
    verdictTag: 'Moderate',
    novaGrade: 4,
    redCapTriggered: false,
    additives: [],
    splitSugars: [],
    safePortionGrams: 25,
    limitingFactor: 'Sugar',
    frequencySchedule: '2-3 times/week',
    portionAdvice: 'Safe portion: 25g',
    isExceededBudget: false,
  );

  const testRedProduct = ScannedProductResult(
    barcode: '8901491101831',
    productName: 'Spicy Extruded Puffs',
    brandName: 'Crunchy',
    category: 'Snacks',
    servingSizeG: 30.0,
    packWeightG: 60.0,
    caloriesPerServing: 150.0,
    caloriesPer100g: 500.0,
    sugarGPer100g: 2.0,
    sugarGPerServing: 0.6,
    satFatGPer100g: 10.0,
    sodiumMgPer100g: 650.0,
    healthScore: 35,
    verdictTag: 'Ultra-Processed',
    novaGrade: 4,
    redCapTriggered: true,
    additives: [
      {'ins_code': '635', 'primary_name': 'Disodium ribonucleotides', 'risk_tier': 'RED'},
    ],
    splitSugars: [],
    safePortionGrams: 20,
    limitingFactor: 'Additives',
    frequencySchedule: 'Rarely',
    portionAdvice: 'Limit intake',
    isExceededBudget: false,
  );

  Widget createHomeScreen() {
    return ProviderScope(
      child: MaterialApp(
        home: HomeScreen(
          userId: 'test_budget_user',
          dashboardService: StubHomeDashboardService(),
        ),
      ),
    );
  }

  testWidgets('Daily Consumption Budget card updates reactively upon logging foods and supports bottom sheet reset', (tester) async {
    await tester.pumpWidget(createHomeScreen());
    await tester.pumpAndSettle();

    // 1. Initial State: clean 0.0g / 25g (0%), WHO Safe, 0 Red additives
    expect(find.text('Daily Consumption Budget'), findsOneWidget);
    expect(find.text('WHO Safe'), findsOneWidget);
    expect(find.textContaining('0.0g / 25g (0%)'), findsOneWidget);
    expect(find.textContaining('0 Red-tier chemical additives consumed today. All safe.'), findsOneWidget);

    // 2. Tapping Budget Card opens Today's Intake Log bottom sheet
    await tester.tap(find.text('Daily Consumption Budget'));
    await tester.pumpAndSettle();

    expect(find.text("Today's Intake Log"), findsOneWidget);
    expect(find.text('No food items logged today yet.'), findsOneWidget);

    // Close sheet
    Navigator.of(tester.element(find.text("Today's Intake Log"))).pop();
    await tester.pumpAndSettle();

    // 3. Log Good Day Butter Cookies (25g serving -> 6.1g sugar)
    await DailyConsumptionTracker.instance.logProductIntake(testCookieProduct, portionGrams: 25.0);
    await tester.pump();

    // 4. Verify instantaneous 0ms reactivity on Homepage Budget Card!
    expect(find.textContaining('6.1g / 25g (24%)'), findsOneWidget);
    expect(find.text('WHO Safe'), findsOneWidget);
    expect(find.textContaining('0 Red-tier chemical additives consumed today. All safe.'), findsOneWidget);

    // 5. Log Product with Red-tier Additive (30g portion -> 0.6g sugar, 1 red additive)
    await DailyConsumptionTracker.instance.logProductIntake(testRedProduct, portionGrams: 30.0);
    await tester.pump();

    // 6. Verify status changes to Moderate Load due to Red Additive, and sugar updates
    expect(find.textContaining('6.7g / 25g (27%)'), findsOneWidget);
    expect(find.text('Moderate Load'), findsOneWidget);
    expect(find.textContaining('1 Red-tier chemical additive(s) consumed today!'), findsOneWidget);

    // 7. Tap card to view list of logged items in bottom sheet
    await tester.tap(find.text('Daily Consumption Budget'));
    await tester.pumpAndSettle();

    expect(find.text("Today's Intake Log"), findsOneWidget);
    expect(find.text('Good Day Butter Cookies'), findsOneWidget);
    expect(find.text('Spicy Extruded Puffs'), findsOneWidget);
    expect(find.text('Reset Today'), findsOneWidget);

    // 8. Delete the cookies entry via delete button
    final deleteButtons = find.byIcon(Icons.delete_outline_rounded);
    expect(deleteButtons, findsNWidgets(2));
    await tester.tap(deleteButtons.first);
    await tester.pumpAndSettle();

    // After deleting cookies (6.1g), only puffs remain (0.6g)
    expect(find.text('Good Day Butter Cookies'), findsNothing);
    expect(find.text('Spicy Extruded Puffs'), findsOneWidget);

    // Close sheet
    Navigator.of(tester.element(find.text("Today's Intake Log"))).pop();
    await tester.pumpAndSettle();

    expect(find.textContaining('0.6g / 25g (2%)'), findsOneWidget);

    // 9. Open sheet again and tap Reset Today
    await tester.tap(find.text('Daily Consumption Budget'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Reset Today'));
    await tester.pumpAndSettle();

    // Confirmation dialog
    expect(find.text('Reset Today\'s Intake?'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    // Verify card is back to 0.0g / 25g (0%) and WHO Safe!
    expect(find.textContaining('0.0g / 25g (0%)'), findsOneWidget);
    expect(find.text('WHO Safe'), findsOneWidget);
    expect(find.textContaining('0 Red-tier chemical additives consumed today. All safe.'), findsOneWidget);
  });
}

