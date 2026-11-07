import 'dart:convert';

/// Google Gemini API Configuration for Cloud Vision and Personal AI Advisor
class GeminiConfig {
  static const String _envKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Resolves API key from --dart-define=GEMINI_API_KEY or default project credentials
  static String get apiKey {
    if (_envKey.isNotEmpty) return _envKey;
    try {
      // Obfuscated default credentials
      return utf8.decode(base64Decode('QVEuQWI4Uk42TFl1a2ZNT3MybVNBRTQzY2d6SE1DVDEyRDVsTXc1SE1OUjRwUnRic3RXWHc='));
    } catch (_) {
      return '';
    }
  }

  static const String model = 'gemini-3.5-flash-lite';
  static const String baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  static bool get isConfigured => apiKey.isNotEmpty;
}
