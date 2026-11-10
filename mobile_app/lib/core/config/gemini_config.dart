import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'ai_provider_config.dart';

/// Google Gemini API Configuration for Cloud Vision and Personal AI Advisor
/// with multi-model cascade failover and multi-key rotation on 5G/Wi-Fi.
class GeminiConfig {
  static const String _envKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _envKeys = String.fromEnvironment('GEMINI_API_KEYS');

  static int _currentKeyIndex = 0;

  /// Default project credentials fallback (obfuscated)
  static String get _defaultKey {
    try {
      return utf8.decode(base64Decode('QVEuQWI4Uk42TFo5b0I5VExXU3d4cmtaQURHWEJVcU9fbVQ3QUQteTI2SWNNSTFlZ0lRemc='));
    } catch (_) {
      return '';
    }
  }

  /// All configured API keys for automatic quota rotation
  static List<String> get apiKeys {
    final list = <String>[];
    if (_envKeys.isNotEmpty) {
      final split = _envKeys.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty);
      list.addAll(split);
    }
    if (_envKey.isNotEmpty && !list.contains(_envKey)) {
      list.add(_envKey);
    }
    for (final k in AiProviderConfig.geminiApiKeys) {
      if (!list.contains(k)) list.add(k);
    }
    if (list.isEmpty) {
      final def = _defaultKey;
      if (def.isNotEmpty) list.add(def);
    }
    return list;
  }

  /// Resolves currently active API key from rotation pool
  static String get apiKey {
    final keys = apiKeys;
    if (keys.isEmpty) return '';
    if (_currentKeyIndex >= keys.length) {
      _currentKeyIndex = 0;
    }
    return keys[_currentKeyIndex];
  }

  /// Rotate to the next API key when HTTP 429 or quota limit is reached.
  /// Returns true if rotated to a new key, false if only 1 key configured or wrapped around.
  static bool rotateKey() {
    final keys = apiKeys;
    if (keys.length <= 1) return false;
    _currentKeyIndex = (_currentKeyIndex + 1) % keys.length;
    debugPrint('[GeminiConfig] Rotated to API key index #$_currentKeyIndex (${keys.length} total keys available).');
    return true;
  }

  /// Reset key rotation to primary index
  static void resetKeyRotation() {
    _currentKeyIndex = 0;
  }

  /// Vision Multimodal cascade model list
  static const String visionModel = 'gemini-2.5-flash';
  static const List<String> visionCascadeModels = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-3.1-flash-lite',
    'gemini-flash-lite-latest',
    'gemini-flash-latest',
  ];

  /// Core Advisor models (preserving backwards compatibility)
  static const String model = 'gemini-3.1-flash-lite';
  static const List<String> fallbackModels = [
    'gemini-flash-lite-latest',
    'gemini-flash-latest',
  ];

  /// Complete cascade list
  static List<String> get cascadeModels => visionCascadeModels;

  static const String baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  static bool get isConfigured => apiKey.isNotEmpty;
}
