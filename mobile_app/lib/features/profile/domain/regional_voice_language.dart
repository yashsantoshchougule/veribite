/// Supported Regional Voice Read-Out Languages for VeriBite.
/// Normalizes display names, ISO codes, and TTS locale identifiers.
enum RegionalVoiceLanguage {
  english('en', 'en-IN', 'English'),
  hindi('hi', 'hi-IN', 'Hindi (हिंदी)'),
  marathi('mr', 'mr-IN', 'Marathi (मराठी)'),
  tamil('ta', 'ta-IN', 'Tamil (தமிழ்)'),
  telugu('te', 'te-IN', 'Telugu (తెలుగు)');

  final String code;
  final String localeCode;
  final String displayName;

  const RegionalVoiceLanguage(this.code, this.localeCode, this.displayName);

  /// Resolves any input string (code, locale code, or display name) to a valid [RegionalVoiceLanguage].
  /// Defaults safely to [RegionalVoiceLanguage.english] if unrecognized.
  static RegionalVoiceLanguage fromString(String? input) {
    if (input == null || input.trim().isEmpty) {
      return RegionalVoiceLanguage.english;
    }

    final normalized = input.trim().toLowerCase();

    // Specific Indian language alias checks
    if (normalized == 'hi' ||
        normalized == 'hi-in' ||
        normalized.contains('hindi') ||
        normalized.contains('हिंदी')) {
      return RegionalVoiceLanguage.hindi;
    }
    if (normalized == 'mr' ||
        normalized == 'mr-in' ||
        normalized.contains('marathi') ||
        normalized.contains('मराठी')) {
      return RegionalVoiceLanguage.marathi;
    }
    if (normalized == 'ta' ||
        normalized == 'ta-in' ||
        normalized.contains('tamil') ||
        normalized.contains('தமிழ்')) {
      return RegionalVoiceLanguage.tamil;
    }
    if (normalized == 'te' ||
        normalized == 'te-in' ||
        normalized.contains('telugu') ||
        normalized.contains('తెలుగు')) {
      return RegionalVoiceLanguage.telugu;
    }
    if (normalized == 'en' ||
        normalized == 'en-in' ||
        normalized == 'en-us' ||
        normalized.contains('english')) {
      return RegionalVoiceLanguage.english;
    }

    for (final lang in RegionalVoiceLanguage.values) {
      if (normalized == lang.code ||
          normalized == lang.localeCode.toLowerCase() ||
          normalized == lang.displayName.toLowerCase()) {
        return lang;
      }
    }

    return RegionalVoiceLanguage.english;
  }
}
