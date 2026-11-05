import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/legal/presentation/legal_policy_screen.dart';

void main() {
  Widget buildTestableScreen({LegalTab initialTab = LegalTab.terms}) {
    return MaterialApp(
      home: LegalPolicyScreen(initialTab: initialTab),
    );
  }

  group('LegalPolicyScreen UI & Tab Switching Tests', () {
    testWidgets('renders top bar, title, and default Terms & Conditions tab', (tester) async {
      await tester.pumpWidget(buildTestableScreen(initialTab: LegalTab.terms));
      await tester.pumpAndSettle();

      // Top bar header
      expect(find.text('Legal & Policies'), findsOneWidget);
      expect(find.text('VeriBite Standards • Effective Nov 2026'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

      // Segmented Tabs
      expect(find.text('Terms & Conditions'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);

      // Terms content
      expect(find.text('VeriBite Terms of Service'), findsOneWidget);
      expect(find.text('CRITICAL MEDICAL & NUTRITIONAL DISCLAIMER'), findsOneWidget);
      expect(find.text('1. Acceptance & Educational Scope'), findsOneWidget);
      expect(find.text('2. Safe Consumption Ceilings & Guardrails'), findsOneWidget);
      expect(find.text('3. Formulation Updates & Allergen Limitations'), findsOneWidget);
    });

    testWidgets('tapping Privacy Policy switches tab and displays privacy content', (tester) async {
      await tester.pumpWidget(buildTestableScreen(initialTab: LegalTab.terms));
      await tester.pumpAndSettle();

      // Tap Privacy Policy tab
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      // Privacy content
      expect(find.text('VeriBite Privacy Policy'), findsOneWidget);
      expect(find.text('OUR ZERO-TRACKING & ZERO-AD PLEDGE'), findsOneWidget);
      expect(find.text('1. Information We Collect & Why'), findsOneWidget);
      expect(find.text('2. Camera Permissions & Optical Processing'), findsOneWidget);
      expect(find.text('4. Your Rights & Data Ownership (DPDP Act / GDPR)'), findsOneWidget);

      // Tap back to Terms
      await tester.tap(find.text('Terms & Conditions'));
      await tester.pumpAndSettle();

      expect(find.text('VeriBite Terms of Service'), findsOneWidget);
    });

    testWidgets('opening with initialTab: LegalTab.privacy renders Privacy directly', (tester) async {
      await tester.pumpWidget(buildTestableScreen(initialTab: LegalTab.privacy));
      await tester.pumpAndSettle();

      expect(find.text('VeriBite Privacy Policy'), findsOneWidget);
      expect(find.text('OUR ZERO-TRACKING & ZERO-AD PLEDGE'), findsOneWidget);
    });

    testWidgets('quick-jump chips can be tapped smoothly without exceptions', (tester) async {
      await tester.pumpWidget(buildTestableScreen(initialTab: LegalTab.terms));
      await tester.pumpAndSettle();

      // Tap Safe Ceilings quick chip
      final ceilingsChip = find.text('Safe Ceilings');
      expect(ceilingsChip, findsOneWidget);
      await tester.tap(ceilingsChip);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Switch to privacy tab
      await tester.tap(find.text('Privacy Policy'));
      await tester.pumpAndSettle();

      // Tap Camera & OCR quick chip
      final cameraChip = find.text('Camera & OCR');
      expect(cameraChip, findsOneWidget);
      await tester.tap(cameraChip);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('back button triggers Navigator.pop', (tester) async {
      bool popped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const LegalPolicyScreen(),
                  ),
                ).then((_) => popped = true);
              },
              child: const Text('Open Legal'),
            ),
          ),
        ),
      );

      // Open screen
      await tester.tap(find.text('Open Legal'));
      await tester.pumpAndSettle();
      expect(find.byType(LegalPolicyScreen), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(find.byType(LegalPolicyScreen), findsNothing);
    });
  });

  group('Responsive Layout Tests across Device Sizes', () {
    testWidgets('renders cleanly on Small Compact Phone (320x568) without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableScreen(initialTab: LegalTab.terms));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Legal & Policies'), findsOneWidget);
      expect(find.text('VeriBite Terms of Service'), findsOneWidget);
    });

    testWidgets('renders cleanly on Standard Phone (390x844) without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableScreen(initialTab: LegalTab.terms));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('VeriBite Terms of Service'), findsOneWidget);
    });

    testWidgets('renders cleanly on moto g85 5G (412x915) without overflow', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableScreen(initialTab: LegalTab.privacy));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('VeriBite Privacy Policy'), findsOneWidget);
    });

    testWidgets('renders cleanly on Tablet (768x1024) with centered max-width constraints', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableScreen(initialTab: LegalTab.terms));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('VeriBite Terms of Service'), findsOneWidget);
    });
  });
}
