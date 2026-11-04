import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/auth/application/supabase_auth_service.dart';
import 'package:mobile_app/features/auth/presentation/login_screen.dart';
import 'package:mobile_app/features/profile/application/user_profile_service.dart';
import 'package:mobile_app/features/profile/domain/user_profile_model.dart';
import 'package:mobile_app/features/profile/presentation/profile_screen.dart';
import 'package:mobile_app/features/profile/presentation/user_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserProfileService.resetAllCache();
  });

  Widget buildTestableProfileScreen({
    String userId = 'test_profile_user',
    UserProfileService? service,
    SupabaseAuthService? authService,
  }) {
    return ProviderScope(
      child: MaterialApp(
        home: ProfileScreen(
          userId: userId,
          profileService: service,
          authService: authService,
        ),
      ),
    );
  }

  group('ProfileScreen Visual & Section Component Tests', () {
    testWidgets('renders top bar, identity card, biometrics, safe ceilings, language, and sign out', (tester) async {
      final service = UserProfileService();
      await service.saveProfile(
        UserProfileModel(
          userId: 'test_profile_user',
          weightKg: 65.0,
          isChild: false,
          allergens: ['Peanuts', 'Gluten / Wheat'],
          dietaryPreference: 'Vegetarian',
          isCompleted: true,
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(buildTestableProfileScreen(service: service));
      await tester.pumpAndSettle();

      // Top Bar
      expect(find.text('My Health Profile'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      // Identity Card
      expect(find.textContaining('VeriBite Consumer'), findsOneWidget);
      expect(find.textContaining('Verified Account • Isolated Storage'), findsOneWidget);

      // Biometrics Card
      expect(find.text('Active Biometrics & Life Stage'), findsOneWidget);
      expect(find.text('65.0'), findsOneWidget);
      expect(find.text('Adult (18+ Standard)'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);

      // Safe Ceilings Card
      expect(find.text('Calculated Safe Daily Ceilings'), findsOneWidget);
      expect(find.text('Free Sugar Max'), findsOneWidget);
      expect(find.text('25g'), findsOneWidget);
      expect(find.text('Single Snack'), findsOneWidget);
      expect(find.text('≤ 5g'), findsOneWidget);
      expect(find.text('Sodium Cap'), findsOneWidget);

      // Allergens & Diet Card
      expect(find.text('Allergens & Diet Watchlist'), findsOneWidget);
      expect(find.text('Vegetarian'), findsOneWidget);
      expect(find.textContaining('Peanuts'), findsOneWidget);
      expect(find.textContaining('Gluten / Wheat'), findsOneWidget);

      // Language Selector Card
      expect(find.text('Regional Voice Read-Out Language'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('Hindi (हिंदी)'), findsOneWidget);
      expect(find.text('Marathi (मराठी)'), findsOneWidget);

      // Offline Engine & Privacy Card
      expect(find.text('Offline Engine & Privacy Guard'), findsOneWidget);
      expect(find.textContaining('6,450+ chemical INS / E-numbers loaded offline in SQLite.'), findsOneWidget);

      // Sign Out Button
      expect(find.text('Sign Out of Account'), findsOneWidget);
    });

    testWidgets('calculates custom medical guardrail ceilings for diabetic child', (tester) async {
      final service = UserProfileService();
      await service.saveProfile(
        UserProfileModel(
          userId: 'diabetic_child_user',
          weightKg: 30.0,
          isChild: true,
          isDiabetic: true,
          isHypertensive: true,
          isCompleted: true,
          updatedAt: DateTime.now(),
        ),
      );

      await tester.pumpWidget(buildTestableProfileScreen(
        userId: 'diabetic_child_user',
        service: service,
      ));
      await tester.pumpAndSettle();

      expect(find.text('30.0'), findsOneWidget);
      expect(find.text('Child / Teen (< 18 yrs)'), findsOneWidget);
      expect(find.text('🛡️ Type-2 Diabetic'), findsOneWidget);
      expect(find.text('🛡️ Hypertension Guard'), findsOneWidget);
      expect(find.text('🛡️ Child Guard (<18 yrs)'), findsOneWidget);

      // Diabetic capped sugar limit: 10g/day, single snack: <= 2g, hypertensive sodium: 1500mg
      expect(find.text('10g'), findsOneWidget);
      expect(find.text('≤ 2g'), findsOneWidget);
      expect(find.text('1500mg'), findsOneWidget);
    });
  });

  group('ProfileScreen Interaction & Navigation Tests', () {
    testWidgets('tapping Edit on Biometrics card navigates to UserDetailsScreen in edit mode', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      final editBtn = find.text('Edit');
      expect(editBtn, findsOneWidget);
      await tester.tap(editBtn);
      await tester.pumpAndSettle();

      expect(find.byType(UserDetailsScreen), findsOneWidget);
      expect(find.text('Edit Safe Limits'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('tapping language chip updates user profile language', (tester) async {
      final service = UserProfileService();
      await tester.pumpWidget(buildTestableProfileScreen(service: service));
      await tester.pumpAndSettle();

      // Tap Hindi
      final hindiChip = find.text('Hindi (हिंदी)');
      expect(hindiChip, findsOneWidget);
      await tester.ensureVisible(hindiChip);
      await tester.pumpAndSettle();
      await tester.tap(hindiChip);
      await tester.pumpAndSettle();

      final saved = await service.getProfile('test_profile_user');
      expect(saved?.language, equals('hi'));
    });

    testWidgets('tapping Sign Out shows confirmation dialog and cancels cleanly', (tester) async {
      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      final signOutBtn = find.text('Sign Out of Account');
      await tester.ensureVisible(signOutBtn);
      await tester.pumpAndSettle();
      await tester.tap(signOutBtn);
      await tester.pumpAndSettle();

      expect(find.text('Sign Out of VeriBite'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
    });
  });

  group('ProfileScreen Responsive Layout Tests', () {
    testWidgets('renders cleanly on Small Compact Phone (320x568) without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('My Health Profile'), findsOneWidget);
      expect(find.text('Calculated Safe Daily Ceilings'), findsOneWidget);
    });

    testWidgets('renders cleanly on Standard Phone (390x844) without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('My Health Profile'), findsOneWidget);
    });

    testWidgets('renders cleanly on moto g85 5G (412x915) without overflow', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('My Health Profile'), findsOneWidget);
    });

    testWidgets('renders cleanly on Tablet (768x1024) with centered constraints', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(buildTestableProfileScreen());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('My Health Profile'), findsOneWidget);
    });
  });
}
