import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/auth/presentation/login_screen.dart';
import 'package:mobile_app/features/auth/presentation/widgets/google_logo_icon.dart';
import 'package:mobile_app/features/auth/presentation/widgets/login_feature_chip.dart';
import 'package:mobile_app/main.dart';

void main() {
  group('LoginScreen Visual & Component Tests', () {
    testWidgets('renders all headers, chips, actions, and disclaimer correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Verify Header Headline & Subtitle
      expect(find.text('Join 1 million+ smart consumers'), findsOneWidget);
      expect(find.text('Scan smarter. Choose wiser.'), findsOneWidget);

      // Verify Value Proposition Chips
      expect(find.byType(LoginFeatureChip), findsNWidgets(3));
      expect(find.text('Personalized insights'), findsOneWidget);
      expect(find.text('Instant results'), findsOneWidget);
      expect(find.text('Earn rewards'), findsOneWidget);

      // Verify Action Section
      expect(find.text('Welcome to VeriBite'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.byType(GoogleLogoIcon), findsOneWidget);
      expect(find.text('Or'), findsOneWidget);
      expect(find.text('Enter your Email/Phone'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Verify Footer Disclaimer
      expect(find.text('By continuing you agree to VeriBite'), findsOneWidget);
      expect(find.text('Terms & Conditions'), findsOneWidget);
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('triggers onGoogleSignIn when Google button is tapped', (tester) async {
      bool googleTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onGoogleSignIn: () {
              googleTapped = true;
            },
          ),
        ),
      );

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(googleTapped, isTrue);
    });

    testWidgets('shows validation error when continue is tapped with empty input', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email or phone number'), findsOneWidget);
    });

    testWidgets('shows validation error when continue is tapped with invalid input', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      await tester.enterText(find.byType(TextField), 'invalidinput');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address or 10-digit mobile number'), findsOneWidget);
    });

    testWidgets('succeeds with valid email address', (tester) async {
      String? submittedCredential;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onContinueWithCredential: (val) {
              submittedCredential = val;
            },
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'tester@veribite.app');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(submittedCredential, equals('tester@veribite.app'));
    });

    testWidgets('succeeds with valid 10-digit phone number', (tester) async {
      String? submittedCredential;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onContinueWithCredential: (val) {
              submittedCredential = val;
            },
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '9876543210');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(submittedCredential, equals('9876543210'));
    });
  });

  group('LoginScreen Responsive Layout Tests', () {
    testWidgets('renders cleanly on Small Compact Phone (320x568) without overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Welcome to VeriBite'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('renders cleanly on Standard Phone (390x844) without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Welcome to VeriBite'), findsOneWidget);
    });
  });

  group('Walkthrough to Login End-to-End Navigation Test', () {
    testWidgets('skipping walkthrough navigates to LoginScreen', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: ScannerApp()),
      );

      expect(find.text('Point & Scan Any Food Packet'), findsOneWidget);

      // Skip to Step 4
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      expect(find.text('Get Started & Sign In →'), findsOneWidget);

      // Tap Get Started & Sign In -> Should navigate to LoginScreen
      await tester.tap(find.text('Get Started & Sign In →'));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to VeriBite'), findsOneWidget);
      expect(find.text('Join 1 million+ smart consumers'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });
}
