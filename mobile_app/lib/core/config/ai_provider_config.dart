import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';

enum AiProvider {
  gemini,
  groq,
  openRouter,
  backendProxy,
  onDeviceOcr,
}

/// Central API Configuration for Google Gemini, Groq Cloud, OpenRouter,
/// with per-provider rate-limit cooldown tracking, quota header inspection,
/// and independent model cascades.
class AiProviderConfig {
  // ---------------------------------------------------------------------------
  // Google Gemini Configuration
  // ---------------------------------------------------------------------------
  static const String _envGeminiKey = String.fromEnvironment('GEMINI_API_KEY');
  static const String _envGeminiKeys = String.fromEnvironment('GEMINI_API_KEYS');
  static int _currentGeminiKeyIndex = 0;

  static String get _defaultGeminiKey {
    try {
      return utf8.decode(base64Decode('QVEuQWI4Uk42TFo5b0I5VExXU3d4cmtaQURHWEJVcU9fbVQ3QUQteTI2SWNNSTFlZ0lRemc='));
    } catch (_) {
      return '';
    }
  }

  static List<String> get geminiApiKeys {
    final list = <String>[];
    if (_envGeminiKeys.isNotEmpty) {
      list.addAll(_envGeminiKeys.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty));
    }
    if (_envGeminiKey.isNotEmpty && !list.contains(_envGeminiKey)) {
      list.add(_envGeminiKey);
    }
    if (list.isEmpty) {
      final def = _defaultGeminiKey;
      if (def.isNotEmpty) list.add(def);
    }
    return list;
  }

  static String get activeGeminiApiKey {
    final keys = geminiApiKeys;
    if (keys.isEmpty) return '';
    if (_currentGeminiKeyIndex >= keys.length) _currentGeminiKeyIndex = 0;
    return keys[_currentGeminiKeyIndex];
  }

  static bool rotateGeminiKey() {
    final keys = geminiApiKeys;
    if (keys.length <= 1) return false;
    _currentGeminiKeyIndex = (_currentGeminiKeyIndex + 1) % keys.length;
    debugPrint('[AiProviderConfig] Rotated to Gemini Key index #$_currentGeminiKeyIndex');
    return true;
  }

  static const String geminiBaseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  static const List<String> geminiVisionModels = [
    'gemini-2.5-flash',
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash',
    'gemini-2.0-flash-lite',
    'gemini-1.5-flash',
    'gemini-flash-latest',
  ];

  static const List<String> geminiAdvisorModels = [
    'gemini-2.0-flash-lite',
    'gemini-2.5-flash-lite',
    'gemini-2.5-flash',
    'gemini-flash-lite-latest',
    'gemini-flash-latest',
  ];

  // ---------------------------------------------------------------------------
  // Groq Cloud Configuration
  // ---------------------------------------------------------------------------
  static const String _envGroqKey = String.fromEnvironment('GROQ_API_KEY');
  static const String _envGroqKeys = String.fromEnvironment('GROQ_API_KEYS');
  static int _currentGroqKeyIndex = 0;
  static List<String> _testGroqKeys = [];
  static void setTestGroqKeys(List<String> keys) => _testGroqKeys = keys;

  static List<String> get groqApiKeys {
    if (_testGroqKeys.isNotEmpty) return _testGroqKeys;
    final list = <String>[];
    if (_envGroqKeys.isNotEmpty) {
      list.addAll(_envGroqKeys.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty));
    }
    if (_envGroqKey.isNotEmpty && !list.contains(_envGroqKey)) {
      list.add(_envGroqKey);
    }
    return list;
  }

  static String get activeGroqApiKey {
    final keys = groqApiKeys;
    if (keys.isEmpty) return '';
    if (_currentGroqKeyIndex >= keys.length) _currentGroqKeyIndex = 0;
    return keys[_currentGroqKeyIndex];
  }

  static bool rotateGroqKey() {
    final keys = groqApiKeys;
    if (keys.length <= 1) return false;
    _currentGroqKeyIndex = (_currentGroqKeyIndex + 1) % keys.length;
    debugPrint('[AiProviderConfig] Rotated to Groq Key index #$_currentGroqKeyIndex');
    return true;
  }

  static const String groqApiUrl = 'https://api.groq.com/openai/v1/chat/completions';

  static const String groqPrimaryVisionModel = 'qwen/qwen3.8-27b';
  static const List<String> groqVisionModels = [
    'qwen/qwen3.8-27b',
    'meta-llama/llama-4-scout-17b-16e-instruct',
    'meta-llama/llama-4-maverick-17b-128e-instruct',
  ];

  static const List<String> groqAdvisorModels = [
    'llama-3.3-70b-versatile',
    'meta-llama/llama-4-scout-17b-16e-instruct',
  ];

  // ---------------------------------------------------------------------------
  // OpenRouter Configuration (Tier 3 Spillover)
  // ---------------------------------------------------------------------------
  static const String _envOpenRouterKey = String.fromEnvironment('OPENROUTER_API_KEY');
  static const String _envOpenRouterKeys = String.fromEnvironment('OPENROUTER_API_KEYS');
  static int _currentOpenRouterKeyIndex = 0;
  static List<String> _testOpenRouterKeys = [];
  static void setTestOpenRouterKeys(List<String> keys) => _testOpenRouterKeys = keys;

  static List<String> get openRouterApiKeys {
    if (_testOpenRouterKeys.isNotEmpty) return _testOpenRouterKeys;
    final list = <String>[];
    if (_envOpenRouterKeys.isNotEmpty) {
      list.addAll(_envOpenRouterKeys.split(',').map((k) => k.trim()).where((k) => k.isNotEmpty));
    }
    if (_envOpenRouterKey.isNotEmpty && !list.contains(_envOpenRouterKey)) {
      list.add(_envOpenRouterKey);
    }
    return list;
  }

  static String get activeOpenRouterApiKey {
    final keys = openRouterApiKeys;
    if (keys.isEmpty) return '';
    if (_currentOpenRouterKeyIndex >= keys.length) _currentOpenRouterKeyIndex = 0;
    return keys[_currentOpenRouterKeyIndex];
  }

  static bool rotateOpenRouterKey() {
    final keys = openRouterApiKeys;
    if (keys.length <= 1) return false;
    _currentOpenRouterKeyIndex = (_currentOpenRouterKeyIndex + 1) % keys.length;
    return true;
  }

  static const String openRouterApiUrl = 'https://openrouter.ai/api/v1/chat/completions';

  static const List<String> openRouterVisionModels = [
    'google/gemini-2.0-flash-exp:free',
    'qwen/qwen2.5-vl-72b-instruct:free',
    'meta-llama/llama-3.3-70b-instruct:free',
  ];

  // ---------------------------------------------------------------------------
  // Rate-Limit & Cooldown Registry
  // Key format: "$provider:$apiKey:$model"
  // ---------------------------------------------------------------------------
  static final Map<String, DateTime> _cooldownRegistry = {};
  static final math.Random _random = math.Random();

  static String _buildBucketKey(AiProvider provider, String apiKey, String model) {
    final keyPrefix = apiKey.length >= 8 ? apiKey.substring(0, 8) : apiKey;
    return '${provider.name}:$keyPrefix:$model';
  }

  /// Checks if the specific provider, key, and model combination is currently available (not on cooldown).
  static bool isBucketAvailable(AiProvider provider, String apiKey, String model) {
    final bucketKey = _buildBucketKey(provider, apiKey, model);
    final cooldownUntil = _cooldownRegistry[bucketKey];
    if (cooldownUntil == null) return true;
    if (DateTime.now().isAfter(cooldownUntil)) {
      _cooldownRegistry.remove(bucketKey);
      return true;
    }
    return false;
  }

  /// Marks a bucket on cooldown due to HTTP 429 Too Many Requests or header exhaustion.
  static void markCooldown(
    AiProvider provider,
    String apiKey,
    String model, {
    int? retryAfterSeconds,
    String reason = 'Rate limited',
  }) {
    final baseSeconds = retryAfterSeconds != null && retryAfterSeconds > 0 ? retryAfterSeconds : 45;
    // Add 150ms - 400ms jitter to prevent thundering herd
    final jitterMs = 150 + _random.nextInt(250);
    final cooldownDuration = Duration(seconds: baseSeconds, milliseconds: jitterMs);
    final cooldownUntil = DateTime.now().add(cooldownDuration);

    final bucketKey = _buildBucketKey(provider, apiKey, model);
    _cooldownRegistry[bucketKey] = cooldownUntil;
    debugPrint('[AiProviderConfig] Bucket $bucketKey entered cooldown for ${baseSeconds}s ($reason).');
  }

  /// Inspects response headers proactively and enters cooldown if rate limits are nearing exhaustion.
  static void inspectResponseHeaders(
    AiProvider provider,
    String apiKey,
    String model,
    Map<String, String> headers,
  ) {
    final lowerHeaders = <String, String>{};
    headers.forEach((k, v) => lowerHeaders[k.toLowerCase()] = v);

    // Groq proactive token & request headers
    if (provider == AiProvider.groq) {
      final remainingTokensStr = lowerHeaders['x-ratelimit-remaining-tokens'];
      final remainingReqStr = lowerHeaders['x-ratelimit-remaining-requests'];

      final remainingTokens = remainingTokensStr != null ? int.tryParse(remainingTokensStr) : null;
      final remainingReq = remainingReqStr != null ? int.tryParse(remainingReqStr) : null;

      if ((remainingTokens != null && remainingTokens < 1500) || (remainingReq != null && remainingReq <= 0)) {
        markCooldown(
          provider,
          apiKey,
          model,
          retryAfterSeconds: 30,
          reason: 'Proactive quota exhaustion guard (< 1500 tokens or 0 req left)',
        );
      }
    }
  }

  static bool get isGeminiConfigured => activeGeminiApiKey.isNotEmpty;
  static bool get isGroqConfigured => activeGroqApiKey.isNotEmpty;
  static bool get isOpenRouterConfigured => activeOpenRouterApiKey.isNotEmpty;
  static int get activeCooldownCount => _cooldownRegistry.length;

  /// Clears all cooldowns (useful for unit tests or manual resets)
  static void clearAllCooldowns() {
    _cooldownRegistry.clear();
  }

  /// Gets the remaining cooldown seconds for a specific bucket, or 0 if available
  static int getRemainingCooldownSeconds(AiProvider provider, String apiKey, String model) {
    final bucketKey = _buildBucketKey(provider, apiKey, model);
    final cooldownUntil = _cooldownRegistry[bucketKey];
    if (cooldownUntil == null) return 0;
    final diff = cooldownUntil.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }
}
