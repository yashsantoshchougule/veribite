import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_app/core/config/ai_provider_config.dart';
import 'package:mobile_app/core/vision/on_device_vision_service.dart';
import 'package:mobile_app/services/multi_provider_ai_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    AiProviderConfig.clearAllCooldowns();
    AiProviderConfig.setTestGroqKeys(['gsk_mock_test_key_for_unit_tests']);
    AiProviderConfig.setTestOpenRouterKeys(['sk-or-mock_test_key_for_unit_tests']);
  });

  tearDown(() {
    AiProviderConfig.clearAllCooldowns();
    AiProviderConfig.setTestGroqKeys([]);
    AiProviderConfig.setTestOpenRouterKeys([]);
  });

  group('MultiProviderAiRouter Unit Tests', () {
    test('Image Pre-Compression shrinks high-res image to <= 1280px longest side', () {
      // Create a 2000 x 1000 dummy image in memory
      final rawImage = img.Image(width: 2000, height: 1000);
      img.fill(rawImage, color: img.ColorRgb8(200, 100, 50));
      final highResJpg = img.encodeJpg(rawImage, quality: 95);

      expect(highResJpg.length, greaterThan(20000));

      // Compress via router
      final compressed = MultiProviderAiRouter.precompressFrame(highResJpg);
      final decodedCompressed = img.decodeImage(compressed);

      expect(decodedCompressed, isNotNull);
      expect(decodedCompressed!.width, 1280);
      expect(decodedCompressed.height, 640);
      expect(compressed.length, lessThan(highResJpg.length));
    });

    test('In-Flight Request Deduplication awaits same future within sliding window', () async {
      int apiCallCount = 0;
      final mockClient = MockClient((req) async {
        apiCallCount++;
        await Future.delayed(const Duration(milliseconds: 30));
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': jsonEncode({'product_name': 'Deduplicated Milk', 'calories': 60.0})}
                  ]
                }
              }
            ]
          }),
          200,
        );
      });

      final router = MultiProviderAiRouter(httpClient: mockClient);
      final frame = List<int>.filled(100, 1);

      // Fire 2 simultaneous identical calls
      final call1 = router.analyzePackagingPhoto(frames: [frame], hintBarcode: '89012345');
      final call2 = router.analyzePackagingPhoto(frames: [frame], hintBarcode: '89012345');

      final results = await Future.wait([call1, call2]);

      expect(results[0], isNotNull);
      expect(results[1], isNotNull);
      expect(results[0]!['product_name'], 'Deduplicated Milk');
      expect(results[1]!['product_name'], 'Deduplicated Milk');
      // Deduplication guarantees single remote execution
      expect(apiCallCount, 1);
    });

    test('Proactive Groq Rate-Limit Inspection triggers cooldown when tokens < 1500', () {
      const provider = AiProvider.groq;
      const apiKey = 'gsk_test_api_key_12345678';
      const model = 'qwen/qwen3.8-27b';

      expect(AiProviderConfig.isBucketAvailable(provider, apiKey, model), isTrue);

      // Inspect response headers showing remaining tokens is 1200 (< 1500 threshold)
      AiProviderConfig.inspectResponseHeaders(
        provider,
        apiKey,
        model,
        {
          'x-ratelimit-remaining-tokens': '1200',
          'x-ratelimit-remaining-requests': '25',
        },
      );

      // Bucket should now proactively be on cooldown
      expect(AiProviderConfig.isBucketAvailable(provider, apiKey, model), isFalse);
      expect(AiProviderConfig.getRemainingCooldownSeconds(provider, apiKey, model), greaterThan(0));
    });

    test('HTTP 429 Retry-After parsing locks bucket with jitter', () {
      const provider = AiProvider.gemini;
      const apiKey = 'test_gemini_key_1234';
      const model = 'gemini-2.5-flash';

      expect(AiProviderConfig.isBucketAvailable(provider, apiKey, model), isTrue);

      AiProviderConfig.markCooldown(
        provider,
        apiKey,
        model,
        retryAfterSeconds: 20,
        reason: 'HTTP 429 received',
      );

      expect(AiProviderConfig.isBucketAvailable(provider, apiKey, model), isFalse);
      expect(AiProviderConfig.getRemainingCooldownSeconds(provider, apiKey, model), inInclusiveRange(19, 22));
    });

    test('Multimodal Vision cascade: Tier 1 (Gemini) fails -> Tier 2 (Groq Qwen 3.8) succeeds', () async {
      final mockClient = MockClient((req) async {
        final url = req.url.toString();

        // Tier 1: Gemini returns 429
        if (url.contains('generativelanguage.googleapis.com')) {
          return http.Response(
            jsonEncode({'error': {'code': 429, 'message': 'Resource has been exhausted'}}),
            429,
            headers: {'retry-after': '10'},
          );
        }

        // Tier 2: Groq receives Qwen request and responds 200 with JSON
        if (url.contains('api.groq.com')) {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['model'], 'qwen/qwen3.8-27b');
          expect(body['response_format'], {'type': 'json_object'});

          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': jsonEncode({
                      'product_name': 'Haldiram Frozen Paneer',
                      'brand_name': "Haldiram's",
                      'category': 'Dairy',
                      'calories': 280.0,
                      'protein_g': 18.0,
                      'total_fat_g_per_100g': 22.0,
                      'carbohydrates_g_per_100g': 3.0,
                      'sodium_mg_per_100g': 40.0,
                    })
                  }
                }
              ]
            }),
            200,
            headers: {
              'x-ratelimit-remaining-tokens': '50000',
              'x-ratelimit-remaining-requests': '29',
            },
          );
        }

        return http.Response('Not Found', 404);
      });

      final router = MultiProviderAiRouter(httpClient: mockClient);
      final dummyFrame = List<int>.generate(200, (i) => i % 256);

      final result = await router.analyzePackagingPhoto(frames: [dummyFrame]);

      expect(result, isNotNull);
      expect(result!['source'], 'groq_vision');
      expect(result['product_name'], 'Haldiram Frozen Paneer');
      expect(result['brand_name'], "Haldiram's");
      expect(result['calories'], 280.0);
    });

    test('Advisor Chat routes to Groq Llama 3.3 70B without burning Vision quota', () async {
      final mockClient = MockClient((req) async {
        final url = req.url.toString();

        if (url.contains('api.groq.com')) {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          // Ensures Advisor uses Llama 3.3 70B versatile, preserving Qwen vision quota
          expect(body['model'], 'llama-3.3-70b-versatile');

          return http.Response(
            jsonEncode({
              'choices': [
                {
                  'message': {
                    'content': 'Safi is an Unani botanical blood purifier formulation containing zero cholesterol.'
                  }
                }
              ]
            }),
            200,
            headers: {
              'x-ratelimit-remaining-tokens': '10000',
              'x-ratelimit-remaining-requests': '28',
            },
          );
        }

        return http.Response('Error', 500);
      });

      final router = MultiProviderAiRouter(httpClient: mockClient);
      final answer = await router.askAdvisor(
        systemPrompt: 'You are the VeriBite AI Advisor.',
        userMessage: 'what is colestrol of safi',
      );

      expect(answer, isNotNull);
      expect(answer, contains('zero cholesterol'));
    });

    test('Multimodal Vision cascade falls back to Tier 4 On-Device OCR when all cloud tiers fail', () async {
      final mockClient = MockClient((req) async {
        // All cloud endpoints fail with 503 or 429
        return http.Response('Service Unavailable', 503);
      });

      final mockOnDeviceService = OnDeviceVisionService(
        injectedOcrEngine: (bytes) async {
          return '''
Haldiram's Bhujia Sev
Energy: 580 kcal
Protein: 12.0 g
Total Fat: 42.0 g
Carbohydrates: 38.0 g
Sodium: 680 mg
Ingredients: Tepary Beans Flour, Edible Vegetable Oil, Salt, Red Chilli Powder.
''';
        },
      );

      final router = MultiProviderAiRouter(
        httpClient: mockClient,
        onDeviceVisionService: mockOnDeviceService,
      );

      final dummyFrame = List<int>.generate(200, (i) => i % 256);
      final result = await router.analyzePackagingPhoto(frames: [dummyFrame]);

      expect(result, isNotNull);
      expect(result!['source'], 'on_device_vision');
      expect(result['product_name'], contains('Bhujia'));
    });

    test('AiProviderConfig correctly unmasks 11 keys (5 Gemini, 3 Groq, 3 OpenRouter) and rotates', () {
      // Clear test overrides so default pool is tested
      AiProviderConfig.setTestGroqKeys([]);
      AiProviderConfig.setTestOpenRouterKeys([]);

      // 1. Gemini: 5 keys
      final geminiKeys = AiProviderConfig.geminiApiKeys;
      expect(geminiKeys.length, greaterThanOrEqualTo(5));
      expect(geminiKeys[0], startsWith('AQ.Ab8RN6Jftl'));
      expect(geminiKeys[1], startsWith('AQ.Ab8RN6JhPa'));
      expect(geminiKeys[2], startsWith('AQ.Ab8RN6IREU'));
      expect(geminiKeys[3], startsWith('AQ.Ab8RN6LoMr'));
      expect(geminiKeys[4], startsWith('AQ.Ab8RN6KkUR'));

      // 2. Groq: 3 keys
      final groqKeys = AiProviderConfig.groqApiKeys;
      expect(groqKeys.length, 3);
      expect(groqKeys[0], startsWith('gsk_YDoGu9'));
      expect(groqKeys[1], startsWith('gsk_UxArVi'));
      expect(groqKeys[2], startsWith('gsk_Pnz9am'));

      // 3. OpenRouter: 3 keys
      final orKeys = AiProviderConfig.openRouterApiKeys;
      expect(orKeys.length, 3);
      expect(orKeys[0], startsWith('sk-or-v1-1b0ce'));
      expect(orKeys[1], startsWith('sk-or-v1-671fd'));
      expect(orKeys[2], startsWith('sk-or-v1-a911c'));

      // 4. Test Key Masking for Display
      expect(AiProviderConfig.maskKeyForDisplay(groqKeys[0]), 'gsk_YDoG••••Gknn');
      expect(AiProviderConfig.maskKeyForDisplay(orKeys[0]), 'sk-or-v1••••2668');

      // 5. Test Key Rotation
      final firstGemini = AiProviderConfig.activeGeminiApiKey;
      AiProviderConfig.rotateGeminiKey();
      expect(AiProviderConfig.activeGeminiApiKey, isNot(equals(firstGemini)));

      final firstGroq = AiProviderConfig.activeGroqApiKey;
      AiProviderConfig.rotateGroqKey();
      expect(AiProviderConfig.activeGroqApiKey, isNot(equals(firstGroq)));

      final firstOr = AiProviderConfig.activeOpenRouterApiKey;
      AiProviderConfig.rotateOpenRouterKey();
      expect(AiProviderConfig.activeOpenRouterApiKey, isNot(equals(firstOr)));
    });
  });
}
