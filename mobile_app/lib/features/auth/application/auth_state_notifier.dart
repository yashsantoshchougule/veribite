import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_auth_service.dart';

/// Provider for SupabaseAuthService instance
final supabaseAuthServiceProvider = Provider<SupabaseAuthService>((ref) {
  return SupabaseAuthService();
});

/// Stream provider for listening to live auth state changes (login, logout, token refresh)
final authStateStreamProvider = StreamProvider<AuthState?>((ref) {
  final service = ref.watch(supabaseAuthServiceProvider);
  return service.authStateChanges ?? const Stream.empty();
});

/// Provider for the current user (if logged in)
final currentUserProvider = Provider<User?>((ref) {
  // Triggers re-read whenever auth state changes
  ref.watch(authStateStreamProvider);
  return ref.watch(supabaseAuthServiceProvider).currentUser;
});

/// Provider for checking whether the user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});

