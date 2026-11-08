import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/advisor/application/tts_voice_service.dart';

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
  });
}
