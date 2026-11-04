/// Supabase Cloud PostgreSQL & Authentication Configuration
class SupabaseConfig {
  static const String supabaseUrl = 'https://yfexwjkayfwnrcmsqvzf.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_WohnxcPz_g0ueHArzdawpg_fW_j0fRy';
  static const String googleClientId = '999210457582-56ulttc90n6397clchr5kr3fa9fol12r.apps.googleusercontent.com';

  /// Returns true if valid Supabase credentials are configured
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_SUPABASE_URL');
}

