import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:edge_tts/edge_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../camera/application/product_scanner_service.dart';
import '../../profile/domain/user_profile_model.dart';

/// Text-to-Speech Voice Service powering the conversational AI advisor.
/// Features a hyper-realistic, emotionally expressive human female voice
/// (Microsoft Edge Neural TTS: en-US-AriaNeural) with automatic seamless
/// fallback to on-device neural female voices.
class TtsVoiceService {
  final FlutterTts _flutterTts;
  AudioPlayer? _audioPlayer;
  StreamSubscription<void>? _playerCompleteSubscription;

  final ValueNotifier<String?> currentlySpeakingIdNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<bool> autoSpeakEnabledNotifier = ValueNotifier<bool>(false);

  /// Top-tier natural, conversational female neural voice
  static const String naturalFemaleVoice = 'en-US-AriaNeural';

  TtsVoiceService({FlutterTts? tts, AudioPlayer? audioPlayer})
      : _flutterTts = tts ?? FlutterTts(),
        _audioPlayer = audioPlayer {
    _initAudioPlayer();
    _initTts();
  }

  void _initAudioPlayer() {
    try {
      _audioPlayer ??= AudioPlayer();
      _playerCompleteSubscription = _audioPlayer?.onPlayerComplete.listen((_) {
        currentlySpeakingIdNotifier.value = null;
      });
    } catch (e) {
      debugPrint('[TtsVoiceService] AudioPlayer initialization notice: $e');
    }
  }

  Future<void> _initTts() async {
    try {
      // Natural conversational cadence and pitch for female voice
      await _flutterTts.setSpeechRate(0.46).catchError((_) => null);
      await _flutterTts.setVolume(1.0).catchError((_) => null);
      await _flutterTts.setPitch(1.08).catchError((_) => null); // Warm, friendly female pitch
      await _flutterTts.setLanguage('en-US').catchError((_) => null);

      // Attempt to select high quality female voice if available on device
      try {
        final dynamic voices = await _flutterTts.getVoices;
        if (voices is List && voices.isNotEmpty) {
          for (final voice in voices) {
            if (voice is Map) {
              final name = (voice['name'] ?? '').toString().toLowerCase();
              final locale = (voice['locale'] ?? '').toString().toLowerCase();
              if (locale.contains('en')) {
                if (name.contains('female') ||
                    name.contains('samantha') ||
                    name.contains('ava') ||
                    name.contains('karen') ||
                    name.contains('serena') ||
                    name.contains('victoria') ||
                    name.contains('sfg') ||
                    name.contains('tpf')) {
                  await _flutterTts.setVoice(Map<String, String>.from(voice));
                  break;
                }
              }
            }
          }
        }
      } catch (_) {}

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
    // Condense extra newlines into distinct conversational pauses
    text = text.replaceAll(RegExp(r'\n+'), '. ');
    return text.trim();
  }

  /// Formats an evidence-based clinical speech summary for a scanned product verdict
  static String buildVerdictSpeechSummary({
    required ScannedProductResult product,
    required UserProfileModel userProfile,
  }) {
    final buffer = StringBuffer();

    // 1. Product Name & Health Score
    final cleanVerdict = product.verdictTag
        .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '')
        .trim();
    buffer.write('Here is the safety verdict for ${product.productName}. ');
    if (product.healthScore != null) {
      buffer.write('Overall health score is ${product.healthScore} out of 100, classified as $cleanVerdict. ');
    } else {
      buffer.write('Overall health score has insufficient data. ');
    }

    // 2. Toxic Red-Cap Override Status
    if (product.redCapTriggered) {
      final redAdditives = product.additives
          .where((a) => a['risk_tier'] == 'RED' || a['triggers_red_cap'] == 1)
          .map((a) => a['primary_name'] ?? 'INS ${a["ins_code"]}')
          .take(3)
          .join(', ');
      buffer.write('Warning: A strict red-cap toxic override is triggered. ');
      if (redAdditives.isNotEmpty) {
        buffer.write('This product contains hazardous additives: $redAdditives. ');
      }
      buffer.write('Health score is restricted to 39 or below. ');
    } else {
      buffer.write('No toxic red-cap chemical additives were detected. ');
    }

    // 3. Sugar Splitting Cluster Alert
    if (product.splitSugars.isNotEmpty) {
      buffer.write(
        'Be aware: Hidden sugar splitting was detected across ${product.splitSugars.length} sweetener aliases, including ${product.splitSugars.take(2).join(" and ")}. ',
      );
    }

    // 4. Prescribed Safe Portion & Ceilings
    buffer.write('Your prescribed safe consumption limit is ${product.safePortionGrams} grams');
    if (product.safePieces != null) {
      buffer.write(', or about ${product.safePieces} pieces');
    }
    buffer.write('. Recommended frequency: ${product.frequencySchedule}. ');
    buffer.write('Limiting constraint: ${product.limitingFactor}.');

    return buffer.toString();
  }

  /// Speaks the provided text aloud. If the same message is already playing, stops it.
  Future<void> toggleSpeak(String text, {required String messageId}) async {
    if (currentlySpeakingIdNotifier.value == messageId) {
      await stop();
    } else {
      await speak(text, messageId: messageId);
    }
  }

  /// Internal helper to stop all audio outputs without clearing speaking id
  Future<void> _stopAudioOutputs() async {
    try {
      if (_audioPlayer != null) {
        await _audioPlayer!.stop().catchError((_) => null);
      }
      await _flutterTts.stop().catchError((_) => null);
    } catch (e) {
      debugPrint('[TtsVoiceService] Stop audio notice: $e');
    }
  }

  /// Speaks text aloud using hyper-realistic female neural voice (en-US-AriaNeural)
  /// with automatic fallback to high-quality on-device neural voice.
  Future<void> speak(String text, {required String messageId}) async {
    final cleanText = cleanMarkdownForSpeech(text);
    if (cleanText.isEmpty) return;

    try {
      await _stopAudioOutputs();
      currentlySpeakingIdNotifier.value = messageId;

      bool playedWithNeural = false;

      // Tier 1: Microsoft Edge Neural TTS (en-US-AriaNeural)
      // Highly regarded in the AI community for realistic emotional warmth and human prosody.
      try {
        final communicate = Communicate(
          text: cleanText,
          voice: naturalFemaleVoice,
          rate: '+0%',
          pitch: '+0Hz',
          volume: '+0%',
        );
        final bytes = await communicate.toBytes().timeout(const Duration(seconds: 5));
        if (bytes.isNotEmpty && _audioPlayer != null) {
          await _audioPlayer!.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
          playedWithNeural = true;
        }
      } catch (neuralErr) {
        debugPrint('[TtsVoiceService] Neural audio streaming notice: $neuralErr. Using on-device fallback.');
      }

      // Tier 2: Seamless zero-latency fallback to on-device female neural voice
      if (!playedWithNeural) {
        await _flutterTts.speak(cleanText).catchError((_) => null);
      }
    } catch (e) {
      debugPrint('[TtsVoiceService] Speak notice: $e');
      currentlySpeakingIdNotifier.value = null;
    }
  }

  /// Stops current speech output
  Future<void> stop() async {
    await _stopAudioOutputs();
    currentlySpeakingIdNotifier.value = null;
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
      _playerCompleteSubscription?.cancel();
      _audioPlayer?.stop().catchError((_) => null);
      _audioPlayer?.dispose().catchError((_) => null);
      _flutterTts.stop().catchError((_) => null);
    } catch (_) {}
    currentlySpeakingIdNotifier.dispose();
    autoSpeakEnabledNotifier.dispose();
  }
}
