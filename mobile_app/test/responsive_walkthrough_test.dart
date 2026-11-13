import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/onboarding/presentation/starter_walkthrough_screen.dart';

void main() {
  group('Responsive Walkthrough Multi-Screen Tests', () {
    testWidgets('renders cleanly on Small Compact Phone (320x568) without overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StarterWalkthroughScreen(),
        ),
      );

      // Verify no RenderFlex exception occurred
      expect(tester.takeException(), isNull);
      expect(find.textContaining('Point & Scan'), findsOneWidget);
      expect(find.text('Next Step →'), findsOneWidget);
    });

    testWidgets('renders cleanly on iPhone SE (375x667) without overflow', (tester) async {
      tester.view.physicalSize = const Size(375 * 2.0, 667 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StarterWalkthroughScreen(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Point & Scan'), findsOneWidget);

      // Step through all 4 screens on iPhone SE to verify zero overflow on all steps
      for (int i = 0; i < 3; i++) {
        await tester.tap(find.text('Next Step →'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Get Started & Sign In →'), findsOneWidget);
    });

    testWidgets('renders cleanly on Samsung Galaxy (412x915) without overflow', (tester) async {
      tester.view.physicalSize = const Size(412 * 2.5, 915 * 2.5);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StarterWalkthroughScreen(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Point & Scan'), findsOneWidget);
    });

    testWidgets('renders cleanly on Tablet (768x1024) with centered content', (tester) async {
      tester.view.physicalSize = const Size(768 * 2.0, 1024 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: StarterWalkthroughScreen(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Point & Scan'), findsOneWidget);
    });
  });
}
