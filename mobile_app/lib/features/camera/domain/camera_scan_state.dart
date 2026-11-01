/// Camera scan status and reactive state models.

enum CameraScanStatus {
  searching,
  barcodeLocked,
  ocrProcessing,
  resolved,
  error,
}

class CameraScanState {
  final CameraScanStatus status;
  final String? barcode;
  final bool hasGlareAlert;
  final String? glareBadgeText;
  final bool isMultiAngleMode;
  final List<List<int>> capturedFrames;
  final bool isTorchOn;
  final String? errorMessage;

  const CameraScanState({
    this.status = CameraScanStatus.searching,
    this.barcode,
    this.hasGlareAlert = false,
    this.glareBadgeText,
    this.isMultiAngleMode = false,
    this.capturedFrames = const [],
    this.isTorchOn = false,
    this.errorMessage,
  });

  CameraScanState copyWith({
    CameraScanStatus? status,
    String? barcode,
    bool? hasGlareAlert,
    String? glareBadgeText,
    bool? isMultiAngleMode,
    List<List<int>>? capturedFrames,
    bool? isTorchOn,
    String? errorMessage,
  }) {
    return CameraScanState(
      status: status ?? this.status,
      barcode: barcode ?? this.barcode,
      hasGlareAlert: hasGlareAlert ?? this.hasGlareAlert,
      glareBadgeText: glareBadgeText ?? this.glareBadgeText,
      isMultiAngleMode: isMultiAngleMode ?? this.isMultiAngleMode,
      capturedFrames: capturedFrames ?? this.capturedFrames,
      isTorchOn: isTorchOn ?? this.isTorchOn,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
