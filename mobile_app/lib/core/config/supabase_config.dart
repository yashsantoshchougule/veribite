/// Supabase Cloud PostgreSQL & Authentication Configuration
class SupabaseConfig {
  static const String supabaseUrl = 'https://yfexwjkayfwnrcmsqvzf.supabase.co';
  static const String supabaseAnonKey = 'sb_publishable_WohnxcPz_g0ueHArzdawpg_fW_j0fRy';

  /// Returns true if valid Supabase credentials are configured
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty &&
      supabaseAnonKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_SUPABASE_URL');
}

