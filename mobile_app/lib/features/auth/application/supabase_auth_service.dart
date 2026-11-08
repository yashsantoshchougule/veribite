import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/oauth_config.dart';
import 'google_auth_service.dart';

export 'google_auth_service.dart' show GoogleKeystoreMismatchException;

/// Service managing Supabase Cloud Authentication for VeriBite.
class SupabaseAuthService {
  final SupabaseClient? _injectedClient;

  SupabaseAuthService({SupabaseClient? client}) : _injectedClient = client;

  SupabaseClient? get _client {
    if (_injectedClient != null) {
      return _injectedClient;
    }
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  /// Whether Supabase client is available and initialized
  bool get isAvailable => _client != null;

  /// Current authenticated user (if any)
  User? get currentUser => _client?.auth.currentUser;

  /// Current active session (if any)
  Session? get currentSession => _client?.auth.currentSession;

  /// Whether a user is currently signed in
  bool get isAuthenticated => currentUser != null;

  /// Stream of authentication state changes
  Stream<AuthState>? get authStateChanges => _client?.auth.onAuthStateChange;

  /// Sign in with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw const AuthException('Supabase client is not initialized');
    }

    try {
      final response = await client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Sign up / Register new account with 5 fields
  Future<AuthResponse> signUp({
    required String fullName,
    required String username,
    required String email,
    required String password,
  }) async {
    final client = _client;
    if (client == null) {
      throw const AuthException('Supabase client is not initialized');
    }

    try {
      final response = await client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {
          'full_name': fullName.trim(),
          'username': username.trim().toLowerCase(),
        },
      );
      return response;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Send password reset link to user's Gmail
  Future<void> resetPasswordForEmail(String email) async {
    final client = _client;
    if (client == null) {
      throw const AuthException('Supabase client is not initialized');
    }

    try {
      await client.auth.resetPasswordForEmail(
        email.trim(),
      );
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Sign in with Google with 2-tier fallback (Native -> Browser PKCE OAuth)
  Future<bool> signInWithGoogle({void Function(String message)? onStatusUpdate}) async {
    final client = _client;
    final googleAuth = GoogleAuthService(supabaseClient: client);

    try {
      final res = await googleAuth.signInWithGoogle(onStatusUpdate: onStatusUpdate);
      return res != null || isAuthenticated;
    } on GoogleKeystoreMismatchException {
      rethrow;
    } on AuthException {
      rethrow;
    } catch (e) {
      if (GoogleAuthService.isKeystoreMismatchError(e)) {
        throw GoogleKeystoreMismatchException(
          message: 'Google Sign-In blocked by keystore fingerprint.',
          rawError: e.toString(),
        );
      }
      throw AuthException(e.toString());
    }
  }

  /// Explicit Tier 1 Browser OAuth PKCE flow (Chrome Custom Tabs)
  Future<bool> signInWithBrowserOAuth() async {
    final client = _client;
    if (client == null) {
      throw const AuthException('Supabase client is not initialized');
    }

    try {
      final success = await client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? null : OAuthConfig.supabaseSchemeRedirectUri,
        authScreenLaunchMode: LaunchMode.externalApplication,
      );
      return success;
    } on AuthException {
      rethrow;
    } catch (e) {
      throw AuthException(e.toString());
    }
  }

  /// Sign out current session
  Future<void> signOut() async {
    final client = _client;
    if (client == null) return;

    try {
      await client.auth.signOut();
    } catch (e) {
      debugPrint('Supabase sign-out warning: $e');
    }
  }
}

