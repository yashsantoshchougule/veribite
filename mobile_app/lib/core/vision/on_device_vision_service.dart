import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'on_device_nutrition_parser.dart';

/// On-Device Computer Vision Service using Google ML Kit Text Recognition
/// Runs entirely on the device CPU/NPU without requiring network access, Gemini API keys,
/// or external server proxies.
class OnDeviceVisionService {
  final Future<String> Function(List<int> frameBytes)? _injectedOcrEngine;

  OnDeviceVisionService({
    Future<String> Function(List<int> frameBytes)? injectedOcrEngine,
  }) : _injectedOcrEngine = injectedOcrEngine;

  /// Analyzes one or more captured package frames locally using ML Kit and regex parsing.
  /// Returns structured product map with `source: 'on_device_vision'`, or null if no text found.
  Future<Map<String, dynamic>?> analyzeFrames(List<List<int>> frames) async {
    if (frames.isEmpty) return null;

    // Pick highest resolution frame
    List<int> bestFrame = frames.first;
    for (final frame in frames) {
      if (frame.length > bestFrame.length) {
        bestFrame = frame;
      }
    }

    if (bestFrame.length < 50) return null;

    try {
      String recognizedText;

      if (_injectedOcrEngine != null) {
        recognizedText = await _injectedOcrEngine(bestFrame);
      } else {
        // Native Google ML Kit Text Recognition
        recognizedText = await _recognizeWithMlKit(bestFrame);
      }

      if (recognizedText.trim().isEmpty) {
        debugPrint('[OnDeviceVisionService] No text recognized on frame.');
        return null;
      }

      debugPrint('[OnDeviceVisionService] Recognized ${recognizedText.length} chars locally.');
      return OnDeviceNutritionParser.parseFromText(recognizedText);
    } catch (e) {
      debugPrint('[OnDeviceVisionService] Local OCR analysis notice: $e');
      return null;
    }
  }

  /// Executes ML Kit Latin text recognizer by creating an ephemeral temporary JPEG file
  Future<String> _recognizeWithMlKit(List<int> frameBytes) async {
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.jpg');

    try {
      await tempFile.writeAsBytes(frameBytes);
      final inputImage = InputImage.fromFile(tempFile);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

      try {
        final recognized = await textRecognizer.processImage(inputImage);
        return recognized.text;
      } finally {
        await textRecognizer.close();
      }
    } finally {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    }
  }
}
