import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/advisor/presentation/advisor_chat_screen.dart';
import 'package:mobile_app/features/camera/application/product_scanner_service.dart';
import 'package:mobile_app/features/profile/domain/user_profile_model.dart';
import 'package:mobile_app/features/results/presentation/ingredient_breakdown_screen.dart';
import 'package:mobile_app/features/results/presentation/verdict_report_screen.dart';
import 'package:mobile_app/features/results/presentation/widgets/circular_score_gauge.dart';
import 'package:mobile_app/features/results/presentation/widgets/ingredient_deep_dive_sheet.dart';
import 'package:mobile_app/features/swaps/presentation/healthier_swaps_screen.dart';

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

  testWidgets('VerdictReportScreen renders real sat fat and sodium, and computes dynamic pack weight multiplier', (tester) async {
    const customPackProduct = ScannedProductResult(
      barcode: '8901234567890',
      productName: 'Nutri Crisp Bar',
      brandName: 'HealthyBites',
      category: 'Snack Bar',
      servingSizeG: 25.0,
      packWeightG: 50.0, // Exactly 2 servings (2.0x multiplier)
      sugarGPer100g: 8.0,
      sugarGPerServing: 2.0,
      satFatGPer100g: 11.2,
      satFatGPerServing: 2.8,
      sodiumMgPer100g: 280.0,
      sodiumMgPerServing: 70.0,
      caloriesPerServing: 110.0,
      healthScore: 78,
      verdictTag: 'Nutri Safe 🟢',
      novaGrade: 2,
      redCapTriggered: false,
      safePortionGrams: 25,
      safePieces: null,
      limitingFactor: 'Sugar',
      frequencySchedule: 'Daily Safe',
      additives: [],
      splitSugars: [],
      portionAdvice: 'Safe consumption portion: 25g.',
      isExceededBudget: false,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: VerdictReportScreen(
          product: customPackProduct,
          userProfile: testProfile,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify 1-serving real values
    expect(find.text('Whole Pack (50g)'), findsOneWidget);
    expect(find.text('2.8'), findsOneWidget); // Real Sat Fat
    expect(find.text('70'), findsOneWidget); // Real Sodium

    // Switch to Whole Pack (2.0x multiplier, NOT hardcoded 3.0x)
    await tester.tap(find.text('Whole Pack (50g)'));
    await tester.pumpAndSettle();

    expect(find.text('220'), findsOneWidget); // 110 * 2 = 220 kcal
    expect(find.text('4.0'), findsOneWidget); // 2.0 * 2 = 4.0 g sugar
    expect(find.text('5.6'), findsOneWidget); // 2.8 * 2 = 5.6 g Sat Fat
    expect(find.text('140'), findsOneWidget); // 70 * 2 = 140 mg Sodium
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

  testWidgets('VerdictReportScreen tapping Smart Healthier Clean Swaps navigates to HealthierSwapsScreen', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VerdictReportScreen(
          product: testRedCappedProduct,
          userProfile: testProfile,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final swapsCTAFinder = find.text('Smart Healthier Clean Swaps');
    await tester.ensureVisible(swapsCTAFinder);
    await tester.tap(swapsCTAFinder);
    await tester.pumpAndSettle();

    expect(find.byType(HealthierSwapsScreen), findsOneWidget);
    expect(find.textContaining('Instant Noodles • Verified Alternatives'), findsOneWidget);
  });

  testWidgets('VerdictReportScreen renders Doctor & Dietitian Health Report (PDF) card and top bar icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: VerdictReportScreen(
          product: testRedCappedProduct,
          userProfile: testProfile,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Top Bar PDF button
    final topBarPdfBtn = find.byTooltip('Export Medical PDF Report');
    expect(topBarPdfBtn, findsOneWidget);

    // Verify Medical PDF Export Card in body
    final pdfCard = find.text('Doctor & Dietitian Health Report (PDF)');
    expect(pdfCard, findsOneWidget);
    await tester.ensureVisible(pdfCard);
    expect(find.textContaining('1-Tap printable dossier with complete toxicology & safe limits'), findsOneWidget);
    expect(find.text('Export'), findsOneWidget);

    // Tap Export button to verify modal bottom sheet triggers
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();

    expect(find.text('Clinical Health Report (PDF)'), findsOneWidget);
    expect(find.text('Share PDF'), findsOneWidget);
    expect(find.text('Print / Save'), findsOneWidget);
  });
}
