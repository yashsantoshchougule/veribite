import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/advisor/presentation/advisor_chat_screen.dart';
import 'package:mobile_app/features/camera/application/product_scanner_service.dart';
import 'package:mobile_app/features/camera/presentation/smart_camera_screen.dart';
import 'package:mobile_app/features/home/application/home_dashboard_service.dart';
import 'package:mobile_app/features/home/domain/home_dashboard_data.dart';
import 'package:mobile_app/features/home/application/daily_consumption_tracker.dart';
import 'package:mobile_app/features/home/presentation/home_screen.dart';
import 'package:mobile_app/features/profile/application/user_profile_manager.dart';
import 'package:mobile_app/features/profile/application/user_profile_service.dart';
import 'package:mobile_app/features/profile/domain/user_profile_model.dart';
import 'package:mobile_app/features/profile/presentation/profile_screen.dart';
import 'package:mobile_app/features/results/presentation/verdict_report_screen.dart';
import 'package:mobile_app/features/swaps/presentation/healthier_swaps_screen.dart';
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
      recentProducts: HomeDashboardData.defaultFeaturedProducts,
      isUserHistory: true,
    );
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserProfileManager.instance.resetForTesting();
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

    testWidgets('tapping featured product card pushes VerdictReportScreen with accurate macros and NO placeholder snackbar', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      final biscuitCard = find.text('Orange Cream Biscuits');
      expect(biscuitCard, findsOneWidget);
      await tester.ensureVisible(biscuitCard);
      await tester.pumpAndSettle();

      await tester.tap(biscuitCard);
      await tester.pumpAndSettle();

      // Confirm NO SnackBar was shown
      expect(find.byType(SnackBar), findsNothing);

      // Confirm VerdictReportScreen was pushed
      expect(find.byType(VerdictReportScreen), findsOneWidget);
      expect(find.text('Orange Cream Biscuits'), findsAtLeastNWidgets(1));
      expect(find.textContaining('22'), findsAtLeastNWidgets(1));

      // Pop back to dashboard
      Navigator.of(tester.element(find.byType(VerdictReportScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(VerdictReportScreen), findsNothing);
    });

    testWidgets('rapidly double-tapping featured product card pushes VerdictReportScreen only once', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      final biscuitCard = find.text('Orange Cream Biscuits');
      expect(biscuitCard, findsOneWidget);
      await tester.ensureVisible(biscuitCard);
      await tester.pumpAndSettle();

      // Rapid double tap
      await tester.tap(biscuitCard);
      await tester.tap(biscuitCard, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Exactly ONE VerdictReportScreen pushed
      expect(find.byType(VerdictReportScreen), findsOneWidget);

      // Popping once returns directly to HomeScreen
      Navigator.of(tester.element(find.byType(VerdictReportScreen))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(VerdictReportScreen), findsNothing);
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

    testWidgets('tapping Advisor tab on Bottom Nav navigates to AdvisorChatScreen', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      final advisorTab = find.byIcon(Icons.auto_awesome_outlined);
      await tester.tap(advisorTab);
      await tester.pumpAndSettle();

      expect(find.byType(AdvisorChatScreen), findsOneWidget);
      expect(find.text('VeriBite AI Advisor'), findsAtLeastNWidgets(1));
    });

    testWidgets('tapping Profile on Top Header navigates to ProfileScreen', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      final profilePill = find.byIcon(Icons.tune_rounded);
      await tester.tap(profilePill);
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('tapping Blinkit Swaps action tile navigates to HealthierSwapsScreen', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      final swapsTile = find.text('Blinkit Swaps');
      await tester.ensureVisible(swapsTile);
      await tester.tap(swapsTile);
      await tester.pumpAndSettle();

      expect(find.byType(HealthierSwapsScreen), findsOneWidget);
      expect(find.text('Smart Healthier Swaps'), findsOneWidget);
    });

    testWidgets('tapping INS Decoder action tile switches to Search tab and selects Additives category', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      final insTile = find.text('INS Decoder');
      await tester.ensureVisible(insTile);
      await tester.tap(insTile);
      await tester.pumpAndSettle();

      // Confirms switched to Search Catalog view (Tab 1)
      expect(find.byType(TextField), findsOneWidget);
      // Confirms Additives chip is selected
      expect(find.widgetWithText(ChoiceChip, 'Additives'), findsOneWidget);
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

  group('HomeScreen Search Tab Integration Tests', () {
    testWidgets('tapping Search tab switches to Search Catalog View with verified products and navigation', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      // Tap Search tab in bottom nav
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      // Verify search view is rendered
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search foods, brands, or barcodes...'), findsOneWidget);
      expect(find.textContaining('Verified Products ('), findsOneWidget);

      // Verify catalog items appear
      expect(find.text('Good Day Butter Cookies'), findsOneWidget);
      expect(find.text('2-Minute Masala Noodles'), findsOneWidget);
      expect(find.text('100% Whole Grain Rolled Oats'), findsOneWidget);

      // Filter by search query
      await tester.enterText(find.byType(TextField), 'Noodles');
      await tester.pumpAndSettle();

      expect(find.text('2-Minute Masala Noodles'), findsOneWidget);
      expect(find.text('Good Day Butter Cookies'), findsNothing);

      // Tapping on product card navigates to VerdictReportScreen
      await tester.tap(find.text('2-Minute Masala Noodles'));
      await tester.pumpAndSettle();

      expect(find.text('32'), findsOneWidget);
      expect(find.text('Toxic / Capped 🔴'), findsOneWidget);
    });

    testWidgets('rapidly double-tapping a product card in Search only pushes VerdictReportScreen once', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      // Tap Search tab in bottom nav
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      final noodlesCard = find.text('2-Minute Masala Noodles');
      expect(noodlesCard, findsOneWidget);

      // Perform rapid double-tap (2 taps without pumpAndSettle in between)
      await tester.tap(noodlesCard);
      await tester.tap(noodlesCard, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Exactly ONE VerdictReportScreen must be mounted
      expect(find.byType(VerdictReportScreen), findsOneWidget);

      // Popping once must return directly back to Search Catalog
      Navigator.of(tester.element(find.byType(VerdictReportScreen))).pop();
      await tester.pumpAndSettle();

      // Verify we are back on Search, and VerdictReportScreen is gone
      expect(find.byType(VerdictReportScreen), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('empty search results show empty state with camera trigger CTA', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'UnknownItem12345');
      await tester.pumpAndSettle();

      expect(find.text('No products found matching "UnknownItem12345"'), findsOneWidget);
      expect(find.text('Open Smart Camera'), findsOneWidget);
    });
  });

  group('UserProfileManager Persistence & Reactivity on HomeScreen', () {
    testWidgets('header subtitle updates dynamically when weight updates to 87 kg and survives tab switching', (tester) async {
      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();

      // Initially displays 65 kg Adult • Safe Baseline
      expect(find.text('65 kg Adult • Safe Baseline'), findsOneWidget);

      // User updates profile (e.g. from ProfileScreen or UserDetailsScreen)
      final updatedProfile = UserProfileModel(
        userId: 'local_user',
        weightKg: 87.0,
        age: 38,
        isChild: false,
        isCompleted: true,
        updatedAt: DateTime.now(),
      );
      await UserProfileManager.instance.updateProfile(updatedProfile);
      await tester.pumpAndSettle();

      // Subtitle must update immediately to 87 kg Adult • Safe Baseline
      expect(find.text('87 kg Adult • Safe Baseline'), findsOneWidget);

      // Switch to Search tab
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      // Switch back to Home tab
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();

      // Subtitle must STILL be 87 kg Adult • Safe Baseline
      expect(find.text('87 kg Adult • Safe Baseline'), findsOneWidget);
    });

    testWidgets('tapping Reset Today in Daily Intake log does not reset user profile from 87 kg to 65 kg', (tester) async {
      // Set user to 87 kg in UserProfileManager
      await UserProfileManager.instance.updateWeight(87.0);

      // Log a sample intake item so entries is not empty and Reset Today button appears
      final tracker = DailyConsumptionTracker.instance;
      await tracker.logProductIntake(
        const ScannedProductResult(
          barcode: '8901063012117',
          productName: 'Good Day Butter Cookies',
          brandName: 'Britannia',
          category: 'Biscuits & Cookies',
          servingSizeG: 25.0,
          packWeightG: 75.0,
          caloriesPerServing: 125.0,
          caloriesPer100g: 500.0,
          sugarGPer100g: 24.5,
          sugarGPerServing: 6.1,
          satFatGPer100g: 11.2,
          sodiumMgPer100g: 280.0,
          totalFatGPer100g: 22.0,
          carbsGPer100g: 68.0,
          proteinGPer100g: 6.0,
          fiberGPer100g: 1.8,
          addedSugarGPer100g: 20.0,
          transFatGPer100g: 0.1,
          cholesterolMgPer100g: 10.0,
          healthScore: 48,
          novaGrade: 4,
          redCapTriggered: false,
          additives: [],
          splitSugars: [],
          safePortionGrams: 25,
          limitingFactor: 'Sugar',
          verdictTag: 'Moderate',
          frequencySchedule: '2-3 times/week',
          portionAdvice: 'Safe portion advice',
          isExceededBudget: false,
        ),
      );

      await tester.pumpWidget(buildTestableHomeScreen());
      await tester.pumpAndSettle();
      expect(find.text('87 kg Adult • Safe Baseline'), findsOneWidget);

      // Open Daily Intake Log bottom sheet
      final budgetCard = find.textContaining('Daily Consumption Budget');
      await tester.ensureVisible(budgetCard);
      await tester.tap(budgetCard);
      await tester.pumpAndSettle();

      // Tap Reset Today
      final resetBtn = find.text('Reset Today');
      expect(resetBtn, findsOneWidget);
      await tester.tap(resetBtn);
      await tester.pumpAndSettle();

      // Confirm reset dialog
      final confirmBtn = find.widgetWithText(FilledButton, 'Reset');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Subtitle must still remain 87 kg!
      expect(find.text('87 kg Adult • Safe Baseline'), findsOneWidget);
      expect(UserProfileManager.instance.weightKg, equals(87.0));
    });
  });
}
