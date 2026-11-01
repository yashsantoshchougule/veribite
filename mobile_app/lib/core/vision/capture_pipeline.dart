/// Coordinator for the 3-Tier Self-Scaling Hybrid Capture Pipeline.

import 'barcode_scanner_service.dart';

enum CaptureTier {
  tier1Barcode,
  tier2Ocr,
  tier3CloudVision,
  manualFallback,
}

class CapturePipelineCoordinator {
  final Duration barcodeTimeout;
  final double ocrConfidenceThreshold;

  const CapturePipelineCoordinator({
    this.barcodeTimeout = const Duration(milliseconds: 1800),
    this.ocrConfidenceThreshold = 0.65,
  });

  CaptureTier determineTier({
    String? rawBarcode,
    Duration elapsedScanning = Duration.zero,
    double? ocrConfidence,
    bool isCurvedOrGlare = false,
    bool hasNetwork = true,
  }) {
    // 1. Tier 1: Valid Barcode detected
    if (rawBarcode != null) {
      final normalized = validateAndNormalizeBarcode(rawBarcode);
      if (normalized != null) {
        return CaptureTier.tier1Barcode;
      }
    }

    // If still within barcode scanning window and no OCR available yet, wait
    if (elapsedScanning < barcodeTimeout && ocrConfidence == null) {
      return CaptureTier.tier1Barcode;
    }

    // 2. Tier 2: OCR with sufficient confidence (>= 65%) and no extreme glare/curvature
    if (ocrConfidence != null && ocrConfidence >= ocrConfidenceThreshold && !isCurvedOrGlare) {
      return CaptureTier.tier2Ocr;
    }

    // 3. Tier 3: Low OCR confidence or curved bottle with active network connection
    if (hasNetwork) {
      return CaptureTier.tier3CloudVision;
    }

    // 4. Fallback: Offline mode with poor OCR -> Quick manual macro slider
    return CaptureTier.manualFallback;
  }
}

