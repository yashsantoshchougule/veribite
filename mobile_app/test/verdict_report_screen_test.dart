import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/advisor/presentation/advisor_chat_screen.dart';
import 'package:mobile_app/features/camera/application/product_scanner_service.dart';
import 'package:mobile_app/features/profile/domain/user_profile_model.dart';
import 'package:mobile_app/features/results/presentation/ingredient_breakdown_screen.dart';
import 'package:mobile_app/features/results/presentation/verdict_report_screen.dart';
import 'package:mobile_app/features/results/presentation/widgets/circular_score_gauge.dart';
import 'package:mobile_app/features/results/presentation/widgets/ingredient_deep_dive_sheet.dart';

void main() {
  final testProfile = UserProfileModel.defaults('test_user_1');

  const testSafeProduct = ScannedProductResult(
    barcode: '8901491101837',
    productName: '100% Whole Grain Rolled Oats',
    brandName: 'Quaker',
    category: 'Breakfast Cereals',
    servingSizeG: 40.0,
    sugarGPer100g: 1.1,
    sugarGPerServing: 0.4,
    caloriesPerServing: 153.0,
    healthScore: 88,
    verdictTag: 'Nutri Safe 🟢',
    novaGrade: 1,
    redCapTriggered: false,
    safePortionGrams: 40,
    safePieces: null,
    limitingFactor: 'Calories',
    frequencySchedule: 'Daily Safe',
    additives: [],
    splitSugars: [],
    portionAdvice: 'Safe consumption portion: 40g (max 1.0 serving). Limiting constraint: Calories.',
    isExceededBudget: false,
  );

  const testRedCappedProduct = ScannedProductResult(
    barcode: '8901058852339',
    productName: '2-Minute Masala Noodles',
    brandName: 'Maggi',
    category: 'Instant Noodles',
    servingSizeG: 70.0,
    sugarGPer100g: 3.2,
    sugarGPerServing: 2.2,
    caloriesPerServing: 295.0,
    healthScore: 32,
    verdictTag: 'Toxic / Capped 🔴',
    novaGrade: 4,
    redCapTriggered: true,
    safePortionGrams: 25,
    safePieces: null,
    limitingFactor: 'Sodium',
    frequencySchedule: 'Strict 1–2x Per Week',
    additives: [
      {
        'ins_code': '635',
        'primary_name': 'Disodium 5-Ribonucleotides',
        'risk_tier': 'RED',
        'triggers_red_cap': 1,
      },
      {
        'ins_code': '451(i)',
        'primary_name': 'Pentasodium Triphosphate',
        'risk_tier': 'CAUTION',
      },
    ],
    splitSugars: ['Invert Sugar Syrup', 'Glucose Syrup'],
    portionAdvice: 'Safe consumption portion: 25g (max 0.4 serving). Limiting constraint: Sodium.',
    isExceededBudget: false,
  );

  testWidgets('VerdictReportScreen renders CircularScoreGauge, product title, and safe portion advice', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VerdictReportScreen(
          product: testSafeProduct,
          userProfile: testProfile,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify product name and brand
    expect(find.text('100% Whole Grain Rolled Oats'), findsOneWidget);
    expect(find.text('Quaker • Breakfast Cereals'), findsOneWidget);

    // Verify circular score gauge is present
    expect(find.byType(CircularScoreGauge), findsOneWidget);
    expect(find.text('88'), findsOneWidget);
    expect(find.text('Nutri Safe 🟢'), findsOneWidget);

    // Verify safe portion prescription card
    expect(find.textContaining('Safe consumption portion: 40g'), findsOneWidget);
    expect(find.text('Frequency: Daily Safe'), findsOneWidget);

    // Verify action buttons
    expect(find.text('I Ate This (Log to Today\'s Budget)'), findsOneWidget);
    expect(find.text('Just Checking (Don\'t Add to Budget)'), findsOneWidget);
    expect(find.text('Ask AI About This Product'), findsOneWidget);
    expect(find.text('Full Ingredients & Toxicology Breakdown'), findsOneWidget);
  });

  testWidgets('VerdictReportScreen displays 39/100 Red-cap alert banner when product has Red-tier additive', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VerdictReportScreen(
          product: testRedCappedProduct,
          userProfile: testProfile,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Red-cap banner
    expect(find.text('39/100 Toxic Red-Cap Enforced'), findsOneWidget);
    expect(find.text('Toxic / Capped 🔴'), findsOneWidget);
    expect(find.text('NOVA 4'), findsOneWidget);
    expect(find.text('32'), findsOneWidget);
  });

  testWidgets('VerdictReportScreen toggling Whole Pack multiplier scales calorie and macro readouts', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VerdictReportScreen(
          product: testSafeProduct,
          userProfile: testProfile,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially 1 Serving: 153 kcal
    expect(find.text('153'), findsOneWidget);
    expect(find.text('0.4'), findsOneWidget);

    // Tap Whole Pack toggle
    await tester.tap(find.textContaining('Whole Pack'));
    await tester.pumpAndSettle();

    // 153 * 3 = 459 kcal, 0.4 * 3 = 1.2 g sugar
    expect(find.text('459'), findsOneWidget);
    expect(find.text('1.2'), findsOneWidget);
  });

  testWidgets('VerdictReportScreen tapping Full Ingredients CTA navigates to IngredientBreakdownScreen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VerdictReportScreen(
          product: testRedCappedProduct,
          userProfile: testProfile,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Ensure Ingredients CTA is scrolled into view and tap
    final ctaFinder = find.text('Full Ingredients & Toxicology Breakdown');
    await tester.ensureVisible(ctaFinder);
    await tester.tap(ctaFinder);
    await tester.pumpAndSettle();

    // Verify navigation to IngredientBreakdownScreen
    expect(find.byType(IngredientBreakdownScreen), findsOneWidget);
    expect(find.text('Ingredients & Toxicology'), findsOneWidget);

    // Verify anti-splitting alert
    expect(find.text('Anti-Splitting Sweetener Cluster Alert'), findsOneWidget);
    expect(find.textContaining('splits sugar across 2 distinct sweetener aliases'), findsOneWidget);

    // Verify filter chips
    expect(find.textContaining('All ('), findsOneWidget);
    expect(find.textContaining('Red Flags ('), findsOneWidget);
    expect(find.textContaining('Caution ('), findsOneWidget);
    expect(find.textContaining('Safe ('), findsOneWidget);
  });

  testWidgets('IngredientBreakdownScreen tapping ingredient card presents IngredientDeepDiveSheet with citations', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: IngredientBreakdownScreen(
          product: testRedCappedProduct,
          userProfile: testProfile,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Disodium 5-Ribonucleotides card
    final card = find.text('Disodium 5-Ribonucleotides');
    expect(card, findsOneWidget);
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();

    // Verify deep dive sheet appeared
    expect(find.byType(IngredientDeepDiveSheet), findsOneWidget);
    expect(find.text('Why Manufacturers Add It'), findsOneWidget);
    expect(find.text('Health Impacts & Toxicology'), findsOneWidget);
    expect(find.text('Acceptable Daily Intake (ADI)'), findsOneWidget);
    expect(find.text('Verified Official Citation'), findsOneWidget);
    expect(find.textContaining('Joint FAO/WHO Expert Committee on Food Additives'), findsOneWidget);

    // Scroll to "Got It" button to dismiss
    final gotItFinder = find.text('Got It');
    await tester.ensureVisible(gotItFinder);
    await tester.tap(gotItFinder);
    await tester.pumpAndSettle();
    expect(find.byType(IngredientDeepDiveSheet), findsNothing);
  });

  testWidgets('VerdictReportScreen tapping Ask AI CTA navigates to AdvisorChatScreen with product context', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VerdictReportScreen(
          product: testSafeProduct,
          userProfile: testProfile,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final askAIFinder = find.text('Ask AI About This Product');
    await tester.ensureVisible(askAIFinder);
    await tester.tap(askAIFinder);
    await tester.pumpAndSettle();

    expect(find.byType(AdvisorChatScreen), findsOneWidget);
    expect(find.textContaining('100% Whole Grain Rolled Oats'), findsAtLeastNWidgets(1));
  });
}
