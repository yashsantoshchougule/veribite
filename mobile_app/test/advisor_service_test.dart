import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/core/network/client_rate_limiter.dart';
import 'package:mobile_app/features/advisor/application/advisor_service.dart';
import 'package:mobile_app/features/advisor/domain/advisor_chat_model.dart';
import 'package:mobile_app/features/profile/domain/user_profile_model.dart';

void main() {
  group('AdvisorService Tests', () {
    test('askAdvisor queries direct Google Gemini REST endpoint with RAG context', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.host, 'generativelanguage.googleapis.com');
        expect(request.url.path, contains('gemini-3.1-flash-lite'));

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final promptText = body['contents'][0]['parts'][0]['text'] as String;
        expect(promptText, contains('USER HEALTH PROFILE'));
        expect(promptText, contains('WHO, EFSA, FSSAI, JECFA'));

        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': 'According to WHO guidelines, daily free sugar intake should be restricted to under 25g. EFSA and FSSAI guidelines corroborate this ceiling.'
                    }
                  ]
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = AdvisorService(client: mockClient);
      final reply = await service.askAdvisor(
        userMessage: 'What is the safe sugar limit for an adult?',
        userProfile: UserProfileModel.defaults('test_user'),
      );

      expect(reply.source, 'gemini_3.5_flash');
      expect(reply.text, contains('WHO guidelines'));
      expect(reply.citations, contains('WHO Free Sugars (2015)'));
      expect(reply.citations, contains('EFSA Additive Opinion'));
    });

    test('askAdvisor retries with fallback model when primary model returns 503 spike', () async {
      int attempt = 0;
      final mockClient = MockClient((request) async {
        attempt++;
        if (attempt == 1) {
          expect(request.url.path, contains('gemini-3.1-flash-lite'));
          return http.Response('{"error": {"code": 503, "message": "High demand"}}', 503);
        }
        expect(request.url.path, contains('gemini-flash-lite-latest'));
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': 'WHO recommends limiting salt and processed additives.'
                    }
                  ]
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = AdvisorService(client: mockClient);
      final reply = await service.askAdvisor(
        userMessage: 'Is this high in sodium?',
        userProfile: UserProfileModel.defaults('test_user'),
      );

      expect(attempt, 2);
      expect(reply.text, contains('WHO recommends limiting salt'));
    });

    test('askAdvisor parses 200 OK backend proxy response with citations', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/advisor/chat');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['user_message'], 'Is this safe for kids?');

        return http.Response(
          jsonEncode({
            'source': 'gemini_3.5_flash',
            'response': 'Tartrazine (INS 102) is flagged under Southampton studies for pediatric hyperactivity.',
            'citations': ['EFSA-ANS-2009-102', 'WHO-TRS-983'],
            'safe_portion_grams': 22.0,
            'frequency_schedule': 'Max 1 time per week',
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = AdvisorService(client: mockClient, customBaseUrl: 'http://test-server:8000');
      final reply = await service.askAdvisor(
        userMessage: 'Is this safe for kids?',
        userProfile: UserProfileModel.defaults('test_user'),
      );

      expect(reply.source, 'gemini_3.5_flash');
      expect(reply.text, contains('Tartrazine (INS 102)'));
      expect(reply.citations, contains('EFSA-ANS-2009-102'));
      expect(reply.safePortionGrams, 22.0);
    });

    test('askAdvisor seamlessly falls back to offline factual engine on network error', () async {
      final failingClient = MockClient((request) async {
        throw http.ClientException('Connection refused');
      });

      final service = AdvisorService(client: failingClient, customBaseUrl: 'http://offline-server:8000');
      final reply = await service.askAdvisor(
        userMessage: 'Is this safe for diabetic patients?',
        productContext: const ProductAdvisorContext(
          productName: 'Cream Biscuit',
          barcode: '8901234567890',
          healthScore: 35,
          additives: [
            {'ins_code': '102', 'name': 'Tartrazine', 'risk_tier': 'Red'},
          ],
          nutrition: {'sugars_100g': 32.0},
        ),
        userProfile: UserProfileModel.defaults('test_user'),
      );

      expect(reply.source, 'local_offline');
      expect(reply.text, contains('Diabetes & Sugar Assessment'));
      expect(reply.citations, contains('WHO-Guidelines-Sugar-2015'));
      expect(reply.safePortionGrams, isNotNull);
      expect(reply.frequencySchedule, isNotNull);
    });

    test('offline fallback handles child queries and Southampton additives', () async {
      final failingClient = MockClient((request) async {
        return http.Response('Server Error', 500);
      });

      final service = AdvisorService(client: failingClient, customBaseUrl: 'http://server:8000');
      final reply = await service.askAdvisor(
        userMessage: 'Can my child eat this snack?',
        productContext: const ProductAdvisorContext(
          productName: 'Fruit Jelly',
          barcode: '8901112223334',
          healthScore: 28,
          additives: [
            {'ins_code': '110', 'name': 'Sunset Yellow', 'risk_tier': 'Red'},
          ],
        ),
        userProfile: UserProfileModel.defaults('test_user'),
      );

      expect(reply.source, 'local_offline');
      expect(reply.text, contains('Child Safety & Pediatric Toxicology'));
      expect(reply.text, contains('Sunset Yellow'));
      expect(reply.citations, contains('EFSA-Southampton-Study-2008'));
    });

    test('askAdvisor intercepts and refuses out-of-scope query without hitting network', () async {
      bool networkCalled = false;
      final mockClient = MockClient((request) async {
        networkCalled = true;
        return http.Response('{}', 200);
      });

      final service = AdvisorService(client: mockClient);
      final reply = await service.askAdvisor(
        userMessage: 'who is pm of india',
        userProfile: UserProfileModel.defaults('test_user'),
      );

      expect(networkCalled, isFalse);
      expect(reply.source, 'veribite_guardrail');
      expect(reply.text, contains('VeriBite Food Safety & App Advisor'));
      expect(reply.text, contains('Please ask a question related to food products or this application'));
    });

    test('askAdvisor intercepts identity query protecting model and creator anonymity', () async {
      bool networkCalled = false;
      final mockClient = MockClient((request) async {
        networkCalled = true;
        return http.Response('{}', 200);
      });

      final service = AdvisorService(client: mockClient);
      final reply = await service.askAdvisor(
        userMessage: 'Which model are you and who created you?',
        userProfile: UserProfileModel.defaults('test_user'),
      );

      expect(networkCalled, isFalse);
      expect(reply.source, 'veribite_guardrail');
      expect(reply.text, contains('I am the VeriBite AI Advisor'));
      expect(reply.text, isNot(contains('Gemini')));
      expect(reply.text, isNot(contains('Google')));
    });

    test('askAdvisor offline fallback answers in-app feature guidance queries', () async {
      final failingClient = MockClient((request) async {
        throw http.ClientException('Offline');
      });

      final service = AdvisorService(client: failingClient);
      final reply = await service.askAdvisor(
        userMessage: 'how do I scan a product barcode?',
        userProfile: UserProfileModel.defaults('test_user'),
      );

      expect(reply.source, 'veribite_app_guide');
      expect(reply.text, contains('How to Scan with VeriBite'));
      expect(reply.text, contains('320px central reticle'));
    });

    test('askAdvisor does not attach safePortionGrams when query is general and has no product context', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'text': 'VeriBite analyzes packaged food ingredients and flags harmful additives.'
                    }
                  ]
                }
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final service = AdvisorService(client: mockClient);
      final reply = await service.askAdvisor(
        userMessage: 'What are your primary functions?',
        userProfile: UserProfileModel.defaults('test_user'),
      );

      expect(reply.safePortionGrams, isNull);
      expect(reply.frequencySchedule, isNull);
    });

    test('askAdvisor enforces client-side rate limit and returns guardrail cooldown message', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [{'text': 'Safe intake is 20g.'}]
                }
              }
            ]
          }),
          200,
        );
      });

      final customLimiter = ClientRateLimiter(
        maxRequestsPerMinute: 1,
        minimumInterval: const Duration(seconds: 10),
      );
      final service = AdvisorService(client: mockClient, rateLimiter: customLimiter);

      // 1st request succeeds
      final reply1 = await service.askAdvisor(
        userMessage: 'Is sugar safe?',
        userProfile: UserProfileModel.defaults('test_user'),
      );
      expect(reply1.source, 'gemini_3.5_flash');

      // 2nd request immediately blocked by client limiter
      final reply2 = await service.askAdvisor(
        userMessage: 'Is sugar safe again?',
        userProfile: UserProfileModel.defaults('test_user'),
      );
      expect(reply2.source, 'veribite_guardrail');
      expect(reply2.text, contains('You are sending questions too quickly'));
    });

    test('askAdvisor handles HTTP 429 rate limit from Gemini and falls back to offline database', () async {
      final rateLimitedClient = MockClient((request) async {
        return http.Response(
          '{"error": {"code": 429, "message": "Resource exhausted"}}',
          429,
          headers: {'retry-after': '20'},
        );
      });

      final customLimiter = ClientRateLimiter(maxRequestsPerMinute: 20);
      final service = AdvisorService(client: rateLimitedClient, rateLimiter: customLimiter);

      final reply = await service.askAdvisor(
        userMessage: 'What is safe salt dosage?',
        userProfile: UserProfileModel.defaults('test_user'),
      );

      expect(reply.source, 'local_offline');
      expect(reply.text, contains('rate limit active'));
      expect(customLimiter.canSendRequest(), isFalse);
    });

    test('askAdvisor handles HTTP 429 rate limit from backend proxy and falls back gracefully', () async {
      final proxyRateLimitedClient = MockClient((request) async {
        return http.Response(
          '{"detail": "Rate limit exceeded for advisor tier", "retry_after": 25, "tier": "advisor"}',
          429,
          headers: {'retry-after': '25'},
        );
      });

      final customLimiter = ClientRateLimiter(maxRequestsPerMinute: 20);
      final service = AdvisorService(
        client: proxyRateLimitedClient,
        customBaseUrl: 'http://localhost:8000',
        rateLimiter: customLimiter,
      );

      final reply = await service.askAdvisor(
        userMessage: 'How much sugar can I eat?',
        userProfile: UserProfileModel.defaults('test_user'),
      );

      expect(reply.source, 'local_offline');
      expect(reply.text, contains('rate limit active'));
      expect(customLimiter.canSendRequest(), isFalse);
    });
  });
}
