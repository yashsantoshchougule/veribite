import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/camera/presentation/smart_camera_screen.dart';
import 'package:mobile_app/features/home/presentation/home_screen.dart';
import 'package:mobile_app/features/profile/application/user_profile_service.dart';
import 'package:mobile_app/features/profile/domain/user_profile_model.dart';
import 'package:mobile_app/features/profile/presentation/user_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableHomeScreen({String userId = 'test_home_user'}) {
    return ProviderScope(
      child: MaterialApp(
        home: HomeScreen(userId: userId),
      ),
    );
  }

  group('HomeScreen Visual & Component Tests', () {
    testWidgets('renders header, hero scan card, budget meter, recent scans, and 5 tabs', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      // Top Header
      expect(find.text('VeriBite Dashboard'), findsOneWidget);
      expect(find.textContaining('65 kg Adult'), findsOneWidget);
      expect(find.text('Profile'), findsNWidgets(2)); // Header pill + Bottom nav

      // Hero Scan Card
      expect(find.text('3-TIER OPTICAL SCANNER'), findsOneWidget);
      expect(find.text('Point & Scan Backside Label'), findsOneWidget);
      expect(find.text('Open Smart Camera'), findsOneWidget);

      // Daily Consumption Budget Meter
      expect(find.text('Daily Consumption Budget'), findsOneWidget);
      expect(find.text('WHO Safe'), findsOneWidget);
      expect(find.textContaining('Free Sugar Ceiling'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Recent Scans Carousel
      expect(find.text('Recent Scans'), findsOneWidget);
      expect(find.text('Britannia Bourbon'), findsOneWidget);
      expect(find.text('Real Mixed Fruit'), findsOneWidget);

      // Quick Health Actions
      expect(find.text('Quick Health Actions'), findsOneWidget);
      expect(find.text('INS Decoder'), findsOneWidget);
      expect(find.text('Barcode Lookup'), findsOneWidget);
      expect(find.text('Child Guard'), findsOneWidget);
      expect(find.text('Blinkit Swaps'), findsOneWidget);

      // 5-Tab Persistent Bottom Navigation Bar
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Advisor'), findsOneWidget);
      expect(find.text('Profile'), findsNWidgets(2)); // Header pill + Bottom nav
    });

    testWidgets('loads custom user biometrics and guardrails into header', (tester) async {
      final service = UserProfileService();
      await service.saveProfile(
        UserProfileModel(
          userId: 'custom_diabetic_user',
          weightKg: 82.0,
          isChild: false,
          isDiabetic: true,
          isCompleted: true,
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(buildTestableHomeScreen(userId: 'custom_diabetic_user'));
      await tester.pumpAndSettle();

      expect(find.textContaining('82 kg Adult • Diabetic Guard Active'), findsOneWidget);
    });
  });

  group('HomeScreen Interactive Navigation Tests', () {
    testWidgets('tapping Open Smart Camera on Hero card navigates to SmartCameraScreen', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      final heroBtn = find.text('Open Smart Camera');
      expect(heroBtn, findsOneWidget);
      await tester.tap(heroBtn);
      await tester.pumpAndSettle();

      expect(find.byType(SmartCameraScreen), findsOneWidget);
    });

    testWidgets('tapping center Scan FAB on Bottom Nav navigates to SmartCameraScreen', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      final scanTab = find.byIcon(Icons.qr_code_scanner_rounded).last;
      await tester.tap(scanTab);
      await tester.pumpAndSettle();

      expect(find.byType(SmartCameraScreen), findsOneWidget);
    });

    testWidgets('tapping Profile on Top Header navigates to UserDetailsScreen', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      final profilePill = find.byIcon(Icons.tune_rounded);
      await tester.tap(profilePill);
      await tester.pumpAndSettle();

      expect(find.byType(UserDetailsScreen), findsOneWidget);
    });
  });

  group('HomeScreen Cross-Device Responsive Layout Tests', () {
    testWidgets('renders cleanly on Small Compact Phone (320x568) without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Point & Scan Backside Label'), findsOneWidget);
    });

    testWidgets('renders cleanly on Standard Phone (390x844) without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Point & Scan Backside Label'), findsOneWidget);
    });

    testWidgets('renders cleanly on moto g85 5G (412x915) without overflow', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Point & Scan Backside Label'), findsOneWidget);
    });

    testWidgets('renders cleanly on Tablet / iPad (768x1024) with centered content constraints', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Point & Scan Backside Label'), findsOneWidget);
    });
  });
}
