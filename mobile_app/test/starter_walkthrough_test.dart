import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/onboarding/domain/walkthrough_step.dart';
import 'package:mobile_app/features/onboarding/presentation/starter_walkthrough_screen.dart';

void main() {
  group('AppColors Purple Theme Palette', () {
    test('defines required Material 3 purple palette tokens', () {
      expect(AppColors.primaryPurple, const Color(0xFF6750A4));
      expect(AppColors.darkPurple, const Color(0xFF381E72));
      expect(AppColors.lightPurple, const Color(0xFFEADDFF));
      expect(AppColors.surfaceLavender, const Color(0xFFF7F2FA));
      expect(AppColors.textDark, const Color(0xFF1D192B));
      expect(AppColors.accentViolet, const Color(0xFF845EC2));
      expect(AppColors.safetyRed, const Color(0xFFBA1A1A));
      expect(AppColors.safetyMint, const Color(0xFF146C2E));
    });
  });

  group('WalkthroughStep Domain Model', () {
    test('provides all 4 predefined walkthrough steps', () {
      final steps = WalkthroughStep.defaultSteps;
      expect(steps.length, 4);
      expect(steps[0].title, contains('Point & Scan'));
      expect(steps[1].title, contains('Unmask Hidden Sugars'));
      expect(steps[2].title, contains('Personalized Safe Dosage'));
      expect(steps[3].title, contains('Healthier Swaps'));
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

      // Verify Step 1 is visible
      expect(find.textContaining('Point & Scan'), findsOneWidget);
      expect(find.text('Next Step →'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Tap Next Step -> Should show Step 2
      await tester.tap(find.text('Next Step →'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Unmask Hidden Sugars'), findsOneWidget);
      expect(find.text('← Back'), findsOneWidget);

      // Tap Next Step -> Should show Step 3
      await tester.tap(find.text('Next Step →'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Personalized Safe Dosage'), findsOneWidget);

      // Tap Next Step -> Should show Step 4
      await tester.tap(find.text('Next Step →'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Healthier Swaps'), findsOneWidget);
      expect(find.text('Get Started & Sign In →'), findsOneWidget);

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

      expect(find.textContaining('Point & Scan'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);

      // Tap Skip
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Now at Step 4
      expect(find.textContaining('Healthier Swaps'), findsOneWidget);
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
      expect(find.textContaining('Unmask Hidden Sugars'), findsOneWidget);

      // Tap Back -> Returns to Step 1
      await tester.tap(find.text('← Back'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Point & Scan'), findsOneWidget);
    });
  });
}
