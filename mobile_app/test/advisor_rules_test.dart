import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/advisor/domain/advisor_rules.dart';

void main() {
  group('AdvisorRules Guardrails & Scope Tests', () {
    test('isOutOfScope correctly identifies non-food, non-app queries', () {
      expect(AdvisorRules.isOutOfScope('who is pm of india'), isTrue);
      expect(AdvisorRules.isOutOfScope('Who is the Prime Minister of India?'), isTrue);
      expect(AdvisorRules.isOutOfScope('who is the president of usa'), isTrue);
      expect(AdvisorRules.isOutOfScope('who won the cricket match yesterday'), isTrue);
      expect(AdvisorRules.isOutOfScope('write python code for quicksort'), isTrue);
      expect(AdvisorRules.isOutOfScope('tell me a funny joke'), isTrue);
      expect(AdvisorRules.isOutOfScope('what is the capital of France'), isTrue);
      expect(AdvisorRules.isOutOfScope('what is the weather in Delhi'), isTrue);
      expect(AdvisorRules.isOutOfScope('what is the current stock price of Apple'), isTrue);
    });

    test('isOutOfScope permits legitimate food, nutrition, and app queries', () {
      expect(AdvisorRules.isOutOfScope('Is maltodextrin safe for daily consumption?'), isFalse);
      expect(AdvisorRules.isOutOfScope('How much sugar is allowed for a diabetic?'), isFalse);
      expect(AdvisorRules.isOutOfScope('Can my child eat foods with INS 102?'), isFalse);
      expect(AdvisorRules.isOutOfScope('How do I scan a product barcode?'), isFalse);
      expect(AdvisorRules.isOutOfScope('Where can I see healthy clean swaps?'), isFalse);
      expect(AdvisorRules.isOutOfScope('How do I change my body weight?'), isFalse);
      expect(AdvisorRules.isOutOfScope('What does the 39 red cap score mean?'), isFalse);
      expect(AdvisorRules.isOutOfScope('hello'), isFalse);
      expect(AdvisorRules.isOutOfScope('help'), isFalse);
    });

    test('isIdentityQuery catches model and creator interrogation', () {
      expect(AdvisorRules.isIdentityQuery('Which model are you?'), isTrue);
      expect(AdvisorRules.isIdentityQuery('Who created you?'), isTrue);
      expect(AdvisorRules.isIdentityQuery('Who made you?'), isTrue);
      expect(AdvisorRules.isIdentityQuery('Are you Gemini or ChatGPT?'), isTrue);
      expect(AdvisorRules.isIdentityQuery('What AI are you?'), isTrue);

      expect(AdvisorRules.isIdentityQuery('Is this biscuit safe?'), isFalse);
      expect(AdvisorRules.isIdentityQuery('How do I use this app?'), isFalse);
    });

    test('isAppHelpQuery catches in-app feature and troubleshooting questions', () {
      expect(AdvisorRules.isAppHelpQuery('how do I scan a product barcode?'), isTrue);
      expect(AdvisorRules.isAppHelpQuery('how to change weight in profile?'), isTrue);
      expect(AdvisorRules.isAppHelpQuery('how to find swaps on blinkit?'), isTrue);
      expect(AdvisorRules.isAppHelpQuery('what does the health score mean?'), isTrue);

      final scanGuide = AdvisorRules.buildAppHelpResponse('how to scan');
      expect(scanGuide, contains('How to Scan with VeriBite'));
      expect(scanGuide, contains('320px central reticle'));

      final weightGuide = AdvisorRules.buildAppHelpResponse('change weight');
      expect(weightGuide, contains('How to Adjust Biometrics & Guardrails'));
      expect(weightGuide, contains('Weight Slider'));
    });

    test('buildSystemPrompt includes mandatory identity and brevity guardrails', () {
      final prompt = AdvisorRules.buildSystemPrompt(
        weightKg: 70.0,
        isChild: false,
        isDiabetic: true,
        isHypertensive: false,
        productName: 'Cream Wafer',
        healthScore: 32,
      );

      expect(prompt, contains('IDENTITY RULE: You are ONLY the "VeriBite AI Advisor"'));
      expect(prompt, contains('NEVER disclose or mention your underlying AI model'));
      expect(prompt, contains('STRICT DOMAIN BOUNDARY'));
      expect(prompt, contains('CONCISENESS & BREVITY: Give ONLY the details requested'));
      expect(prompt, contains('NO MEDICAL DIAGNOSIS'));
      expect(prompt, contains('Calibrated Body Weight: 70.0 kg'));
      expect(prompt, contains('Diabetic Guardrail: ACTIVE'));
    });
  });
}

