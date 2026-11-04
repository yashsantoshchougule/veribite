import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/camera/presentation/smart_camera_screen.dart';
import 'package:mobile_app/features/home/application/home_dashboard_service.dart';
import 'package:mobile_app/features/home/domain/home_dashboard_data.dart';
import 'package:mobile_app/features/home/presentation/home_screen.dart';
import 'package:mobile_app/features/profile/application/user_profile_service.dart';
import 'package:mobile_app/features/profile/domain/user_profile_model.dart';
import 'package:mobile_app/features/profile/presentation/profile_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockHomeDashboardService extends HomeDashboardService {
  HomeDashboardData? stubData;

  MockHomeDashboardService({this.stubData});

  @override
  Future<HomeDashboardData> getDashboardData(String userId, UserProfileModel profile) async {
    if (stubData != null) return stubData!;
    final maxSugar = calculateMaxSugar(profile);
    return HomeDashboardData(
      consumedSugarGrams: 4.2,
      maxSugarGrams: maxSugar,
      redAdditivesToday: 0,
      recentProducts: const [
        DashboardProductItem(
          barcode: '8901030383786',
          productName: 'Orange Cream Biscuits',
          brandName: 'Britannia Treat',
          healthScore: 22,
          verdictTag: 'Capped 🔴',
          safePortion: '20g',
          color: AppColors.safetyRed,
        ),
        DashboardProductItem(
          barcode: '8901234567890',
          productName: '100% Wholegrain Rolled Oats',
          brandName: 'Quaker',
          healthScore: 88,
          verdictTag: 'Nutri Safe 🟢',
          safePortion: '40g',
          color: AppColors.safetyGreen,
        ),
      ],
      isUserHistory: true,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildTestableHomeScreen({
    String userId = 'test_home_user',
    HomeDashboardService? dashboardService,
    UserProfileService? profileService,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: HomeScreen(
          userId: userId,
          dashboardService: dashboardService ?? MockHomeDashboardService(),
          profileService: profileService,
        ),
      ),
    );
  }

  group('HomeScreen Visual & Database-Driven Component Tests', () {
    testWidgets('renders header, hero scan card, live budget meter, and recent scans from database', (tester) async {
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

      // Live Daily Consumption Budget Meter
      expect(find.text('Daily Consumption Budget'), findsOneWidget);
      expect(find.text('WHO Safe'), findsOneWidget);
      expect(find.textContaining('Free Sugar Ceiling'), findsOneWidget);
      expect(find.textContaining('4.2g / 25g (17%)'), findsOneWidget);
      expect(find.textContaining('0 Red-tier chemical additives consumed today. All safe.'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Database-driven Recent Scans Carousel
      expect(find.text('Recent Scans'), findsOneWidget);
      expect(find.text('Orange Cream Biscuits'), findsOneWidget);
      expect(find.text('100% Wholegrain Rolled Oats'), findsOneWidget);
      expect(find.text('Portion: 20g'), findsOneWidget);
      expect(find.text('22/100'), findsOneWidget);
      expect(find.text('88/100'), findsOneWidget);

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
    });

    testWidgets('renders Featured Database Products header when user has 0 personal scans', (tester) async {
      final mock = MockHomeDashboardService(
        stubData: const HomeDashboardData(
          consumedSugarGrams: 0.0,
          maxSugarGrams: 25.0,
          redAdditivesToday: 0,
          recentProducts: [
            DashboardProductItem(
              barcode: '8901764012234',
              productName: 'Classic Sparkling Cola',
              brandName: 'Thums Up',
              healthScore: 18,
              verdictTag: 'Capped 🔴',
              safePortion: '250 ml',
              color: AppColors.safetyRed,
            ),
          ],
          isUserHistory: false, // Featured products mode
        ),
      );

      await tester.pumpWidget(buildTestableHomeScreen(dashboardService: mock));
      await tester.pumpAndSettle();

      expect(find.text('Featured Database Products'), findsOneWidget);
      expect(find.text('Scan Product +'), findsOneWidget);
      expect(find.text('Classic Sparkling Cola'), findsOneWidget);
      expect(find.text('0.0g / 25g (0%)'), findsOneWidget);
    });

    testWidgets('displays Exceeded badge and red additives warning when threshold is passed', (tester) async {
      final mock = MockHomeDashboardService(
        stubData: const HomeDashboardData(
          consumedSugarGrams: 28.5,
          maxSugarGrams: 25.0,
          redAdditivesToday: 2,
          recentProducts: [],
          isUserHistory: true,
        ),
      );

      await tester.pumpWidget(buildTestableHomeScreen(dashboardService: mock));
      await tester.pumpAndSettle();

      expect(find.text('Exceeded ⚠️'), findsOneWidget);
      expect(find.textContaining('28.5g / 25g (114%)'), findsOneWidget);
      expect(find.textContaining('⚠️ 2 Red-tier chemical additive(s) consumed today!'), findsOneWidget);
      expect(find.text('Database Ready'), findsOneWidget);
    });

    testWidgets('loads custom user biometrics and guardrails into header and recalculates budget', (tester) async {
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

      final mock = MockHomeDashboardService(
        stubData: const HomeDashboardData(
          consumedSugarGrams: 3.0,
          maxSugarGrams: 10.0, // Diabetic safe limit
          redAdditivesToday: 0,
          recentProducts: [],
          isUserHistory: true,
        ),
      );

      await tester.pumpWidget(
        buildTestableHomeScreen(
          userId: 'custom_diabetic_user',
          dashboardService: mock,
          profileService: service,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('82 kg Adult • Diabetic Guard Active'), findsOneWidget);
      expect(find.textContaining('3.0g / 10g (30%)'), findsOneWidget);
    });

    testWidgets('tapping product card displays snackbar notification with health score', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      final biscuitCard = find.text('Orange Cream Biscuits');
      expect(biscuitCard, findsOneWidget);
      await tester.ensureVisible(biscuitCard);
      await tester.pumpAndSettle();

      await tester.tap(biscuitCard);
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('Orange Cream Biscuits • Health Score: 22/100'), findsOneWidget);
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

    testWidgets('tapping Profile on Top Header navigates to ProfileScreen', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      final profilePill = find.byIcon(Icons.tune_rounded);
      await tester.tap(profilePill);
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
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
