import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_app/features/profile/application/user_profile_service.dart';
import 'package:mobile_app/features/profile/presentation/user_details_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UserProfileService.resetAllCache();
  });

  Widget buildTestableScreen({
    required String userId,
    required VoidCallback onComplete,
    UserProfileService? service,
  }) {
    return MaterialApp(
      home: UserDetailsScreen(
        userId: userId,
        onComplete: onComplete,
        profileService: service,
      ),
    );
  }

  group('UserDetailsScreen Visual & Interaction Tests', () {
    testWidgets('renders headline, weight readout, life stage, and skip options', (tester) async {
      await tester.pumpWidget(
        buildTestableScreen(
          userId: 'user_visual_test',
          onComplete: () {},
        ),
      );

      expect(find.text('Tailor Your Safe Limits'), findsOneWidget);
      expect(find.text('Body Weight'), findsOneWidget);
      expect(find.text('65.0'), findsOneWidget);
      expect(find.text('Adult (18+)'), findsOneWidget);
      expect(find.text('Child / Teen'), findsOneWidget);
      expect(find.text('Save & Open Scanner'), findsOneWidget);
      expect(find.text('Skip for now'), findsOneWidget);
    });

    testWidgets('increment and decrement buttons adjust weight value', (tester) async {
      await tester.pumpWidget(
        buildTestableScreen(
          userId: 'user_stepper_test',
          onComplete: () {},
        ),
      );

      expect(find.text('65.0'), findsOneWidget);

      // Tap + button
      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.text('66.0'), findsOneWidget);

      // Tap - button twice
      await tester.tap(find.byIcon(Icons.remove_circle_outline_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.remove_circle_outline_rounded));
      await tester.pumpAndSettle();
      expect(find.text('64.0'), findsOneWidget);
    });

    testWidgets('selecting Child switches mode and displays Hyperactivity Guard banner', (tester) async {
      await tester.pumpWidget(
        buildTestableScreen(
          userId: 'user_child_test',
          onComplete: () {},
        ),
      );

      expect(find.textContaining('Child Hyperactivity Guard active'), findsNothing);

      // Tap Child / Teen
      final childFinder = find.text('Child / Teen');
      await tester.ensureVisible(childFinder);
      await tester.pumpAndSettle();
      await tester.tap(childFinder);
      await tester.pumpAndSettle();

      expect(find.textContaining('Child Hyperactivity Guard active'), findsOneWidget);
    });

    testWidgets('saving custom profile persists data under isolated userId and calls onComplete', (tester) async {
      bool completed = false;
      final service = UserProfileService();

      await tester.pumpWidget(
        buildTestableScreen(
          userId: 'user_save_isolation_1',
          onComplete: () {
            completed = true;
          },
          service: service,
        ),
      );

      // Increment weight to 66 kg
      await tester.tap(find.byIcon(Icons.add_circle_outline_rounded));
      await tester.pumpAndSettle();

      // Tap Diabetic chip with ensureVisible
      final diabeticFinder = find.text('Type-2 Diabetic / Pre-Diabetic');
      await tester.ensureVisible(diabeticFinder);
      await tester.pumpAndSettle();
      await tester.tap(diabeticFinder);
      await tester.pumpAndSettle();

      // Tap Save & Open Scanner
      final saveFinder = find.text('Save & Open Scanner');
      await tester.ensureVisible(saveFinder);
      await tester.pumpAndSettle();
      await tester.tap(saveFinder);
      await tester.pumpAndSettle();

      expect(completed, isTrue);

      // Verify User 1 profile has custom details
      final saved1 = await service.getProfile('user_save_isolation_1');
      expect(saved1, isNotNull);
      expect(saved1!.weightKg, equals(66.0));
      expect(saved1.isDiabetic, isTrue);
      expect(saved1.isCompleted, isTrue);

      // Verify User 2 has zero data
      final saved2 = await service.getProfile('user_save_isolation_2');
      expect(saved2, isNull);
    });

    testWidgets('tapping Skip for now persists safe baseline defaults and calls onComplete', (tester) async {
      bool completed = false;
      final service = UserProfileService();

      await tester.pumpWidget(
        buildTestableScreen(
          userId: 'user_skip_test',
          onComplete: () {
            completed = true;
          },
          service: service,
        ),
      );

      // Tap top Skip for now
      await tester.tap(find.text('Skip for now').first);
      await tester.pumpAndSettle();

      expect(completed, isTrue);

      final saved = await service.getProfile('user_skip_test');
      expect(saved, isNotNull);
      expect(saved!.weightKg, equals(65.0));
      expect(saved.isChild, isFalse);
      expect(saved.isDiabetic, isFalse);
      expect(saved.isCompleted, isFalse); // Marked as skipped/default
    });
  });

  group('UserDetailsScreen Responsive Layout Tests', () {
    testWidgets('renders cleanly on Small Compact Phone (320x568) without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestableScreen(
          userId: 'user_small_screen',
          onComplete: () {},
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Tailor Your Safe Limits'), findsOneWidget);
      expect(find.text('Save & Open Scanner'), findsOneWidget);
    });

    testWidgets('renders cleanly on Standard Phone (390x844) without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        buildTestableScreen(
          userId: 'user_std_screen',
          onComplete: () {},
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Tailor Your Safe Limits'), findsOneWidget);
      expect(find.text('Save & Open Scanner'), findsOneWidget);
    });
  });

  group('UserDetailsScreen Edit Mode & Preset Tests', () {
    testWidgets('renders Edit Safe Limits headline and Save Changes button in edit mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UserDetailsScreen(
            userId: 'edit_mode_user',
            isEditMode: true,
            onComplete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Safe Limits'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Skip for now'), findsNothing);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });

    testWidgets('1-tap weight preset chips update weight value instantly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: UserDetailsScreen(
            userId: 'preset_weight_user',
            onComplete: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('65.0'), findsOneWidget);

      // Tap 80 kg chip
      final chip80 = find.text('80 kg');
      expect(chip80, findsOneWidget);
      await tester.tap(chip80);
      await tester.pumpAndSettle();

      expect(find.text('80.0'), findsOneWidget);
    });
  });
}
