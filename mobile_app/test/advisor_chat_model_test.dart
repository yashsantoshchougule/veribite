import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/advisor/domain/advisor_chat_model.dart';

void main() {
  group('ChatMessage & ProductAdvisorContext Tests', () {
    test('ChatMessage.user creates properly initialized user message', () {
      final msg = ChatMessage.user('Is this diabetic safe?');
      expect(msg.isUser, isTrue);
      expect(msg.text, 'Is this diabetic safe?');
      expect(msg.source, 'user');
      expect(msg.citations, isEmpty);
    });

    test('ChatMessage.advisor correctly parses citations and dosage metrics', () {
      final msg = ChatMessage.advisor(
        text: 'This product contains Sunset Yellow (INS 110).',
        source: 'gemini_2.5_flash',
        citations: ['EFSA-2009-110', 'WHO-JECFA-ADI'],
        safePortionGrams: 28.5,
        frequencySchedule: 'Max 1-2 times per week',
      );

      expect(msg.isUser, isFalse);
      expect(msg.source, 'gemini_2.5_flash');
      expect(msg.citations, contains('EFSA-2009-110'));
      expect(msg.safePortionGrams, 28.5);
      expect(msg.frequencySchedule, 'Max 1-2 times per week');
    });

    test('ChatMessage.fromJson parses backend API response correctly', () {
      final json = {
        'source': 'rule_based_fallback',
        'response': 'Calculated portion is 35g based on WHO guidelines.',
        'citations': ['WHO-TRS-983'],
        'safe_portion_grams': 35.0,
        'frequency_schedule': 'Max 2 times per week',
      };

      final msg = ChatMessage.fromJson(json);
      expect(msg.isUser, isFalse);
      expect(msg.source, 'rule_based_fallback');
      expect(msg.text, contains('Calculated portion is 35g'));
      expect(msg.citations, ['WHO-TRS-983']);
      expect(msg.safePortionGrams, 35.0);
    });

    test('ProductAdvisorContext converts to valid backend payload', () {
      const ctx = ProductAdvisorContext(
        productName: 'Good Day Cookies',
        barcode: '8901063012117',
        healthScore: 32,
        additives: [
          {'ins_code': '102', 'name': 'Tartrazine', 'risk_tier': 'Red'},
        ],
        nutrition: {
          'sugars_100g': 24.0,
          'sodium_100g': 180.0,
        },
      );

      final payload = ctx.toBackendPayload();
      expect(payload['product_name'], 'Good Day Cookies');
      expect(payload['health_score'], 32);
      expect((payload['additives'] as List).length, 1);
      expect((payload['nutrition'] as Map)['sugars_100g'], 24.0);
    });
  });
}

