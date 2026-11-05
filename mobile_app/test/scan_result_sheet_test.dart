import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/camera/application/product_scanner_service.dart';
import 'package:mobile_app/features/camera/presentation/widgets/scan_result_sheet.dart';

void main() {
  const safeProduct = ScannedProductResult(
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
    limitingFactor: 'Sugar',
    frequencySchedule: 'Daily Safe',
    additives: [],
    splitSugars: [],
    portionAdvice: 'Safe consumption portion: 40 g (max 1.0 serving). Limiting constraint: Sugar.',
    isExceededBudget: false,
  );

  const toxicProduct = ScannedProductResult(
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
    safePortionGrams: 30,
    limitingFactor: 'Sodium',
    frequencySchedule: 'Strictly Avoid',
    additives: [
      {'ins_code': '635', 'primary_name': 'Disodium 5-Ribonucleotides', 'risk_tier': 'RED', 'triggers_red_cap': 1},
    ],
    splitSugars: ['Invert Sugar Syrup'],
    portionAdvice: 'Safe consumption portion: 30 g (max 0.4 serving). Limiting constraint: Sodium.',
    isExceededBudget: true,
  );

  Widget buildTestableSheet({
    required ScannedProductResult product,
    VoidCallback? onLogConsumed,
    VoidCallback? onDismissWithoutLog,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ScanResultSheet(
          product: product,
          onLogConsumed: onLogConsumed ?? () {},
          onDismissWithoutLog: onDismissWithoutLog ?? () {},
        ),
      ),
    );
  }

  group('ScanResultSheet Component & Interaction Tests', () {
    testWidgets('renders Nutri Safe product details, score, prescription, and action buttons', (tester) async {
      bool logged = false;
      bool dismissed = false;

      await tester.pumpWidget(
        buildTestableSheet(
          product: safeProduct,
          onLogConsumed: () => logged = true,
          onDismissWithoutLog: () => dismissed = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('100% Whole Grain Rolled Oats'), findsOneWidget);
      expect(find.text('Quaker • Breakfast Cereals'), findsOneWidget);
      expect(find.text('88'), findsOneWidget);
      expect(find.text('Safe Portion Prescription'), findsOneWidget);
      expect(find.text('Frequency: Daily Safe'), findsOneWidget);
      expect(find.text('NOVA 1'), findsOneWidget);

      // Verify buttons
      final logButton = find.text('I Ate This (Add to Today\'s Sugar Budget)');
      final checkButton = find.text('Just Checking (Don\'t Add to Budget)');
      expect(logButton, findsOneWidget);
      expect(checkButton, findsOneWidget);

      // Tap Log
      await tester.tap(logButton);
      expect(logged, isTrue);

      // Tap Dismiss
      await tester.tap(checkButton);
      expect(dismissed, isTrue);
    });

    testWidgets('renders Toxic / Capped product with Red-tier additive warnings & split sugars', (tester) async {
      await tester.pumpWidget(buildTestableSheet(product: toxicProduct));
      await tester.pumpAndSettle();

      expect(find.text('2-Minute Masala Noodles'), findsOneWidget);
      expect(find.text('32'), findsOneWidget);
      expect(find.textContaining('exceeds your safe daily ceiling!'), findsOneWidget);
      expect(find.text('Hidden Split Sugar Aliases Detected'), findsOneWidget);
      expect(find.text('Invert Sugar Syrup'), findsOneWidget);
      expect(find.text('Declared Chemical Additives (INS / E-numbers)'), findsOneWidget);
      expect(find.text('INS 635: Disodium 5-Ribonucleotides'), findsOneWidget);
    });
  });

  group('ScanResultSheet Responsive Tests', () {
    testWidgets('renders cleanly on Small Compact Phone (320x568) without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableSheet(product: toxicProduct));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('2-Minute Masala Noodles'), findsOneWidget);
    });

    testWidgets('renders cleanly on Standard Phone (390x844) without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableSheet(product: safeProduct));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('100% Whole Grain Rolled Oats'), findsOneWidget);
    });

    testWidgets('renders cleanly on Tablet (768x1024) without overflow', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableSheet(product: safeProduct));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('100% Whole Grain Rolled Oats'), findsOneWidget);
    });
  });
}
