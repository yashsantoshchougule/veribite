import 'dart:typed_data';

/// Unified single-camera frame stream to prevent hardware lock between
/// barcode scanning and ML Kit OCR recognition (Phase 1 Fallback Specification).
abstract class UnifiedCameraStreamContract {
  Stream<Uint8List> get cameraFrameStream;
  void onBarcodeDetected(String barcode);
  void onTextRecognized(String rawOcrText);
  Future<void> setTorchMode(bool enabled);
}
