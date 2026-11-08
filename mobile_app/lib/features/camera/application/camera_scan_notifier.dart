import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/core/vision/barcode_scanner_service.dart';
import 'package:mobile_app/core/vision/ocr_parser.dart';
import 'package:mobile_app/features/camera/domain/camera_scan_state.dart';

final cameraScanNotifierProvider =
    StateNotifierProvider<CameraScanNotifier, CameraScanState>((ref) {
  return CameraScanNotifier();
});

class CameraScanNotifier extends StateNotifier<CameraScanState> {
  CameraScanNotifier() : super(const CameraScanState());

  void onBarcodeScanned(String rawBarcode) {
    final parsed = parseQrOrBarcode(rawBarcode);
    if (parsed.isValid) {
      state = state.copyWith(
        status: CameraScanStatus.barcodeLocked,
        barcode: parsed.barcode ?? parsed.rawInput,
      );
    }
  }

  void onLuminanceSample(List<int> pixels) {
    final glareResult = detectSpecularGlare(pixels);
    if (glareResult['is_glare'] == true) {
      state = state.copyWith(
        hasGlareAlert: true,
        glareBadgeText: glareResult['badge'] as String?,
      );
    } else if (state.hasGlareAlert) {
      state = state.copyWith(
        hasGlareAlert: false,
        glareBadgeText: null,
      );
    }
  }

  void setMultiAngleMode(bool enabled) {
    state = state.copyWith(
      isMultiAngleMode: enabled,
      capturedFrames: enabled ? state.capturedFrames : const [],
    );
  }

  void addMultiAngleFrame(List<int> frameBytes) {
    if (state.capturedFrames.length < 4) {
      final updated = List<List<int>>.from(state.capturedFrames)..add(frameBytes);
      state = state.copyWith(capturedFrames: updated);
    }
  }

  void clearMultiAngleFrames() {
    state = state.copyWith(capturedFrames: const []);
  }

  void toggleTorch() {
    state = state.copyWith(isTorchOn: !state.isTorchOn);
  }

  void setFocusPoint(Offset point) {
    state = state.copyWith(
      focusPoint: point,
      isFocusLocked: true,
    );
  }

  void clearFocus() {
    state = state.copyWith(
      clearFocusPoint: true,
      isFocusLocked: false,
    );
  }

  void setZoomScale(double scale) {
    state = state.copyWith(zoomScale: scale);
  }

  void reset() {
    state = const CameraScanState();
  }
}
