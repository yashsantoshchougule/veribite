/// Configuration constants and environment keys for VeriBite Google OAuth & Signing Keystore.
class OAuthConfig {
  /// Android Application ID (package name) registered in Google Cloud Console
  static const String applicationId = 'com.example.mobile_app';

  /// Deterministic Project Keystore SHA-1 Fingerprint (android/app/veribite-debug.keystore)
  static const String debugSha1 = '2F:68:24:FE:BA:24:63:76:73:7C:11:D0:5B:23:22:51:8E:A3:25:C2';

  /// Deterministic Project Keystore SHA-256 Fingerprint (android/app/veribite-debug.keystore)
  static const String debugSha256 = 'A4:F2:99:0D:F4:92:41:39:3E:FF:DF:4D:F3:68:2C:8A:B3:84:C3:6A:2C:B2:27:8C:B7:48:58:AC:A5:7C:6A:A0';

  /// Explicit Google Web Client ID (serverClientId) passed to GoogleSignIn
  /// Read from compile-time environment variable (--dart-define=GOOGLE_WEB_CLIENT_ID=...)
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '',
  );

  /// Custom scheme for browser-based PKCE OAuth callback (does not depend on Android keystore)
  static const String customSchemeRedirectUri = 'veribite://auth-callback';

  /// Supabase deep link scheme for browser-based OAuth callback
  static const String supabaseSchemeRedirectUri = 'io.supabase.veribite://login-callback/';

  /// Whether a Web OAuth serverClientId has been supplied via environment
  static bool get hasServerClientId => googleWebClientId.trim().isNotEmpty;
}

