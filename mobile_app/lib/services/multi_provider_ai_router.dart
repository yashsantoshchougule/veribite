import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../core/config/ai_provider_config.dart';
import '../core/network/backend_endpoint_resolver.dart';
import '../core/vision/on_device_vision_service.dart';

/// Unified Multi-Provider Cloud AI Pool Primary + On-Device Edge OCR Fallback Router
/// Manages high-performance Vision & Advisor queries with:
/// - In-memory JPEG pre-compression (max 1280px @ 75% quality)
/// - Sliding-window in-flight request deduplication
/// - Proactive response header rate-limit & cooldown tracking
/// - 4-Tier multimodal failover: Gemini -> Groq -> OpenRouter/Proxy -> Local ML Kit OCR
class MultiProviderAiRouter {
  final http.Client _client;
  final BackendEndpointResolver _backendResolver;
  final OnDeviceVisionService _onDeviceVisionService;

  // In-flight request deduplication cache: key -> Future<Map<String, dynamic>?>
  final Map<String, ({DateTime timestamp, Future<dynamic> future})> _inFlightRequests = {};

  MultiProviderAiRouter({
    http.Client? httpClient,
    BackendEndpointResolver? backendResolver,
    OnDeviceVisionService? onDeviceVisionService,
  })  : _client = httpClient ?? http.Client(),
        _backendResolver = backendResolver ?? BackendEndpointResolver.instance,
        _onDeviceVisionService = onDeviceVisionService ?? OnDeviceVisionService();

  static String _computeSampleHash(List<int> bytes) {
    int hash = 0x811c9dc5;
    final len = math.min(1024, bytes.length);
    for (int i = 0; i < len; i++) {
      hash = (hash ^ bytes[i]) * 0x01000193;
      hash = hash & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }

  // ---------------------------------------------------------------------------
  // 1. Image Payload Pre-Compression
  // Resizes to max 1280px on longest side at 75% JPEG quality (~120KB-180KB).
  // ---------------------------------------------------------------------------
  static Uint8List precompressFrame(List<int> rawBytes, {int maxDimension = 1280, int quality = 75}) {
    if (rawBytes.length < 50) return Uint8List.fromList(rawBytes);

    try {
      final decoded = img.decodeImage(Uint8List.fromList(rawBytes));
      if (decoded == null) return Uint8List.fromList(rawBytes);

      img.Image processed = decoded;
      final int maxSide = math.max(decoded.width, decoded.height);

      if (maxSide > maxDimension) {
        if (decoded.width >= decoded.height) {
          processed = img.copyResize(decoded, width: maxDimension);
        } else {
          processed = img.copyResize(decoded, height: maxDimension);
        }
      }

      final compressedBytes = img.encodeJpg(processed, quality: quality);
      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      debugPrint('[MultiProviderAiRouter] In-memory image compression notice: $e');
      return Uint8List.fromList(rawBytes);
    }
  }

  // ---------------------------------------------------------------------------
  // 2. In-Flight Request Deduplication
  // ---------------------------------------------------------------------------
  Future<T?> _deduplicate<T>(String key, Future<T?> Function() action) {
    final now = DateTime.now();

    // Expire entries older than 2.5 seconds
    _inFlightRequests.removeWhere((k, v) => now.difference(v.timestamp).inMilliseconds > 2500);

    if (_inFlightRequests.containsKey(key)) {
      debugPrint('[MultiProviderAiRouter] In-flight deduplication hit for key: $key');
      return _inFlightRequests[key]!.future as Future<T?>;
    }

    final future = action();
    _inFlightRequests[key] = (timestamp: now, future: future);
    return future;
  }

  // ---------------------------------------------------------------------------
  // 3. Vision Extraction: 4-Tier Multimodal Pool Cascade
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> analyzePackagingPhoto({
    required List<List<int>> frames,
    String? hintBarcode,
  }) async {
    if (frames.isEmpty) return null;

    // Pick largest frame
    List<int> bestFrame = frames.first;
    for (final frame in frames) {
      if (frame.length > bestFrame.length) {
        bestFrame = frame;
      }
    }

    if (bestFrame.length < 50) return null;

    // Pre-compress best frame in memory
    final compressedFrame = precompressFrame(bestFrame);
    final base64Image = base64Encode(compressedFrame);
    final prompt = _buildVisionExtractionPrompt(hintBarcode: hintBarcode);

    // Generate deduplication fingerprint (fast FNV-1a hash prefix of compressed bytes + hint)
    final frameHash = _computeSampleHash(compressedFrame);
    final dedupeKey = 'vision:${hintBarcode ?? ""}:$frameHash';

    return _deduplicate(dedupeKey, () async {
      // -------------------------------------------------------------------------
      // TIER 1: Google Gemini Vision Pool (Co-Primary A)
      // -------------------------------------------------------------------------
      final geminiResult = await _queryGeminiVision(base64Image, prompt, hintBarcode);
      if (geminiResult != null) {
        geminiResult['source'] = 'gemini_vision';
        return geminiResult;
      }

      // -------------------------------------------------------------------------
      // TIER 2: Groq Cloud Vision Pool (Co-Primary B)
      // -------------------------------------------------------------------------
      final groqResult = await _queryGroqVision(base64Image, prompt);
      if (groqResult != null) {
        groqResult['source'] = 'groq_vision';
        return groqResult;
      }

      // -------------------------------------------------------------------------
      // TIER 3: Emergency Cloud Spillover (OpenRouter & Backend FastAPI Proxy)
      // -------------------------------------------------------------------------
      final openRouterResult = await _queryOpenRouterVision(base64Image, prompt);
      if (openRouterResult != null) {
        openRouterResult['source'] = 'openrouter_spillover';
        return openRouterResult;
      }

      final proxyResult = await _queryBackendProxyVision(compressedFrame);
      if (proxyResult != null) {
        proxyResult['source'] = 'backend_proxy';
        return proxyResult;
      }

      // -------------------------------------------------------------------------
      // TIER 4: Offline / Hardware Safety Net (Edge Google ML Kit OCR)
      // -------------------------------------------------------------------------
      debugPrint('[MultiProviderAiRouter] Cloud AI pools exhausted or offline. Triggering Tier 4 Edge OCR...');
      try {
        final ocrResult = await _onDeviceVisionService.analyzeFrames([compressedFrame]);
        if (ocrResult != null) {
          ocrResult['source'] = 'on_device_vision';
          return ocrResult;
        }
      } catch (e) {
        debugPrint('[MultiProviderAiRouter] Tier 4 On-Device Edge OCR notice: $e');
      }

      return null;
    });
  }

  // ---------------------------------------------------------------------------
  // Tier 1: Gemini Multimodal Vision Implementation
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> _queryGeminiVision(
    String base64Image,
    String prompt,
    String? hintBarcode,
  ) async {
    final keys = AiProviderConfig.geminiApiKeys;
    if (keys.isEmpty) return null;

    final models = AiProviderConfig.geminiVisionModels;
    final maxKeyAttempts = keys.length.clamp(1, 4);

    for (int keyAttempt = 0; keyAttempt < maxKeyAttempts; keyAttempt++) {
      final apiKey = AiProviderConfig.activeGeminiApiKey;
      if (apiKey.isEmpty) break;

      for (final model in models) {
        if (!AiProviderConfig.isBucketAvailable(AiProvider.gemini, apiKey, model)) {
          continue;
        }

        // Optimized payload with thinkingBudget: 0 for 2.5 models
        final supportsThinkingConfig = model.contains('2.5');
        final Map<String, dynamic> generationConfig = {
          'temperature': 0.1,
          'responseMimeType': 'application/json',
          if (supportsThinkingConfig) 'thinkingConfig': {'thinkingBudget': 0},
        };

        final requestBody = {
          'contents': [
            {
              'parts': [
                {'text': prompt},
                {
                  'inline_data': {
                    'mime_type': 'image/jpeg',
                    'data': base64Image,
                  }
                }
              ]
            }
          ],
          'generationConfig': generationConfig,
        };

        try {
          final uri = Uri.parse('${AiProviderConfig.geminiBaseUrl}/$model:generateContent?key=$apiKey');
          final response = await _client
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(requestBody),
              )
              .timeout(const Duration(seconds: 7));

          AiProviderConfig.inspectResponseHeaders(AiProvider.gemini, apiKey, model, response.headers);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final content = candidates[0]['content'];
              final parts = content['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                final rawJsonText = parts[0]['text']?.toString() ?? '';
                final parsed = _parseJsonContent(rawJsonText);
                if (parsed != null) return parsed;
              }
            }
          } else if (response.statusCode == 429) {
            final retrySec = _parseRetryAfterSeconds(response.headers);
            AiProviderConfig.markCooldown(AiProvider.gemini, apiKey, model, retryAfterSeconds: retrySec);
            AiProviderConfig.rotateGeminiKey();
            break; // Try next key
          } else {
            debugPrint('[MultiProviderAiRouter] Gemini error ($model): HTTP ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('[MultiProviderAiRouter] Gemini $model call notice: $e');
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Tier 2: Groq Cloud Vision Implementation (console.groq.com/docs/vision)
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> _queryGroqVision(String base64Image, String prompt) async {
    final keys = AiProviderConfig.groqApiKeys;
    if (keys.isEmpty) return null;

    final models = AiProviderConfig.groqVisionModels;
    final maxKeyAttempts = keys.length.clamp(1, 4);

    for (int keyAttempt = 0; keyAttempt < maxKeyAttempts; keyAttempt++) {
      final apiKey = AiProviderConfig.activeGroqApiKey;
      if (apiKey.isEmpty) break;

      for (final model in models) {
        if (!AiProviderConfig.isBucketAvailable(AiProvider.groq, apiKey, model)) {
          continue;
        }

        final requestBody = {
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {
                    'url': 'data:image/jpeg;base64,$base64Image',
                  }
                }
              ]
            }
          ],
          'temperature': 0.1,
          'response_format': {'type': 'json_object'},
        };

        try {
          final uri = Uri.parse(AiProviderConfig.groqApiUrl);
          final response = await _client
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $apiKey',
                },
                body: jsonEncode(requestBody),
              )
              .timeout(const Duration(seconds: 6));

          AiProviderConfig.inspectResponseHeaders(AiProvider.groq, apiKey, model, response.headers);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final choices = data['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final message = choices[0]['message'];
              final rawContent = message['content']?.toString() ?? '';
              final parsed = _parseJsonContent(rawContent);
              if (parsed != null) return parsed;
            }
          } else if (response.statusCode == 429) {
            final retrySec = _parseRetryAfterSeconds(response.headers);
            AiProviderConfig.markCooldown(AiProvider.groq, apiKey, model, retryAfterSeconds: retrySec);
            AiProviderConfig.rotateGroqKey();
            break;
          } else {
            debugPrint('[MultiProviderAiRouter] Groq Vision ($model) error: HTTP ${response.statusCode} - ${response.body}');
          }
        } catch (e) {
          debugPrint('[MultiProviderAiRouter] Groq Vision $model notice: $e');
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Tier 3: OpenRouter Vision Spillover with Native models Gateway Array
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> _queryOpenRouterVision(String base64Image, String prompt) async {
    final apiKey = AiProviderConfig.activeOpenRouterApiKey;
    if (apiKey.isEmpty) return null;

    const primaryModel = 'google/gemini-2.0-flash-exp:free';
    if (!AiProviderConfig.isBucketAvailable(AiProvider.openRouter, apiKey, primaryModel)) {
      return null;
    }

    final requestBody = {
      'model': primaryModel,
      'models': AiProviderConfig.openRouterVisionModels,
      'messages': [
        {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': prompt},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,$base64Image',
              }
            }
          ]
        }
      ],
      'temperature': 0.1,
      'response_format': {'type': 'json_object'},
    };

    try {
      final uri = Uri.parse(AiProviderConfig.openRouterApiUrl);
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
              'HTTP-Referer': 'https://veribite.app',
              'X-Title': 'VeriBite Food Safety',
            },
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          final content = choices[0]['message']['content']?.toString() ?? '';
          return _parseJsonContent(content);
        }
      } else if (response.statusCode == 429) {
        final retrySec = _parseRetryAfterSeconds(response.headers);
        AiProviderConfig.markCooldown(AiProvider.openRouter, apiKey, primaryModel, retryAfterSeconds: retrySec);
      }
    } catch (e) {
      debugPrint('[MultiProviderAiRouter] OpenRouter Vision notice: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Tier 3b: Backend FastAPI Cloud Vision Proxy
  // ---------------------------------------------------------------------------
  Future<Map<String, dynamic>?> _queryBackendProxyVision(List<int> compressedFrame) async {
    try {
      final backendBaseUrl = await _backendResolver.resolveActiveBackendUrl();
      if (backendBaseUrl == null || backendBaseUrl.isEmpty) return null;

      final uri = Uri.parse('$backendBaseUrl/api/v1/scan/vision');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes('images', compressedFrame, filename: 'frame_0.jpg'),
      );

      final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 4));
      if (streamedResponse.statusCode == 200) {
        final respStr = await streamedResponse.stream.bytesToString();
        final decoded = jsonDecode(respStr);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      }
    } catch (e) {
      debugPrint('[MultiProviderAiRouter] Backend proxy vision notice: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 4. Advisor Chat: Multi-Provider Co-Routing
  // Co-routes across Groq llama-3.3-70b-versatile and Gemini 2.0-flash-lite
  // ---------------------------------------------------------------------------
  Future<String?> askAdvisor({
    required String systemPrompt,
    required String userMessage,
    List<Map<String, String>> history = const [],
  }) async {
    final dedupeKey = 'chat:${userMessage.trim().toLowerCase()}';

    return _deduplicate(dedupeKey, () async {
      // 1. Try Groq LPU Chat (30 RPM / 14,400 RPD) first to protect Gemini Vision quota!
      final groqChat = await _queryGroqAdvisor(systemPrompt, userMessage, history);
      if (groqChat != null && groqChat.isNotEmpty) return groqChat;

      // 2. Try Google Gemini Flash Lite
      final geminiChat = await _queryGeminiAdvisor(systemPrompt, userMessage, history);
      if (geminiChat != null && geminiChat.isNotEmpty) return geminiChat;

      // 3. Try OpenRouter Spillover
      final openRouterChat = await _queryOpenRouterAdvisor(systemPrompt, userMessage, history);
      if (openRouterChat != null && openRouterChat.isNotEmpty) return openRouterChat;

      return null;
    });
  }

  Future<String?> _queryGroqAdvisor(
    String systemPrompt,
    String userMessage,
    List<Map<String, String>> history,
  ) async {
    final keys = AiProviderConfig.groqApiKeys;
    if (keys.isEmpty) return null;

    final models = AiProviderConfig.groqAdvisorModels;
    final maxKeyAttempts = keys.length.clamp(1, 4);

    for (int keyAttempt = 0; keyAttempt < maxKeyAttempts; keyAttempt++) {
      final apiKey = AiProviderConfig.activeGroqApiKey;
      if (apiKey.isEmpty) break;

      for (final model in models) {
        if (!AiProviderConfig.isBucketAvailable(AiProvider.groq, apiKey, model)) continue;

        final messages = <Map<String, dynamic>>[
          {'role': 'system', 'content': systemPrompt},
          for (final h in history) {'role': h['role'] ?? 'user', 'content': h['content'] ?? ''},
          {'role': 'user', 'content': userMessage},
        ];

        try {
          final uri = Uri.parse(AiProviderConfig.groqApiUrl);
          final response = await _client
              .post(
                uri,
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $apiKey',
                },
                body: jsonEncode({
                  'model': model,
                  'messages': messages,
                  'temperature': 0.2,
                  'max_tokens': 1024,
                }),
              )
              .timeout(const Duration(seconds: 5));

          AiProviderConfig.inspectResponseHeaders(AiProvider.groq, apiKey, model, response.headers);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final choices = data['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              return choices[0]['message']['content']?.toString().trim();
            }
          } else if (response.statusCode == 429) {
            final retrySec = _parseRetryAfterSeconds(response.headers);
            AiProviderConfig.markCooldown(AiProvider.groq, apiKey, model, retryAfterSeconds: retrySec);
            AiProviderConfig.rotateGroqKey();
            break;
          }
        } catch (e) {
          debugPrint('[MultiProviderAiRouter] Groq Advisor ($model) notice: $e');
        }
      }
    }
    return null;
  }

  Future<String?> _queryGeminiAdvisor(
    String systemPrompt,
    String userMessage,
    List<Map<String, String>> history,
  ) async {
    final keys = AiProviderConfig.geminiApiKeys;
    if (keys.isEmpty) return null;

    final models = AiProviderConfig.geminiAdvisorModels;
    final maxKeyAttempts = keys.length.clamp(1, 4);

    for (int keyAttempt = 0; keyAttempt < maxKeyAttempts; keyAttempt++) {
      final apiKey = AiProviderConfig.activeGeminiApiKey;
      if (apiKey.isEmpty) break;

      for (final model in models) {
        if (!AiProviderConfig.isBucketAvailable(AiProvider.gemini, apiKey, model)) continue;

        final supportsThinking = model.contains('2.5');
        final Map<String, dynamic> generationConfig = {
          'temperature': 0.2,
          if (supportsThinking) 'thinkingConfig': {'thinkingBudget': 0},
        };

        final requestBody = {
          'system_instruction': {
            'parts': [
              {'text': systemPrompt}
            ]
          },
          'contents': [
            for (final h in history)
              {
                'role': h['role'] == 'user' ? 'user' : 'model',
                'parts': [
                  {'text': h['content'] ?? ''}
                ]
              },
            {
              'role': 'user',
              'parts': [
                {'text': userMessage}
              ]
            }
          ],
          'generationConfig': generationConfig,
        };

        try {
          final uri = Uri.parse('${AiProviderConfig.geminiBaseUrl}/$model:generateContent?key=$apiKey');
          final response = await _client
              .post(
                uri,
                headers: {'Content-Type': 'application/json'},
                body: jsonEncode(requestBody),
              )
              .timeout(const Duration(seconds: 5));

          AiProviderConfig.inspectResponseHeaders(AiProvider.gemini, apiKey, model, response.headers);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final candidates = data['candidates'] as List?;
            if (candidates != null && candidates.isNotEmpty) {
              final parts = candidates[0]['content']['parts'] as List?;
              if (parts != null && parts.isNotEmpty) {
                return parts[0]['text']?.toString().trim();
              }
            }
          } else if (response.statusCode == 429) {
            final retrySec = _parseRetryAfterSeconds(response.headers);
            AiProviderConfig.markCooldown(AiProvider.gemini, apiKey, model, retryAfterSeconds: retrySec);
            AiProviderConfig.rotateGeminiKey();
            break;
          }
        } catch (e) {
          debugPrint('[MultiProviderAiRouter] Gemini Advisor ($model) notice: $e');
        }
      }
    }
    return null;
  }

  Future<String?> _queryOpenRouterAdvisor(
    String systemPrompt,
    String userMessage,
    List<Map<String, String>> history,
  ) async {
    final apiKey = AiProviderConfig.activeOpenRouterApiKey;
    if (apiKey.isEmpty) return null;

    const model = 'meta-llama/llama-3.3-70b-instruct:free';
    if (!AiProviderConfig.isBucketAvailable(AiProvider.openRouter, apiKey, model)) return null;

    try {
      final uri = Uri.parse(AiProviderConfig.openRouterApiUrl);
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
              'HTTP-Referer': 'https://veribite.app',
              'X-Title': 'VeriBite AI Advisor',
            },
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'system', 'content': systemPrompt},
                for (final h in history) {'role': h['role'] ?? 'user', 'content': h['content'] ?? ''},
                {'role': 'user', 'content': userMessage},
              ],
              'temperature': 0.2,
              'max_tokens': 1024,
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final choices = data['choices'] as List?;
        if (choices != null && choices.isNotEmpty) {
          return choices[0]['message']['content']?.toString().trim();
        }
      } else if (response.statusCode == 429) {
        final retrySec = _parseRetryAfterSeconds(response.headers);
        AiProviderConfig.markCooldown(AiProvider.openRouter, apiKey, model, retryAfterSeconds: retrySec);
      }
    } catch (e) {
      debugPrint('[MultiProviderAiRouter] OpenRouter Advisor notice: $e');
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Helpers: Parsing & Prompts
  // ---------------------------------------------------------------------------
  int? _parseRetryAfterSeconds(Map<String, String> headers) {
    final lower = <String, String>{};
    headers.forEach((k, v) => lower[k.toLowerCase()] = v);
    final val = lower['retry-after'];
    if (val != null) {
      final sec = int.tryParse(val);
      if (sec != null && sec > 0) return sec;
    }
    return null;
  }

  Map<String, dynamic>? _parseJsonContent(String rawText) {
    var clean = rawText.trim();
    if (clean.startsWith('```')) {
      final lines = clean.split('\n');
      if (lines.length > 2) {
        clean = lines.sublist(1, lines.length - 1).join('\n').trim();
      }
    }
    try {
      final decoded = jsonDecode(clean);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  String _buildVisionExtractionPrompt({String? hintBarcode}) {
    return '''
You are an expert food safety, toxicology, and clinical nutrition analyst.
Analyze this photo of a packaged food product, bottle, can, or nutrition facts label.

CRITICAL INSTRUCTIONS FOR INDIAN FOOD PACKAGING:
- Indian packaging frequently splits the nutrition table into TWO SIDE-BY-SIDE COLUMNS (e.g. Left table: Energy, Total Fat, Saturated Fat, Trans Fat, Carbohydrates; Right table: Total Sugar, Added Sugar, Protein, Cholesterol, Sodium, Dietary Fibre). Carefully read both columns!
- ALWAYS extract values from the "100g" / "Per 100g" column. DO NOT extract from "% RDA per 100g" or "% RDA per Serve" percentage columns!
- If "% RDA per 100g" and "% RDA per Serve" are printed, also extract them as "rda_per_100g" and "rda_per_serve" so exact serving size can be calculated: (rda_per_serve / rda_per_100g) * 100.

Extract the exact information printed on the package:
1. "product_name": Full product name (e.g., "Kreamy Magic Cream Pav", "Amul Butter", "Siddhivinayak Mango Pickle").
2. "brand_name": Manufacturer brand (e.g., "Kwality", "Amul", "Britannia", "Siddhivinayak").
3. "category": Food category (e.g., "Bakery & Breads", "Dairy & Cheese", "Pickles & Chutneys", "Snacks & Namkeen").
4. "serving_size_g": Serving size in grams or ml (default to 30.0 if not specified).
5. "pack_weight_g": Net pack weight in grams or ml (e.g., 60.0, 100.0, 200.0).
6. "nutrition": Object with numeric values per 100g:
   - "energy_kcal": Energy in kcal per 100g (e.g., 368.00)
   - "energy_kj": Energy in kJ per 100g (if kcal printed, multiply kcal by 4.184)
   - "sugar_g_per_100g": Total sugars in grams per 100g
   - "added_sugar_g_per_100g": Added sugars in grams per 100g
   - "total_fat_g_per_100g": Total fat in grams per 100g
   - "sat_fat_g_per_100g": Saturated fat in grams per 100g
   - "trans_fat_g_per_100g": Trans fat in grams per 100g
   - "carbohydrates_g_per_100g": Total carbohydrate in grams per 100g
   - "protein_g": Protein in grams per 100g
   - "sodium_mg_per_100g": Sodium in mg per 100g (if salt in g printed, salt_g * 400)
   - "cholesterol_mg_per_100g": Cholesterol in mg per 100g
   - "fiber_g": Dietary fiber in grams per 100g
7. "ingredients": List of ingredient strings printed on the package.
8. "additives": List of detected food additives with "ins_code", "primary_name", and "risk_tier" ("GREEN", "CAUTION", or "RED").
9. "bioactive_compounds": List of detected herbs/alkaloids/bioactives (e.g., Senna, Caffeine, Ashwagandha) or empty list.
10. "warnings": List of clinical cautions (e.g., "High Sodium", "Contains Gluten") or empty list.

${hintBarcode != null ? 'Note: Scanned barcode hint: $hintBarcode.' : ''}
Respond ONLY with a valid JSON object matching this schema without any markdown formatting.
''';
  }
}
