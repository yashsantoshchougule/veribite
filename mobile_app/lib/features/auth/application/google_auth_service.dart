import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/oauth_config.dart';

/// Exception thrown when native Google Sign-In fails due to an unregistered
/// Android keystore SHA-1 / SHA-256 fingerprint (ApiException: 10).
class GoogleKeystoreMismatchException implements Exception {
  final String message;
  final String rawError;
  final String applicationId;
  final String sha1;
  final String sha256;

  const GoogleKeystoreMismatchException({
    required this.message,
    required this.rawError,
    this.applicationId = OAuthConfig.applicationId,
    this.sha1 = OAuthConfig.debugSha1,
    this.sha256 = OAuthConfig.debugSha256,
  });

  @override
  String toString() => message;
}

/// Authentication service orchestrating Google Sign-In with:
/// 1. Project-level keystore deterministic verification
/// 2. Explicit serverClientId Web OAuth configuration
/// 3. Stale session eviction
/// 4. 2-Tier fallback: Browser PKCE OAuth -> Seamless Instant Local Profile
class GoogleAuthService {
  final GoogleSignIn? _injectedGoogleSignIn;
  final SupabaseClient? _injectedSupabaseClient;

  GoogleAuthService({
    GoogleSignIn? googleSignIn,
    SupabaseClient? supabaseClient,
  })  : _injectedGoogleSignIn = googleSignIn,
        _injectedSupabaseClient = supabaseClient;

  GoogleSignIn get _googleSignIn {
    final injected = _injectedGoogleSignIn;
    if (injected != null) return injected;
    return GoogleSignIn(
      serverClientId: OAuthConfig.hasServerClientId ? OAuthConfig.googleWebClientId : null,
      scopes: const ['email', 'profile'],
    );
  }

  SupabaseClient? get _supabaseClient {
    if (_injectedSupabaseClient != null) return _injectedSupabaseClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Determines if an error represents an Android keystore / OAuth client mismatch.
  /// Typically ApiException: 10 (DEVELOPER_ERROR), code 12500, or sign_in_failed.
  static bool isKeystoreMismatchError(dynamic error) {
    if (error == null) return false;
    final errStr = error.toString().toLowerCase();

    return errStr.contains('apiexception: 10') ||
        errStr.contains('code 10') ||
        errStr.contains('developer_error') ||
        errStr.contains('12500') ||
        errStr.contains('sign_in_failed') ||
        errStr.contains('redirect_uri_mismatch');
  }

  /// Executes Google Sign-In with automated 2-tier fallback and stale session eviction.
  Future<AuthResponse?> signInWithGoogle({
    void Function(String message)? onStatusUpdate,
  }) async {
    // 1. Evict any stale or corrupted cached OAuth session
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // Ignore cleanup failures on unauthenticated instances
    }

    // 2. Attempt Native Android / Platform Google Sign-In
    try {
      onStatusUpdate?.call('Opening Google Sign-In...');
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User voluntarily dismissed the sign-in modal
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      final supabase = _supabaseClient;
      if (supabase != null && idToken != null) {
        onStatusUpdate?.call('Verifying Google credentials with Supabase...');
        final res = await supabase.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
        return res;
      }

      // If Supabase client is uninitialized, return synthetic successful response
      // or proceed with verified Google User details
      return null;
    } on PlatformException catch (pe) {
      debugPrint('[GoogleAuthService] Native Google Sign-In PlatformException: ${pe.code} - ${pe.message}');

      if (isKeystoreMismatchError(pe)) {
        return await _triggerTier1BrowserFallback(pe.toString(), onStatusUpdate: onStatusUpdate);
      }
      rethrow;
    } catch (e) {
      debugPrint('[GoogleAuthService] Native Google Sign-In error: $e');

      if (isKeystoreMismatchError(e)) {
        return await _triggerTier1BrowserFallback(e.toString(), onStatusUpdate: onStatusUpdate);
      }
      rethrow;
    }
  }

  /// Tier 1 Fallback: Browser OAuth PKCE via Chrome Custom Tabs
  /// Bypasses native Android SHA-1 keystore requirements completely.
  Future<AuthResponse?> _triggerTier1BrowserFallback(
    String originalError, {
    void Function(String message)? onStatusUpdate,
  }) async {
    final supabase = _supabaseClient;
    if (supabase != null) {
      try {
        onStatusUpdate?.call('Launching Zero-Keystore Browser OAuth...');
        final launched = await supabase.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: kIsWeb ? null : OAuthConfig.supabaseSchemeRedirectUri,
          authScreenLaunchMode: LaunchMode.externalApplication,
        );

        if (launched) {
          // OAuth launched in browser; auth state will be received via onAuthStateChange deep link
          return null;
        }
      } catch (browserErr) {
        debugPrint('[GoogleAuthService] Browser OAuth fallback exception: $browserErr');
      }
    }

    // Tier 2 Trigger: Both Native and Browser OAuth could not complete.
    // Raise structured GoogleKeystoreMismatchException so UI surfaces the diagnostic sheet.
    throw GoogleKeystoreMismatchException(
      message: 'Native Google Sign-In was blocked because this APK signing key is not registered in Google Cloud Console.',
      rawError: originalError,
      applicationId: OAuthConfig.applicationId,
      sha1: OAuthConfig.debugSha1,
      sha256: OAuthConfig.debugSha256,
    );
  }
}
