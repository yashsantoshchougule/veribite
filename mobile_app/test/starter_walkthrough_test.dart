import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/onboarding/domain/walkthrough_step.dart';
import 'package:mobile_app/features/onboarding/presentation/starter_walkthrough_screen.dart';

void main() {
  group('AppColors Warm Luxury Palette', () {
    test('defines required luxury editorial palette tokens', () {
      expect(AppColors.canvasCream, const Color(0xFFFBF8F4));
      expect(AppColors.cardSurface, const Color(0xFFFDFBF7));
      expect(AppColors.textObsidian, const Color(0xFF0E1424));
      expect(AppColors.textMutedMocha, const Color(0xFF59524A));
      expect(AppColors.accentBronze, const Color(0xFF8C7A6B));
      expect(AppColors.primaryObsidian, const Color(0xFF0E1424));
      expect(AppColors.safetyRed, const Color(0xFFBA1A1A));
      expect(AppColors.safetyMint, const Color(0xFF137333));
    });
  });

  group('WalkthroughStep Domain Model', () {
    test('provides all 4 predefined walkthrough steps matching screenshots', () {
      final steps = WalkthroughStep.defaultSteps;
      expect(steps.length, 4);
      expect(steps[0].title, 'Point & Scan Any Food Packet');
      expect(steps[1].title, 'Unmask Hidden Sugars & Toxins');
      expect(steps[2].title, 'Personalized Safe Dosage Math');
      expect(steps[3].title, 'Healthier Swaps & Setup');
    });
  });

  group('StarterWalkthroughScreen Navigation & Interaction', () {
    testWidgets('renders Step 1 and navigates sequentially via Next button', (tester) async {
      bool completed = false;

      await tester.pumpWidget(
        MaterialApp(
          home: StarterWalkthroughScreen(
            onFinish: () => completed = true,
          ),
        ),
      );

      // Verify Step 1 elements
      expect(find.text('Point & Scan Any Food Packet'), findsOneWidget);
      expect(find.text('STEP 1 OF 4'), findsOneWidget);
      expect(find.text('Offline Ready • < 20ms'), findsOneWidget);
      expect(find.text('Next Step →'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Tap Next Step -> Should show Step 2
      await tester.tap(find.text('Next Step →'));
      await tester.pumpAndSettle();

      expect(find.text('Unmask Hidden Sugars & Toxins'), findsOneWidget);
      expect(find.text('STEP 2 OF 4'), findsOneWidget);
      expect(find.text('39/100 Hard Red Cap Triggered'), findsOneWidget);
      expect(find.text('← Back'), findsOneWidget);

      // Tap Next Step -> Should show Step 3
      await tester.tap(find.text('Next Step →'));
      await tester.pumpAndSettle();

      expect(find.text('Personalized Safe Dosage Math'), findsOneWidget);
      expect(find.text('STEP 3 OF 4'), findsOneWidget);
      expect(find.text('16 Grams (1 Piece)'), findsOneWidget);

      // Tap Next Step -> Should show Step 4
      await tester.tap(find.text('Next Step →'));
      await tester.pumpAndSettle();

      expect(find.text('Healthier Swaps & Setup'), findsOneWidget);
      expect(find.text('STEP 4 OF 4'), findsOneWidget);
      expect(find.text('Get Started & Sign In →'), findsOneWidget);
      // Back button should still be available on Step 4
      expect(find.text('← Back'), findsOneWidget);

      // Tap Get Started
      await tester.tap(find.text('Get Started & Sign In →'));
      await tester.pumpAndSettle();

      expect(completed, isTrue);
    });

    testWidgets('Skip button jumps directly to Step 4', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StarterWalkthroughScreen(),
        ),
      );

      expect(find.text('Point & Scan Any Food Packet'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Tap Skip
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Now at Step 4
      expect(find.text('Healthier Swaps & Setup'), findsOneWidget);
      expect(find.text('STEP 4 OF 4'), findsOneWidget);
      expect(find.text('Get Started & Sign In →'), findsOneWidget);
    });

    testWidgets('Back button returns to previous step', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: StarterWalkthroughScreen(),
        ),
      );

      // Move to Step 2
      await tester.tap(find.text('Next Step →'));
      await tester.pumpAndSettle();
      expect(find.text('Unmask Hidden Sugars & Toxins'), findsOneWidget);

      // Tap Back -> Returns to Step 1
      await tester.tap(find.text('← Back'));
      await tester.pumpAndSettle();
      expect(find.text('Point & Scan Any Food Packet'), findsOneWidget);
    });
  });
}
