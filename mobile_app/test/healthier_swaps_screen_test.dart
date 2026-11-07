import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/camera/application/product_scanner_service.dart';
import 'package:mobile_app/features/swaps/presentation/healthier_swaps_screen.dart';
import 'package:mobile_app/features/swaps/presentation/widgets/swap_alternative_card.dart';

void main() {
  const testScannedProduct = ScannedProductResult(
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
    limitingFactor: 'Sodium',
    frequencySchedule: 'Strict 1–2x/Week',
    additives: [
      {'ins_code': '635', 'primary_name': 'Disodium 5-Ribonucleotides', 'risk_tier': 'RED'},
    ],
    splitSugars: [],
    portionAdvice: 'Safe portion 25g',
    isExceededBudget: false,
  );

  testWidgets('HealthierSwapsScreen renders current product warning and clean alternatives list', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HealthierSwapsScreen(
          currentProduct: testScannedProduct,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Top Bar
    expect(find.text('Smart Healthier Swaps'), findsOneWidget);
    expect(find.textContaining('Instant Noodles • Verified Alternatives'), findsOneWidget);
    expect(find.text('Clean Label'), findsOneWidget);

    // Current Product Warning Banner
    expect(find.textContaining('Currently Scanned: 2-Minute Masala Noodles'), findsOneWidget);
    expect(find.text('Score: 32/100'), findsOneWidget);
    expect(find.textContaining('High risk profile detected due to sodium constraints'), findsOneWidget);

    // Cleaner Alternatives List
    expect(find.byType(SwapAlternativeCard), findsAtLeastNWidgets(1));
    expect(find.text('Foxtail & Little Millet Noodles'), findsOneWidget);
    expect(find.text('Slurrp Farm • Instant Noodles'), findsOneWidget);
    expect(find.text('+46 PTS'), findsOneWidget);

    // Scroll down to build and reveal second alternative
    await tester.drag(find.byType(ListView), const Offset(0, -350));
    await tester.pumpAndSettle();

    expect(find.text('Whole Wheat Hakka Noodles'), findsOneWidget);
    expect(find.text('+42 PTS'), findsOneWidget);

    // Quick Commerce Buttons
    expect(find.text('Blinkit'), findsAtLeastNWidgets(1));
    expect(find.text('Zepto'), findsAtLeastNWidgets(1));
    expect(find.text('Instamart'), findsAtLeastNWidgets(1));
    expect(find.text('BigBasket'), findsAtLeastNWidgets(1));
  });

  testWidgets('tapping SwapAlternativeCard opens Side-by-Side Health Comparison sheet', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HealthierSwapsScreen(
          currentProduct: testScannedProduct,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap first alternative card
    await tester.tap(find.text('Foxtail & Little Millet Noodles'));
    await tester.pumpAndSettle();

    // Verify comparison bottom sheet appeared
    expect(find.text('Side-by-Side Health Comparison'), findsOneWidget);
    expect(find.text('Health Score'), findsOneWidget);
    expect(find.text('32/100'), findsOneWidget);
    expect(find.textContaining('78/100 (+46)'), findsOneWidget);
    expect(find.text('Back to Swaps'), findsOneWidget);

    // Dismiss sheet
    await tester.tap(find.text('Back to Swaps'));
    await tester.pumpAndSettle();

    expect(find.text('Side-by-Side Health Comparison'), findsNothing);
  });

  testWidgets('HealthierSwapsScreen renders smoothly when opened in category mode without scanned product', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HealthierSwapsScreen(
          category: 'Biscuits & Cookies',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Smart Healthier Swaps'), findsOneWidget);
    expect(find.textContaining('Biscuits & Cookies • Verified Alternatives'), findsOneWidget);

    // Alternative cards rendered
    expect(find.byType(SwapAlternativeCard), findsNWidgets(2));
    expect(find.text('Whole Oatmeal & Almond Cookies'), findsOneWidget);
    expect(find.text('Organic Multi-Grain Jaggery Cookies'), findsOneWidget);
  });
}
