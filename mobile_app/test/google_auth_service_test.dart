import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/config/oauth_config.dart';
import 'package:mobile_app/features/auth/application/google_auth_service.dart';
import 'package:mobile_app/features/auth/presentation/widgets/keystore_diagnostic_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OAuthConfig Tests', () {
    test('contains deterministic package ID and SHA fingerprints', () {
      expect(OAuthConfig.applicationId, 'com.example.mobile_app');
      expect(OAuthConfig.debugSha1, '2F:68:24:FE:BA:24:63:76:73:7C:11:D0:5B:23:22:51:8E:A3:25:C2');
      expect(OAuthConfig.debugSha256, 'A4:F2:99:0D:F4:92:41:39:3E:FF:DF:4D:F3:68:2C:8A:B3:84:C3:6A:2C:B2:27:8C:B7:48:58:AC:A5:7C:6A:A0');
      expect(OAuthConfig.customSchemeRedirectUri, 'veribite://auth-callback');
      expect(OAuthConfig.supabaseSchemeRedirectUri, 'io.supabase.veribite://login-callback/');
    });
  });

  group('GoogleAuthService Keystore Error Classification Tests', () {
    test('correctly identifies Android ApiException: 10 as keystore mismatch', () {
      const error1 = 'PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10: , null, null)';
      expect(GoogleAuthService.isKeystoreMismatchError(error1), isTrue);

      const error2 = 'ApiException: 10 (DEVELOPER_ERROR): The application has not been configured in Google Cloud Console';
      expect(GoogleAuthService.isKeystoreMismatchError(error2), isTrue);

      const error3 = 'com.google.android.gms.common.api.ApiException: 12500: Sign in failed';
      expect(GoogleAuthService.isKeystoreMismatchError(error3), isTrue);

      const error4 = 'sign_in_failed: SHA-1 fingerprint mismatch';
      expect(GoogleAuthService.isKeystoreMismatchError(error4), isTrue);

      const error5 = 'OAuth redirect_uri_mismatch for Android package';
      expect(GoogleAuthService.isKeystoreMismatchError(error5), isTrue);
    });

    test('returns false for unrelated errors', () {
      expect(GoogleAuthService.isKeystoreMismatchError(null), isFalse);
      expect(GoogleAuthService.isKeystoreMismatchError(''), isFalse);
      expect(GoogleAuthService.isKeystoreMismatchError('User cancelled the sign in flow'), isFalse);
      expect(GoogleAuthService.isKeystoreMismatchError('SocketException: Failed host lookup'), isFalse);
    });

    test('GoogleKeystoreMismatchException exposes package name and SHA fingerprints', () {
      const exception = GoogleKeystoreMismatchException(
        message: 'Keystore fingerprint not registered',
        rawError: 'ApiException: 10',
      );

      expect(exception.applicationId, 'com.example.mobile_app');
      expect(exception.sha1, '2F:68:24:FE:BA:24:63:76:73:7C:11:D0:5B:23:22:51:8E:A3:25:C2');
      expect(exception.sha256, 'A4:F2:99:0D:F4:92:41:39:3E:FF:DF:4D:F3:68:2C:8A:B3:84:C3:6A:2C:B2:27:8C:B7:48:58:AC:A5:7C:6A:A0');
      expect(exception.toString(), 'Keystore fingerprint not registered');
    });
  });

  group('KeystoreDiagnosticSheet Widget Tests', () {
    testWidgets('renders package ID, SHA-1, SHA-256 fingerprints, and actions', (tester) async {
      bool localProfileTapped = false;
      bool browserOAuthTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  KeystoreDiagnosticSheet.show(
                    context,
                    rawError: 'ApiException: 10',
                    onContinueWithLocalProfile: () {
                      localProfileTapped = true;
                    },
                    onRetryBrowserOAuth: () {
                      browserOAuthTapped = true;
                    },
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      // Open bottom sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      // Verify header and description
      expect(find.text('Google Sign-In Keystore Notice'), findsOneWidget);
      expect(find.textContaining('ApiException: 10'), findsOneWidget);

      // Verify package ID and SHA fingerprints are displayed
      expect(find.text('com.example.mobile_app'), findsOneWidget);
      expect(find.text('2F:68:24:FE:BA:24:63:76:73:7C:11:D0:5B:23:22:51:8E:A3:25:C2'), findsOneWidget);
      expect(find.text('A4:F2:99:0D:F4:92:41:39:3E:FF:DF:4D:F3:68:2C:8A:B3:84:C3:6A:2C:B2:27:8C:B7:48:58:AC:A5:7C:6A:A0'), findsOneWidget);

      // Verify buttons
      expect(find.text('Continue with Instant Local Profile'), findsOneWidget);
      expect(find.text('Try Zero-Keystore Browser OAuth'), findsOneWidget);

      // Tap Instant Local Profile
      await tester.tap(find.text('Continue with Instant Local Profile'));
      await tester.pumpAndSettle();

      expect(localProfileTapped, isTrue);

      // Reopen and tap Retry Browser OAuth
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      final browserBtn = find.text('Try Zero-Keystore Browser OAuth');
      await tester.ensureVisible(browserBtn);
      await tester.pumpAndSettle();

      await tester.tap(browserBtn);
      await tester.pumpAndSettle();

      expect(browserOAuthTapped, isTrue);
    });

    testWidgets('copy button puts fingerprint into clipboard', (tester) async {
      String? copiedString;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedString = (call.arguments as Map)['text'];
          }
          return null;
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeystoreDiagnosticSheet(
              onContinueWithLocalProfile: () {},
            ),
          ),
        ),
      );

      // Tap copy icon for SHA-1
      final copyButtons = find.byIcon(Icons.copy_rounded);
      expect(copyButtons, findsNWidgets(3));

      await tester.tap(copyButtons.at(1)); // SHA-1 copy button
      await tester.pump();

      expect(copiedString, '2F:68:24:FE:BA:24:63:76:73:7C:11:D0:5B:23:22:51:8E:A3:25:C2');
    });
  });
}
