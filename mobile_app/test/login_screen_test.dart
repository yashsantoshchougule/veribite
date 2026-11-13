import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/auth/presentation/login_screen.dart';
import 'package:mobile_app/features/auth/presentation/widgets/login_feature_chip.dart';
import 'package:mobile_app/features/legal/presentation/legal_policy_screen.dart';
import 'package:mobile_app/main.dart';

void main() {
  group('LoginScreen Visual & Value Chips Tests', () {
    testWidgets('renders full-bleed logo, 2 value chips, and excludes earn rewards', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Verify Header Headline & Subtitle
      expect(find.text('Join 1 million+ smart consumers'), findsOneWidget);
      expect(find.text('Scan smarter. Choose wiser.'), findsOneWidget);

      // Verify Value Proposition Chips: exactly 2 chips
      expect(find.byType(LoginFeatureChip), findsNWidgets(2));
      expect(find.text('Personalized insights'), findsOneWidget);
      expect(find.text('Instant results'), findsOneWidget);
      expect(find.text('Earn rewards'), findsNothing);

      // Verify Dual Tab Switcher
      expect(find.text('Login'), findsWidgets);
      expect(find.text('Sign In'), findsWidgets);
    });
  });

  group('Login Section Tests (2 Fields + Forgot Password)', () {
    testWidgets('renders Username, Password, Forgot Password, and Google options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Forgot Password?'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Create new account'), findsOneWidget);
    });

    testWidgets('shows validation error for empty login fields', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Find the Login action button and tap it
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your username or email'), findsOneWidget);
    });

    testWidgets('successful login submission invokes onLoginSubmit callback', (tester) async {
      String? submittedUser;
      String? submittedPass;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onLoginSubmit: (u, p) {
              submittedUser = u;
              submittedPass = p;
            },
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Username'), 'veribite_user');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'secret123');

      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pumpAndSettle();

      expect(submittedUser, equals('veribite_user'));
      expect(submittedPass, equals('secret123'));
    });

    testWidgets('tapping Forgot Password opens reset sheet and sends Gmail reset link', (tester) async {
      String? sentEmail;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onForgotPassword: (email) {
              sentEmail = email;
            },
          ),
        ),
      );

      await tester.tap(find.text('Forgot Password?'));
      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Enter your Gmail address'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Enter your Gmail address'), 'user@gmail.com');
      await tester.tap(find.text('Send Reset Link via Gmail'));
      await tester.pumpAndSettle();

      expect(sentEmail, equals('user@gmail.com'));
      expect(find.text('Password reset link sent to user@gmail.com'), findsOneWidget);
    });
  });

  group('Sign-In (Registration) Section Tests (5 Fields)', () {
    testWidgets('tapping Create new account shifts to Sign In section with 5 fields', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Scroll and tap "Create new account" to shift to Sign In tab
      await tester.ensureVisible(find.text('Create new account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create new account'));
      await tester.pumpAndSettle();

      // Check all 5 fields
      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Username to set'), findsOneWidget);
      expect(find.text('Gmail Address'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Sign In'), findsOneWidget);
      expect(find.text('Already have an account? '), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('validates matching passwords in Sign In section', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Switch to Sign In tab
      await tester.tap(find.text('Sign In').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Full Name'), 'John Doe');
      await tester.enterText(find.widgetWithText(TextField, 'Username to set'), 'johndoe');
      await tester.enterText(find.widgetWithText(TextField, 'Gmail Address'), 'johndoe@gmail.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'pass1234');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'mismatch');

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('successful sign-in submits all 5 fields', (tester) async {
      String? capturedName;
      String? capturedUsername;
      String? capturedEmail;

      await tester.pumpWidget(
        MaterialApp(
          home: LoginScreen(
            onSignInSubmit: (n, u, e, p) {
              capturedName = n;
              capturedUsername = u;
              capturedEmail = e;
            },
          ),
        ),
      );

      // Switch to Sign In tab
      await tester.tap(find.text('Sign In').first);
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Full Name'), 'John Doe');
      await tester.enterText(find.widgetWithText(TextField, 'Username to set'), 'johndoe');
      await tester.enterText(find.widgetWithText(TextField, 'Gmail Address'), 'johndoe@gmail.com');
      await tester.enterText(find.widgetWithText(TextField, 'Password'), 'secure123');
      await tester.enterText(find.widgetWithText(TextField, 'Confirm Password'), 'secure123');

      await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Sign In'));
      await tester.pumpAndSettle();

      expect(capturedName, equals('John Doe'));
      expect(capturedUsername, equals('johndoe'));
      expect(capturedEmail, equals('johndoe@gmail.com'));
    });

    testWidgets('tapping Already have an account? shifts back to Login section', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      // Go to Sign In
      await tester.ensureVisible(find.text('Create new account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create new account'));
      await tester.pumpAndSettle();
      expect(find.text('Full Name'), findsOneWidget);

      // Tap Login link to return
      await tester.ensureVisible(find.text('Login').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Login').last);
      await tester.pumpAndSettle();
      expect(find.text('Full Name'), findsNothing);
      expect(find.text('Forgot Password?'), findsOneWidget);
    });
  });

  group('Swipe Gesture & Responsive Layout Tests', () {
    testWidgets('swiping horizontally transitions between Login and Sign In', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      expect(find.text('Forgot Password?'), findsOneWidget);

      // Swipe Left on the auth area -> Moves to Sign In
      await tester.drag(find.text('Welcome to VeriBite'), const Offset(-300, 0));
      await tester.pumpAndSettle();

      expect(find.text('Full Name'), findsOneWidget);

      // Swipe Right -> Moves back to Login
      await tester.drag(find.text('Welcome to VeriBite'), const Offset(300, 0));
      await tester.pumpAndSettle();

      expect(find.text('Forgot Password?'), findsOneWidget);
    });

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
      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
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

  group('Legal & Privacy Policy Navigation Tests', () {
    testWidgets('tapping Terms & Conditions in footer navigates to LegalPolicyScreen on terms tab', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      final termsFinder = find.text('Terms & Conditions');
      await tester.ensureVisible(termsFinder);
      await tester.pumpAndSettle();
      expect(termsFinder, findsOneWidget);

      await tester.tap(termsFinder);
      await tester.pumpAndSettle();

      expect(find.byType(LegalPolicyScreen), findsOneWidget);
      expect(find.text('VeriBite Terms of Service'), findsOneWidget);
      expect(find.text('CRITICAL MEDICAL & NUTRITIONAL DISCLAIMER'), findsOneWidget);
    });

    testWidgets('tapping Privacy Policy in footer navigates to LegalPolicyScreen on privacy tab', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );

      final privacyFinder = find.text('Privacy Policy');
      await tester.ensureVisible(privacyFinder);
      await tester.pumpAndSettle();
      expect(privacyFinder, findsOneWidget);

      await tester.tap(privacyFinder);
      await tester.pumpAndSettle();

      expect(find.byType(LegalPolicyScreen), findsOneWidget);
      expect(find.text('VeriBite Privacy Policy'), findsOneWidget);
      expect(find.text('OUR ZERO-TRACKING & ZERO-AD PLEDGE'), findsOneWidget);
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

    testWidgets('tapping Continue with Google invokes onGoogleSignIn callback', (tester) async {
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

      final googleBtn = find.text('Continue with Google');
      await tester.ensureVisible(googleBtn);
      await tester.pumpAndSettle();

      await tester.tap(googleBtn);
      await tester.pumpAndSettle();

      expect(googleTapped, isTrue);
    });
  });
}
