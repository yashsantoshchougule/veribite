import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Text-to-Speech Voice Service powering the conversational AI advisor.
/// Allows VeriBite AI to talk aloud to users, reading out nutrition guidance,
/// safety warnings, and portion advice in natural spoken voice.
class TtsVoiceService {
  final FlutterTts _flutterTts;
  final ValueNotifier<String?> currentlySpeakingIdNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<bool> autoSpeakEnabledNotifier = ValueNotifier<bool>(false);

  TtsVoiceService({FlutterTts? tts}) : _flutterTts = tts ?? FlutterTts() {
    _initTts();
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setSpeechRate(0.48).catchError((_) => null);
      await _flutterTts.setVolume(1.0).catchError((_) => null);
      await _flutterTts.setPitch(1.0).catchError((_) => null);

      _flutterTts.setCompletionHandler(() {
        currentlySpeakingIdNotifier.value = null;
      });

      _flutterTts.setCancelHandler(() {
        currentlySpeakingIdNotifier.value = null;
      });

      _flutterTts.setErrorHandler((msg) {
        debugPrint('[TtsVoiceService] Error: $msg');
        currentlySpeakingIdNotifier.value = null;
      });
    } catch (e) {
      debugPrint('[TtsVoiceService] Initialization notice: $e');
    }
  }

  /// Clean Markdown characters, bullet points, and citation markers before speaking
  static String cleanMarkdownForSpeech(String markdown) {
    var text = markdown;
    // Remove markdown headers (###)
    text = text.replaceAll(RegExp(r'#+\s*'), '');
    // Remove bold and italic formatting (**text** or *text*)
    text = text.replaceAllMapped(RegExp(r'\*\*([^*]+)\*\*'), (m) => m[1] ?? '');
    text = text.replaceAllMapped(RegExp(r'\*([^*]+)\*'), (m) => m[1] ?? '');
    // Replace bullet points with brief pauses
    text = text.replaceAll(RegExp(r'^\s*•\s*', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*\*\s*', multiLine: true), '');
    // Remove emojis or warning symbols
    text = text.replaceAll(RegExp(r'[⚠️🚨🔊⏹️•\\]'), '');
    // Condense extra newlines
    text = text.replaceAll(RegExp(r'\n+'), '. ');
    return text.trim();
  }

  /// Speaks the provided text aloud. If the same message is already playing, stops it.
  Future<void> toggleSpeak(String text, {required String messageId}) async {
    if (currentlySpeakingIdNotifier.value == messageId) {
      await stop();
    } else {
      await speak(text, messageId: messageId);
    }
  }

  /// Speaks text aloud
  Future<void> speak(String text, {required String messageId}) async {
    final cleanText = cleanMarkdownForSpeech(text);
    if (cleanText.isEmpty) return;

    try {
      currentlySpeakingIdNotifier.value = messageId;
      await _flutterTts.stop().catchError((_) => null);
      await _flutterTts.speak(cleanText).catchError((_) => null);
    } catch (e) {
      debugPrint('[TtsVoiceService] Speak notice: $e');
      currentlySpeakingIdNotifier.value = null;
    }
  }

  /// Stops current speech output
  Future<void> stop() async {
    try {
      await _flutterTts.stop().catchError((_) => null);
    } catch (e) {
      debugPrint('[TtsVoiceService] Stop notice: $e');
    } finally {
      currentlySpeakingIdNotifier.value = null;
    }
  }

  /// Toggles automatic voice readout for incoming AI responses
  void toggleAutoSpeak() {
    autoSpeakEnabledNotifier.value = !autoSpeakEnabledNotifier.value;
  }

  bool isSpeaking(String messageId) {
    return currentlySpeakingIdNotifier.value == messageId;
  }

  void dispose() {
    try {
      _flutterTts.stop().catchError((_) => null);
    } catch (_) {}
    currentlySpeakingIdNotifier.dispose();
    autoSpeakEnabledNotifier.dispose();
  }
}
