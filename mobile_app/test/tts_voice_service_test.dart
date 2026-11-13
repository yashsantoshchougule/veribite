import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/advisor/application/tts_voice_service.dart';
import 'package:mobile_app/features/camera/application/product_scanner_service.dart';
import 'package:mobile_app/features/profile/domain/user_profile_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TtsVoiceService Tests', () {
    test('naturalFemaleVoice defaults to studio-grade en-US-AriaNeural', () {
      expect(TtsVoiceService.naturalFemaleVoice, 'en-US-AriaNeural');
    });

    test('cleanMarkdownForSpeech removes markdown symbols and formats for speech', () {
      const rawMarkdown = '''
### Diabetes & Sugar Warning
• **Safe Portion Cap:** Do not exceed **15g** in a single sitting.
• *Frequency:* Max 1-2x per week.
⚠️ Flagged Additives: Contains INS 102 (Tartrazine).
''';

      final cleaned = TtsVoiceService.cleanMarkdownForSpeech(rawMarkdown);

      expect(cleaned, isNot(contains('###')));
      expect(cleaned, isNot(contains('**')));
      expect(cleaned, isNot(contains('•')));
      expect(cleaned, isNot(contains('⚠️')));
      expect(cleaned, contains('Diabetes & Sugar Warning'));
      expect(cleaned, contains('Safe Portion Cap: Do not exceed 15g in a single sitting'));
      expect(cleaned, contains('Frequency: Max 1-2x per week'));
    });

    test('toggleAutoSpeak toggles voice readout state', () {
      final service = TtsVoiceService();
      expect(service.autoSpeakEnabledNotifier.value, isFalse);

      service.toggleAutoSpeak();
      expect(service.autoSpeakEnabledNotifier.value, isTrue);

      service.toggleAutoSpeak();
      expect(service.autoSpeakEnabledNotifier.value, isFalse);

      service.dispose();
    });

    test('isSpeaking reports correct message status', () {
      final service = TtsVoiceService();
      expect(service.isSpeaking('msg_123'), isFalse);

      service.currentlySpeakingIdNotifier.value = 'msg_123';
      expect(service.isSpeaking('msg_123'), isTrue);
      expect(service.isSpeaking('msg_456'), isFalse);

      service.dispose();
    });

    test('stop clears speaking state immediately', () async {
      final service = TtsVoiceService();
      service.currentlySpeakingIdNotifier.value = 'msg_test';
      expect(service.isSpeaking('msg_test'), isTrue);

      await service.stop();
      expect(service.currentlySpeakingIdNotifier.value, isNull);
      expect(service.isSpeaking('msg_test'), isFalse);

      service.dispose();
    });

    test('speak with empty text does not initiate playback', () async {
      final service = TtsVoiceService();
      await service.speak('   ', messageId: 'empty_msg');
      expect(service.currentlySpeakingIdNotifier.value, isNull);

      service.dispose();
    });

    test('buildVerdictSpeechSummary formats clean speech for safe product', () {
      final profile = UserProfileModel.defaults('test_user');
      const product = ScannedProductResult(
        barcode: '8901491101837',
        productName: '100% Whole Grain Rolled Oats',
        brandName: 'Quaker',
        category: 'Breakfast Cereals',
        servingSizeG: 40.0,
        sugarGPer100g: 1.1,
        sugarGPerServing: 0.4,
        caloriesPerServing: 153.0,
        healthScore: 88,
        verdictTag: 'Nutri Safe 🟢',
        novaGrade: 1,
        redCapTriggered: false,
        safePortionGrams: 40,
        safePieces: null,
        limitingFactor: 'Calories',
        frequencySchedule: 'Daily Safe',
        additives: [],
        splitSugars: [],
        portionAdvice: 'Safe portion: 40g',
        isExceededBudget: false,
      );

      final summary = TtsVoiceService.buildVerdictSpeechSummary(
        product: product,
        userProfile: profile,
      );

      expect(summary, contains('100% Whole Grain Rolled Oats'));
      expect(summary, contains('88 out of 100'));
      expect(summary, contains('Nutri Safe'));
      expect(summary, contains('No toxic red-cap chemical additives were detected'));
      expect(summary, contains('40 grams'));
      expect(summary, contains('Daily Safe'));
      expect(summary, contains('Calories'));
    });

    test('buildVerdictSpeechSummary includes red-cap warnings and split sugars for ultra-processed items', () {
      final profile = UserProfileModel.defaults('test_user');
      const product = ScannedProductResult(
        barcode: '8901058852339',
        productName: '2-Minute Masala Noodles',
        brandName: 'Maggi',
        category: 'Instant Noodles',
        servingSizeG: 70.0,
        sugarGPer100g: 3.2,
        sugarGPerServing: 2.2,
        caloriesPerServing: 295.0,
        healthScore: 32,
        verdictTag: 'Toxic / Capped 🔴',
        novaGrade: 4,
        redCapTriggered: true,
        safePortionGrams: 25,
        safePieces: null,
        limitingFactor: 'Sodium',
        frequencySchedule: 'Strict 1–2x Per Week',
        additives: [
          {
            'ins_code': '635',
            'primary_name': 'Disodium 5-Ribonucleotides',
            'risk_tier': 'RED',
            'triggers_red_cap': 1,
          },
        ],
        splitSugars: ['Invert Sugar Syrup', 'Liquid Glucose'],
        portionAdvice: 'Safe portion: 25g',
        isExceededBudget: false,
      );

      final summary = TtsVoiceService.buildVerdictSpeechSummary(
        product: product,
        userProfile: profile,
      );

      expect(summary, contains('2-Minute Masala Noodles'));
      expect(summary, contains('32 out of 100'));
      expect(summary, contains('Toxic / Capped'));
      expect(summary, contains('Warning: A strict red-cap toxic override is triggered'));
      expect(summary, contains('Disodium 5-Ribonucleotides'));
      expect(summary, contains('Hidden sugar splitting was detected across 2 sweetener aliases'));
      expect(summary, contains('25 grams'));
      expect(summary, contains('Sodium'));
    });
  });
}
