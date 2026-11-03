import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/config/supabase_config.dart';
import 'package:mobile_app/features/auth/application/supabase_auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('SupabaseConfig Tests', () {
    test('isConfigured returns true for valid credentials', () {
      expect(SupabaseConfig.isConfigured, isTrue);
      expect(SupabaseConfig.supabaseUrl, contains('supabase.co'));
      expect(SupabaseConfig.supabaseAnonKey, isNotEmpty);
    });
  });

  group('SupabaseAuthService Offline Fallback Tests', () {
    test('isAvailable returns false when client is null', () {
      final service = SupabaseAuthService();
      // In unit test without Supabase.initialize, client is null
      expect(service.isAvailable, isFalse);
      expect(service.currentUser, isNull);
      expect(service.currentSession, isNull);
      expect(service.isAuthenticated, isFalse);
    });

    test('methods throw AuthException gracefully when client is uninitialized', () async {
      final service = SupabaseAuthService();

      expect(
        () => service.signInWithEmail(email: 'test@example.com', password: 'password123'),
        throwsA(isA<AuthException>()),
      );

      expect(
        () => service.signUp(
          fullName: 'John Doe',
          username: 'johndoe',
          email: 'test@example.com',
          password: 'password123',
        ),
        throwsA(isA<AuthException>()),
      );

      expect(
        () => service.resetPasswordForEmail('test@example.com'),
        throwsA(isA<AuthException>()),
      );

      expect(
        () => service.signInWithGoogle(),
        throwsA(isA<AuthException>()),
      );

      // signOut should not throw even if uninitialized
      await service.signOut();
    });
  });
}
