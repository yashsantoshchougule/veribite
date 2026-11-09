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
        final spatial = reconstructSpatialText(recognized);
        return '$spatial\n\n=== RAW OCR ===\n${recognized.text}';
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

  /// Spatially reconstructs multi-column text by grouping lines that share vertical Y-coordinate overlap.
  /// Prevents column-separated tables from splitting parameter names from numeric values.
  static String reconstructSpatialText(RecognizedText recognized) {
    final allLines = <TextLine>[];
    for (final block in recognized.blocks) {
      allLines.addAll(block.lines);
    }
    if (allLines.isEmpty) return recognized.text;

    final validLines = allLines.where((l) => l.text.trim().isNotEmpty).toList();
    if (validLines.isEmpty) return recognized.text;

    // Sort primarily by top Y coordinate
    validLines.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    // Cluster lines into horizontal rows based on vertical Y-midpoint overlap
    final rows = <List<TextLine>>[];
    for (final line in validLines) {
      final lineBox = line.boundingBox;
      final lineHeight = lineBox.height > 0 ? lineBox.height : 12.0;
      final lineMidY = lineBox.top + (lineHeight / 2.0);

      int targetRowIndex = -1;
      for (int i = 0; i < rows.length; i++) {
        final row = rows[i];
        final rowHeights = row.map((l) => l.boundingBox.height).where((h) => h > 0);
        final avgHeight = rowHeights.isNotEmpty
            ? rowHeights.reduce((a, b) => a + b) / rowHeights.length
            : 12.0;
        final rowMidYs = row.map((l) => l.boundingBox.top + (l.boundingBox.height / 2.0));
        final avgMidY = rowMidYs.reduce((a, b) => a + b) / rowMidYs.length;

        // Group into same row if vertical distance between midpoints is within 65% of line height
        if ((lineMidY - avgMidY).abs() <= (avgHeight * 0.65)) {
          targetRowIndex = i;
          break;
        }
      }

      if (targetRowIndex != -1) {
        rows[targetRowIndex].add(line);
      } else {
        rows.add([line]);
      }
    }

    // Sort each row horizontally left-to-right
    final sortedRows = <({double avgY, String text})>[];
    for (final row in rows) {
      row.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      final rowText = row.map((l) => l.text.trim()).join('   ');
      final avgY = row.map((l) => l.boundingBox.top).reduce((a, b) => a + b) / row.length;
      sortedRows.add((avgY: avgY, text: rowText));
    }

    // Sort rows top-to-bottom
    sortedRows.sort((a, b) => a.avgY.compareTo(b.avgY));

    return sortedRows.map((r) => r.text).join('\n');
  }
}
