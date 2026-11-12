import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:edge_tts/edge_tts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../camera/application/product_scanner_service.dart';
import '../../profile/application/user_profile_manager.dart';
import '../../profile/domain/user_profile_model.dart';
import 'regional_voice_script_builder.dart';

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

  /// Multilingual Microsoft Edge Neural TTS voices mapped to supported Indian locales
  static const Map<String, String> _edgeNeuralVoices = {
    'hi-IN': 'hi-IN-SwaraNeural',
    'mr-IN': 'mr-IN-AarohiNeural',
    'ta-IN': 'ta-IN-PallaviNeural',
    'te-IN': 'te-IN-ShrutiNeural',
    'en-IN': 'en-IN-NeerjaNeural',
    'en-US': 'en-US-AriaNeural',
  };

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
  /// matching the user's selected regional voice readout language.
  static String buildVerdictSpeechSummary({
    required ScannedProductResult product,
    required UserProfileModel userProfile,
    RegionalVoiceLanguage? language,
  }) {
    return RegionalVoiceScriptBuilder.build(
      product: product,
      userProfile: userProfile,
      language: language,
    );
  }

  /// Speaks the provided text aloud. If the same message is already playing, stops it.
  Future<void> toggleSpeak(
    String text, {
    required String messageId,
    RegionalVoiceLanguage? language,
  }) async {
    if (currentlySpeakingIdNotifier.value == messageId) {
      await stop();
    } else {
      await speak(text, messageId: messageId, language: language);
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

  /// Speaks text aloud using hyper-realistic neural voice matching the user's
  /// regional voice language preference with automatic fallback to high-quality
  /// on-device neural voice via FlutterTts.
  Future<void> speak(
    String text, {
    required String messageId,
    RegionalVoiceLanguage? language,
  }) async {
    final cleanText = cleanMarkdownForSpeech(text);
    if (cleanText.isEmpty) return;

    try {
      // 1. Immediately stop any active audio playback
      await _stopAudioOutputs();

      // 2. Read latest selected language directly from UserProfileManager.instance
      final activeProfile = UserProfileManager.instance.profile;
      final voiceLang = language ??
          RegionalVoiceLanguage.fromString(activeProfile.language);
      final localeCode = voiceLang.localeCode; // e.g. 'hi-IN', 'mr-IN', 'ta-IN', 'te-IN', 'en-IN'

      currentlySpeakingIdNotifier.value = messageId;

      bool playedWithNeural = false;

      // Tier 1: Microsoft Edge Neural TTS with language-specific neural voice
      try {
        final edgeVoice = _edgeNeuralVoices[localeCode] ?? 'en-IN-NeerjaNeural';
        final communicate = Communicate(
          text: cleanText,
          voice: edgeVoice,
          rate: '+0%',
          pitch: '+0Hz',
          volume: '+0%',
        );
        final bytes = await communicate.toBytes().timeout(const Duration(milliseconds: 3500));
        if (bytes.isNotEmpty && _audioPlayer != null) {
          await _audioPlayer!.play(BytesSource(bytes, mimeType: 'audio/mpeg'));
          playedWithNeural = true;
        }
      } catch (neuralErr) {
        debugPrint('[TtsVoiceService] Neural audio streaming notice: $neuralErr. Using on-device fallback.');
      }

      // Tier 2: Seamless zero-latency fallback to on-device FlutterTts with locale configuration
      if (!playedWithNeural) {
        await _flutterTts.stop().catchError((_) => null);
        await _flutterTts.setSpeechRate(0.48).catchError((_) => null);
        await _flutterTts.setPitch(1.0).catchError((_) => null);
        await _flutterTts.setLanguage(localeCode).catchError((_) => null);

        // Query available voices and bind matching native voice if installed
        try {
          final dynamic voices = await _flutterTts.getVoices;
          if (voices is List && voices.isNotEmpty) {
            final targetLangPrefix = localeCode.split('-').first.toLowerCase();
            final targetLocaleNorm = localeCode.toLowerCase().replaceAll('_', '-');
            Map<String, String>? matchingVoice;

            for (final v in voices) {
              if (v is Map) {
                final vLocale = (v['locale'] ?? '').toString().toLowerCase().replaceAll('_', '-');
                final vName = (v['name'] ?? '').toString().toLowerCase();

                if (vLocale == targetLocaleNorm ||
                    vLocale.startsWith('$targetLangPrefix-') ||
                    vLocale.startsWith('${targetLangPrefix}_') ||
                    vName.contains(targetLocaleNorm) ||
                    vName.contains(targetLangPrefix)) {
                  matchingVoice = Map<String, String>.from(
                    v.map((k, val) => MapEntry(k.toString(), val.toString())),
                  );
                  break;
                }
              }
            }

            if (matchingVoice != null) {
              await _flutterTts.setVoice(matchingVoice).catchError((_) => null);
            }
          }
        } catch (voiceErr) {
          debugPrint('[TtsVoiceService] Voice binding error: $voiceErr');
        }

        await _flutterTts.speak(cleanText).catchError((e) {
          debugPrint('[TtsVoiceService] FlutterTts speak error: $e');
          return null;
        });
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
