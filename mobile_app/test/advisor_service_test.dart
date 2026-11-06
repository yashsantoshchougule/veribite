import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/features/advisor/application/advisor_service.dart';
import 'package:mobile_app/features/advisor/domain/advisor_chat_model.dart';
import 'package:mobile_app/features/profile/domain/user_profile_model.dart';

void main() {
  group('AdvisorService Tests', () {
    test('askAdvisor parses 200 OK cloud response with citations', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, '/api/v1/advisor/chat');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['user_message'], 'Is this safe for kids?');

        return http.Response(
          jsonEncode({
            'source': 'gemini_2.5_flash',
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

      expect(reply.source, 'gemini_2.5_flash');
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
  });
}

