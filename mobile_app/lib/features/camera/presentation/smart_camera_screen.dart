import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/application/home_dashboard_service.dart';
import '../../profile/application/user_profile_service.dart';
import '../../profile/domain/user_profile_model.dart';
import '../application/camera_scan_notifier.dart';
import '../application/offline_barcode_repository.dart';
import '../application/product_scanner_service.dart';
import 'widgets/camera_reticle_painter.dart';
import 'widgets/backend_settings_sheet.dart';
import 'widgets/glare_alert_banner.dart';
import 'widgets/multi_angle_capture_strip.dart';
import 'widgets/offline_variant_match_sheet.dart';
import 'widgets/quick_macro_slider_sheet.dart';
import 'widgets/scan_result_sheet.dart';
import '../../results/presentation/verdict_report_screen.dart';

/// Alias for unified in-app barcode and nutrition label scanner
typedef UnifiedProductScannerScreen = SmartCameraScreen;

/// Smart Camera Viewfinder Screen for VeriBite.
/// Unified in-app CameraX session that continuously scans 1D/2D barcodes,
/// detects packaging nutrition tables in real-time with smart auto-capture,
/// and captures high-resolution nutrition/ingredient photos directly in-app
/// without ever launching external system camera intents.
class SmartCameraScreen extends ConsumerStatefulWidget {
  final String? userId;
  final UserProfileModel? userProfile;
  final ValueChanged<Map<String, dynamic>>? onProductResolved;
  final bool useSimulatedFeed;
  final bool disableResultSheet;
  final ProductScannerService? productService;

  const SmartCameraScreen({
    super.key,
    this.userId,
    this.userProfile,
    this.onProductResolved,
    this.useSimulatedFeed = false,
    this.disableResultSheet = false,
    this.productService,
  });

  @override
  ConsumerState<SmartCameraScreen> createState() => _SmartCameraScreenState();
}

enum CameraScanMode { barcodeQr, nutritionLabel, multiAngle }

class _SmartCameraScreenState extends ConsumerState<SmartCameraScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  late final BarcodeScanner _barcodeScanner;
  late final TextRecognizer _textRecognizer;
  late final ProductScannerService _productService;
  UserProfileModel? _profile;

  bool _isProcessingScan = false;
  bool _isProcessingFrame = false;
  late bool _isLiveScanMode;
  bool _isSheetOpen = false;
  bool _isCameraInitialized = false;
  String? _cameraError;

  CameraScanMode _scanMode = CameraScanMode.barcodeQr;
  List<int>? _capturedPreviewBytes;
  bool _showCapturePreviewOverlay = false;

  String? _lastDismissedPayload;
  DateTime? _lastDismissedTime;
  Timer? _qrDebounceTimer;
  String? _pendingQrPayload;
  String? _activeScanningStatus;
  String? _pendingBindingBarcode;

  // Real-time nutrition table detection
  DateTime _lastBarcodeScanTime = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastOcrScanTime = DateTime.fromMillisecondsSinceEpoch(0);
  int _nutritionDetectedCycles = 0;
  bool _isNutritionLabelDetected = false;
  bool _isAutoCaptureEnabled = false;

  // Zoom & Focus
  double _baseZoomScale = 1.0;
  double _currentZoomScale = 1.0;
  int _activePointers = 0;
  bool _isZoomDispatching = false;
  double? _pendingZoomRatio;
  DateTime _lastHardwareZoomTime = DateTime.fromMillisecondsSinceEpoch(0);
  final ValueNotifier<double> _zoomScaleNotifier = ValueNotifier<double>(1.0);
  final ValueNotifier<bool> _isPinchingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<Offset?> _tapFocusOffset = ValueNotifier<Offset?>(null);
  Timer? _zoomOverlayTimer;
  Timer? _zoomThrottleTimer;
  Timer? _focusResetTimer;
  Timer? _tapFocusTimer;

  static const List<String> _nutritionKeywords = [
    'nutrition',
    'nutritional',
    'energy',
    'calories',
    'kcal',
    'protein',
    'carbohydrate',
    'sugar',
    'added sugar',
    'fat',
    'saturated fat',
    'trans fat',
    'sodium',
    'salt',
    'cholesterol',
    'dietary fiber',
    'serving size',
    'per 100g',
    'per serve',
    'ingredients',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isLiveScanMode = !widget.disableResultSheet;
    _productService = widget.productService ?? ProductScannerService();
    _profile = widget.userProfile;

    _barcodeScanner = BarcodeScanner(formats: const [BarcodeFormat.all]);
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    if (_profile == null && widget.userId != null) {
      _loadProfile();
    }

    if (!widget.useSimulatedFeed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraError = 'No camera found on device');
        return;
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      ImageFormatGroup formatGroup = ImageFormatGroup.yuv420;
      try {
        if (Platform.isAndroid) {
          formatGroup = ImageFormatGroup.nv21;
        } else if (Platform.isIOS) {
          formatGroup = ImageFormatGroup.bgra8888;
        }
      } catch (_) {}

      final controller = CameraController(
        backCamera,
        ResolutionPreset.veryHigh,
        enableAudio: false,
        imageFormatGroup: formatGroup,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      _cameraController = controller;
      setState(() {
        _isCameraInitialized = true;
        _cameraError = null;
      });

      await _startImageStreaming();
    } catch (e) {
      debugPrint('[SmartCameraScreen] Error initializing camera: $e');
      if (mounted) {
        setState(() => _cameraError = 'Camera init failed: $e');
      }
    }
  }

  Future<void> _startImageStreaming() async {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isStreamingImages) return;

    try {
      await controller.startImageStream(_onCameraImageAvailable);
    } catch (e) {
      debugPrint('[SmartCameraScreen] Error starting image stream: $e');
    }
  }

  Future<void> _stopImageStreaming() async {
    final controller = _cameraController;
    if (controller != null && controller.value.isInitialized && controller.value.isStreamingImages) {
      try {
        await controller.stopImageStream();
      } catch (_) {}
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopImageStreaming();
      controller.dispose();
      _cameraController = null;
      if (mounted) setState(() => _isCameraInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _loadProfile() async {
    final service = UserProfileService();
    final p = await service.getProfile(widget.userId!);
    if (mounted) {
      setState(() => _profile = p);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _qrDebounceTimer?.cancel();
    _zoomOverlayTimer?.cancel();
    _zoomThrottleTimer?.cancel();
    _focusResetTimer?.cancel();
    _tapFocusTimer?.cancel();
    _zoomScaleNotifier.dispose();
    _isPinchingNotifier.dispose();
    _tapFocusOffset.dispose();
    _barcodeScanner.close();
    _textRecognizer.close();
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _onCameraImageAvailable(CameraImage image) async {
    if (_isProcessingScan || _isSheetOpen || _isProcessingFrame) return;

    final now = DateTime.now();
    // 200ms throttle for frame processing
    if (now.difference(_lastBarcodeScanTime).inMilliseconds < 200) {
      return;
    }

    _isProcessingFrame = true;
    _lastBarcodeScanTime = now;

    try {
      final inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) return;

      // 1. Barcode / QR detection (Paused when user is in Capture Nutrition Label mode to prevent edge barcode hijacking)
      if (_scanMode == CameraScanMode.barcodeQr) {
        final barcodes = await _barcodeScanner.processImage(inputImage);
        if (barcodes.isNotEmpty) {
          if (_isNutritionLabelDetected) {
            setState(() {
              _isNutritionLabelDetected = false;
              _nutritionDetectedCycles = 0;
            });
          }
          _handleBarcodeCapture(barcodes);
          return;
        }
      }

      // 2. Smart Nutrition Table Auto-Detector (every 600ms when no barcode in view)
      if (now.difference(_lastOcrScanTime).inMilliseconds >= 600) {
        _lastOcrScanTime = now;
        await _checkNutritionText(inputImage);
      }
    } catch (e) {
      debugPrint('[SmartCameraScreen] Error processing frame: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    try {
      final controller = _cameraController;
      if (controller == null) return null;

      final camera = controller.description;
      final sensorOrientation = camera.sensorOrientation;
      InputImageRotation? rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
      rotation ??= InputImageRotation.rotation0deg;

      InputImageFormat? format;
      if (image.format.raw is int) {
        format = InputImageFormatValue.fromRawValue(image.format.raw as int);
      }
      try {
        format ??= (Platform.isAndroid ? InputImageFormat.nv21 : InputImageFormat.bgra8888);
      } catch (_) {
        format ??= InputImageFormat.nv21;
      }

      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: image.planes.first.bytesPerRow,
        ),
      );
    } catch (e) {
      debugPrint('[SmartCameraScreen] Error converting CameraImage: $e');
      return null;
    }
  }

  Future<void> _checkNutritionText(InputImage inputImage) async {
    if (_isProcessingScan || _isSheetOpen) return;

    try {
      final recognizedText = await _textRecognizer.processImage(inputImage);
      final text = recognizedText.text.toLowerCase();

      int matchCount = 0;
      for (final keyword in _nutritionKeywords) {
        if (text.contains(keyword)) {
          matchCount++;
          if (matchCount >= 3) break;
        }
      }

      if (matchCount >= 3) {
        _nutritionDetectedCycles++;
        if (!_isNutritionLabelDetected && mounted) {
          setState(() => _isNutritionLabelDetected = true);
        }

        // Auto-capture if held steady for 2 consecutive cycles (~1.2s)
        if (_nutritionDetectedCycles >= 2 && _isAutoCaptureEnabled && !_isProcessingScan && !_isSheetOpen) {
          _nutritionDetectedCycles = 0;
          await _captureNutritionLabelFromActiveCamera();
        }
      } else {
        if (_nutritionDetectedCycles > 0 || _isNutritionLabelDetected) {
          _nutritionDetectedCycles = 0;
          if (mounted) setState(() => _isNutritionLabelDetected = false);
        }
      }
    } catch (e) {
      debugPrint('[SmartCameraScreen] Error recognizing text on stream: $e');
    }
  }

  void _handleBarcodeCapture(List<Barcode> barcodes) {
    if (_isProcessingScan || _isSheetOpen) return;

    Barcode? oneDBarcode;
    Barcode? qrBarcode;

    for (final b in barcodes) {
      final raw = b.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;

      if (b.format == BarcodeFormat.ean13 ||
          b.format == BarcodeFormat.ean8 ||
          b.format == BarcodeFormat.upca ||
          b.format == BarcodeFormat.upce ||
          RegExp(r'^\d{8,14}$').hasMatch(raw)) {
        oneDBarcode = b;
        break;
      } else if (b.format == BarcodeFormat.qrCode ||
          raw.startsWith('http://') ||
          raw.startsWith('https://') ||
          raw.startsWith('{')) {
        qrBarcode ??= b;
      }
    }

    // STAGE 1 PRIORITY: 1D product barcode processes IMMEDIATELY, canceling any pending QR debounce
    if (oneDBarcode != null) {
      _qrDebounceTimer?.cancel();
      _qrDebounceTimer = null;
      _pendingQrPayload = null;

      final trimmed = oneDBarcode.rawValue!.trim();
      if (_lastDismissedPayload != null &&
          _lastDismissedTime != null &&
          trimmed == _lastDismissedPayload &&
          DateTime.now().difference(_lastDismissedTime!) < const Duration(milliseconds: 2500)) {
        return;
      }
      _onBarcodeDetected(trimmed);
      return;
    }

    // If only a QR code is detected:
    if (qrBarcode != null) {
      final trimmed = qrBarcode.rawValue!.trim();
      final lower = trimmed.toLowerCase();

      // Immediately reject non-web QR payloads (e.g. upi://, WIFI:, tel:, mailto:, vCard) without debounce
      if (lower.startsWith('upi:') ||
          lower.startsWith('wifi:') ||
          lower.startsWith('tel:') ||
          lower.startsWith('mailto:') ||
          lower.startsWith('begin:vcard')) {
        _qrDebounceTimer?.cancel();
        _qrDebounceTimer = null;
        _pendingQrPayload = null;
        _onBarcodeDetected(trimmed);
        return;
      }

      // Check 2.5s dismissal debounce
      if (_lastDismissedPayload != null &&
          _lastDismissedTime != null &&
          trimmed == _lastDismissedPayload &&
          DateTime.now().difference(_lastDismissedTime!) < const Duration(milliseconds: 2500)) {
        return;
      }

      // If a QR debounce timer is already running: continue
      if (_qrDebounceTimer != null && _qrDebounceTimer!.isActive) {
        return;
      }

      // Stage 1: Buffer QR payload for 450ms while listening for 1D barcode
      _pendingQrPayload = trimmed;

      _qrDebounceTimer = Timer(const Duration(milliseconds: 450), () {
        if (!mounted || _isProcessingScan || _isSheetOpen) return;
        final payload = _pendingQrPayload;
        _pendingQrPayload = null;
        if (payload != null) {
          _onBarcodeDetected(payload);
        }
      });
    }
  }

  Future<void> _onBarcodeDetected(String rawBarcode, {List<int>? frameImage}) async {
    if (!_isLiveScanMode) {
      await HapticFeedback.selectionClick();
      debugPrint('[Camera Test Mode] Barcode detected: $rawBarcode (Result report suppressed in test mode)');
      return;
    }

    if (_isProcessingScan || _isSheetOpen) return;
    setState(() => _isProcessingScan = true);

    final notifier = ref.read(cameraScanNotifierProvider.notifier);
    notifier.onBarcodeScanned(rawBarcode);

    final activeProfile = _profile ?? UserProfileModel.defaults(widget.userId ?? 'guest_user');

    try {
      unawaited(HapticFeedback.mediumImpact().catchError((_) => null));
      final resolvedProduct = await _productService.resolveScanInput(
        rawScan: rawBarcode,
        userProfile: activeProfile,
        frameImage: frameImage,
        onStatusUpdate: (msg) {
          if (mounted) setState(() => _activeScanningStatus = msg);
        },
      );

      if (!mounted) return;
      setState(() => _isProcessingScan = false);
      if (mounted) setState(() => _isProcessingScan = false);
      await _showScanResultReport(resolvedProduct, activeProfile);
    } on OfflineVariantMatchException catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingScan = false);
      await _showOfflineVariantMatchSheet(e);
    } on PromotionalQrContextException catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingScan = false);
      await _showPromotionalQrContextSheet(e);
    } on NonFoodScanException catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingScan = false);
      await _showNonFoodDialog(e.message, rawBarcode);
    } on ProductNotFoundException catch (e) {
      if (!mounted) return;
      setState(() {
        _isProcessingScan = false;
        _pendingBindingBarcode = e.barcode;
      });
      await _showProductNotFoundDialog(e.barcode);
    } on FoodWebExtractionException catch (e) {
      if (!mounted) return;
      setState(() => _isProcessingScan = false);
      await _showWebExtractionFailedDialog(e.url);
    } on VisionExtractionException catch (e) {
      setState(() => _isProcessingScan = false);
      debugPrint('[SmartCameraScreen] Vision extraction failed: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.safetyRed,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Sliders',
              textColor: Colors.white,
              onPressed: _openMacroSliderSheet,
            ),
          ),
        );
      }
    } catch (e, st) {
      setState(() => _isProcessingScan = false);
      debugPrint('Error resolving scan $rawBarcode: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not resolve product for scan: $rawBarcode'),
            backgroundColor: AppColors.safetyRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingScan = false;
          _activeScanningStatus = null;
        });
      }
    }
  }

  /// Instant in-app capture of Nutrition Information & Ingredient label
  /// Locks autofocus with 350ms settle delay, takes a high-res frame,
  /// and shows an in-app confirmation preview overlay before data extraction.
  Future<void> _captureNutritionLabelFromActiveCamera() async {
    if (_isProcessingScan || _isSheetOpen) return;
    unawaited(HapticFeedback.heavyImpact().catchError((_) => null));

    setState(() {
      _isProcessingScan = true;
      _activeScanningStatus = 'Locking focus & capturing sharp photo...';
    });

    try {
      // 1. Lock hardware focus and exposure with 350ms settle delay so lens is razor sharp
      if (!widget.useSimulatedFeed && _cameraController != null && _cameraController!.value.isInitialized) {
        try {
          await _cameraController!.setFocusMode(FocusMode.locked);
          await Future.delayed(const Duration(milliseconds: 350));
        } catch (e) {
          debugPrint('[SmartCameraScreen] Focus lock notice: $e');
        }
      }

      List<int> frameBytes;
      if (widget.useSimulatedFeed) {
        frameBytes = List<int>.generate(200, (i) => (i * 7) % 256);
      } else {
        if (_cameraController == null || !_cameraController!.value.isInitialized) {
          throw Exception('Camera is not initialized');
        }
        await _stopImageStreaming();
        final photo = await _cameraController!.takePicture();
        frameBytes = await photo.readAsBytes();
      }

      if (!mounted) return;

      setState(() {
        _isProcessingScan = false;
        _capturedPreviewBytes = frameBytes;
        _showCapturePreviewOverlay = true;
      });
    } catch (e) {
      debugPrint('[SmartCameraScreen] Error capturing photo: $e');
      if (mounted) {
        setState(() => _isProcessingScan = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Camera capture failed: $e'),
            backgroundColor: AppColors.safetyRed,
          ),
        );
      }
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedPreviewBytes = null;
      _showCapturePreviewOverlay = false;
      _isProcessingScan = false;
    });
    if (!widget.useSimulatedFeed && _cameraController != null && _cameraController!.value.isInitialized) {
      unawaited(_cameraController!.setFocusMode(FocusMode.auto).catchError((_) => null));
      unawaited(_startImageStreaming().catchError((_) => null));
    }
  }

  Future<String?> _detectBarcodeFromFrames(List<List<int>> frames) async {
    if (widget.useSimulatedFeed) return null;
    for (final frame in frames) {
      if (frame.length < 50) continue;
      try {
        final tempDir = Directory.systemTemp;
        final tempFile = File('${tempDir.path}/bc_detect_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(frame);
        final inputImg = InputImage.fromFile(tempFile);
        final barcodes = await _barcodeScanner.processImage(inputImg).timeout(const Duration(milliseconds: 600));
        if (await tempFile.exists()) {
          try {
            await tempFile.delete();
          } catch (_) {}
        }
        if (barcodes.isNotEmpty && barcodes.first.rawValue != null && barcodes.first.rawValue!.isNotEmpty) {
          debugPrint('[SmartCameraScreen] Detected embedded barcode from frame photo: ${barcodes.first.rawValue}');
          return barcodes.first.rawValue;
        }
      } catch (e) {
        debugPrint('[SmartCameraScreen] Notice detecting barcode from frame: $e');
      }
    }
    return null;
  }

  Future<void> _extractDataFromPreview(List<int> frameBytes) async {
    setState(() {
      _showCapturePreviewOverlay = false;
      _isProcessingScan = true;
      _activeScanningStatus = 'Extracting nutrition facts & additives...';
    });

    try {
      final activeProfile = _profile ?? UserProfileModel.defaults(widget.userId ?? 'guest_user');

      // Opportunistically detect any visible 1D/2D barcode directly on the photographed frame
      String? targetBarcode = _pendingBindingBarcode;
      if (targetBarcode == null || targetBarcode.isEmpty) {
        targetBarcode = await _detectBarcodeFromFrames([frameBytes]);
      }

      final resolvedProduct = await _productService.resolveMultiAngleScan(
        frames: [frameBytes],
        userProfile: activeProfile,
        detectedBarcode: targetBarcode,
      );

      if (!mounted) return;

      // Offline OCR Barcode Binding: bind newly analyzed product to pending/detected barcode in Tier 2 cache
      if (targetBarcode != null && targetBarcode.isNotEmpty) {
        _pendingBindingBarcode = null;
        unawaited(OfflineBarcodeRepository.instance.saveProduct(
          barcode: targetBarcode,
          productData: {
            'barcode': targetBarcode,
            'product_name': resolvedProduct.productName,
            'brand_name': resolvedProduct.brandName,
            'category': resolvedProduct.category,
            'serving_size_g': resolvedProduct.servingSizeG,
            'pack_weight_g': resolvedProduct.packWeightG,
            'health_score': resolvedProduct.healthScore,
            'nova_grade': resolvedProduct.novaGrade,
            'red_cap_triggered': resolvedProduct.redCapTriggered ? 1 : 0,
            'nutrition_json': jsonEncode({
              'energy_kj': resolvedProduct.caloriesPerServing * 4.184,
              'energy_kcal': resolvedProduct.effectiveCaloriesPer100g,
              'sugar_g_per_100g': resolvedProduct.sugarGPer100g,
              'sat_fat_g_per_100g': resolvedProduct.satFatGPer100g,
              'total_fat_g_per_100g': resolvedProduct.totalFatGPer100g,
              'sodium_mg_per_100g': resolvedProduct.sodiumMgPer100g,
              'carbohydrates_g_per_100g': resolvedProduct.carbsGPer100g,
              'protein_g': resolvedProduct.proteinGPer100g,
              'fiber_g': resolvedProduct.fiberGPer100g,
              'added_sugar_g_per_100g': resolvedProduct.addedSugarGPer100g,
              'trans_fat_g_per_100g': resolvedProduct.transFatGPer100g,
              'cholesterol_mg_per_100g': resolvedProduct.cholesterolMgPer100g,
            }),
            if (resolvedProduct.healthIntelligence != null)
              'health_intelligence': resolvedProduct.healthIntelligence!.toJson(),
            'additives_json': jsonEncode(resolvedProduct.additives),
            'ingredients_json': jsonEncode([]),
          },
          isUserLearned: true,
        ));
      }

      if (mounted) setState(() => _isProcessingScan = false);
      await _showScanResultReport(resolvedProduct, activeProfile);
    } on VisionExtractionException catch (e) {
      debugPrint('[SmartCameraScreen] Vision extraction failed: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.safetyRed,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Sliders',
              textColor: Colors.white,
              onPressed: _openMacroSliderSheet,
            ),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[SmartCameraScreen] Error extracting nutrition facts: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not extract nutrition facts. Please steady camera or enter macros.'),
            backgroundColor: AppColors.safetyRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingScan = false;
          _showCapturePreviewOverlay = false;
        });
        if (!widget.useSimulatedFeed) {
          unawaited(_startImageStreaming().catchError((_) => null));
        }
      }
    }
  }

  Widget _buildCapturePreviewOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.92),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.center_focus_strong_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Confirm Photo Clarity',
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: _retakePhoto,
                  tooltip: 'Cancel & Retake',
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Text(
              'Verify that the Nutrition Information table and numbers are sharp and free of plastic glare.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  color: Colors.black,
                  child: (_capturedPreviewBytes != null && _capturedPreviewBytes!.length > 500)
                      ? Image.memory(
                          Uint8List.fromList(_capturedPreviewBytes!),
                          fit: BoxFit.contain,
                        )
                      : Container(
                          alignment: Alignment.center,
                          color: const Color(0xFF1E1E1E),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.table_chart_rounded, color: Color(0xFF0F9D58), size: 56),
                              SizedBox(height: 12),
                              Text(
                                'High-Resolution Nutrition Frame Captured',
                                style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white38),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: _retakePhoto,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retake', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F9D58),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      if (_capturedPreviewBytes != null) {
                        _extractDataFromPreview(_capturedPreviewBytes!);
                      }
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: const Text(
                      'Extract Nutrition Data',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMultiAngleSubmit(List<List<int>> frames) async {
    if (_isProcessingScan || _isSheetOpen || frames.isEmpty) return;

    setState(() => _isProcessingScan = true);
    final activeProfile = _profile ?? UserProfileModel.defaults(widget.userId ?? 'guest_user');

    try {
      unawaited(HapticFeedback.mediumImpact().catchError((_) => null));

      // Opportunistically detect any visible 1D/2D barcode directly on the photographed frames
      String? targetBarcode = _pendingBindingBarcode;
      if (targetBarcode == null || targetBarcode.isEmpty) {
        targetBarcode = await _detectBarcodeFromFrames(frames);
      }

      final resolvedProduct = await _productService.resolveMultiAngleScan(
        frames: frames,
        userProfile: activeProfile,
        detectedBarcode: targetBarcode,
      );

      if (!mounted) return;

      // Offline OCR Barcode Binding: bind newly analyzed product to pending/detected barcode in Tier 2 cache
      if (targetBarcode != null && targetBarcode.isNotEmpty) {
        _pendingBindingBarcode = null;
        unawaited(OfflineBarcodeRepository.instance.saveProduct(
          barcode: targetBarcode,
          productData: {
            'barcode': targetBarcode,
            'product_name': resolvedProduct.productName,
            'brand_name': resolvedProduct.brandName,
            'category': resolvedProduct.category,
            'serving_size_g': resolvedProduct.servingSizeG,
            'pack_weight_g': resolvedProduct.packWeightG,
            'health_score': resolvedProduct.healthScore,
            'nova_grade': resolvedProduct.novaGrade,
            'red_cap_triggered': resolvedProduct.redCapTriggered ? 1 : 0,
            'nutrition_json': jsonEncode({
              'energy_kj': resolvedProduct.caloriesPerServing * 4.184,
              'energy_kcal': resolvedProduct.effectiveCaloriesPer100g,
              'sugar_g_per_100g': resolvedProduct.sugarGPer100g,
              'sat_fat_g_per_100g': resolvedProduct.satFatGPer100g,
              'total_fat_g_per_100g': resolvedProduct.totalFatGPer100g,
              'sodium_mg_per_100g': resolvedProduct.sodiumMgPer100g,
              'carbohydrates_g_per_100g': resolvedProduct.carbsGPer100g,
              'protein_g': resolvedProduct.proteinGPer100g,
              'fiber_g': resolvedProduct.fiberGPer100g,
              'added_sugar_g_per_100g': resolvedProduct.addedSugarGPer100g,
              'trans_fat_g_per_100g': resolvedProduct.transFatGPer100g,
              'cholesterol_mg_per_100g': resolvedProduct.cholesterolMgPer100g,
            }),
            if (resolvedProduct.healthIntelligence != null)
              'health_intelligence': resolvedProduct.healthIntelligence!.toJson(),
            'additives_json': jsonEncode(resolvedProduct.additives),
            'ingredients_json': jsonEncode([]),
          },
          isUserLearned: true,
        ));
      }

      if (mounted) setState(() => _isProcessingScan = false);
      await _showScanResultReport(resolvedProduct, activeProfile);

      ref.read(cameraScanNotifierProvider.notifier).clearMultiAngleFrames();
    } on VisionExtractionException catch (e) {
      debugPrint('[SmartCameraScreen] Vision extraction failed: ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppColors.safetyRed,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Sliders',
              textColor: Colors.white,
              onPressed: _openMacroSliderSheet,
            ),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('Error resolving multi-angle scan: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not complete multi-angle scan. Please retry or enter macros.'),
            backgroundColor: AppColors.safetyRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingScan = false);
        if (!widget.useSimulatedFeed && !_isSheetOpen) {
          unawaited(_startImageStreaming());
        }
      }
    }
  }

  Future<void> _showScanResultReport(ScannedProductResult product, UserProfileModel profile) async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;

    await _stopImageStreaming();

    try {
      if (!mounted) return;
      final dynamic result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VerdictReportScreen(
            product: product,
            userProfile: profile,
          ),
        ),
      );

      if (widget.onProductResolved != null) {
        widget.onProductResolved!({
          'source': 'barcode',
          'product_name': product.productName,
          'health_score': product.healthScore,
          'eaten': result == true,
        });
      }
      ref.read(cameraScanNotifierProvider.notifier).reset();
    } finally {
      _lastDismissedPayload = product.barcode;
      _lastDismissedTime = DateTime.now();
      _isSheetOpen = false;
      if (mounted && !widget.useSimulatedFeed) {
        unawaited(_startImageStreaming());
      }
    }
  }

  Future<void> _showNonFoodDialog(String message, String rawPayload) async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;

    await _stopImageStreaming();

    try {
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1.5)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.safetyRedBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.safetyRedBorder),
                ),
                child: const Icon(Icons.devices_other_rounded, color: AppColors.safetyRed, size: 32),
              ),
              const SizedBox(height: 14),
              const Text(
                'Not a Food Product',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textObsidian,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textMutedMocha,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryObsidian,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Scan Food Product', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      );
    } finally {
      _lastDismissedPayload = rawPayload;
      _lastDismissedTime = DateTime.now();
      _isSheetOpen = false;
      ref.read(cameraScanNotifierProvider.notifier).reset();
      if (mounted && !widget.useSimulatedFeed) {
        unawaited(_startImageStreaming());
      }
    }
  }

  Future<void> _showProductNotFoundDialog(String barcode) async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;

    await _stopImageStreaming();

    try {
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1.5)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.sugarPeachBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.sugarPeachBorder),
                ),
                child: const Icon(Icons.search_off_rounded, color: AppColors.sugarPeachText, size: 32),
              ),
              const SizedBox(height: 14),
              const Text(
                'Product Not Found in Registry',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textObsidian,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Barcode "$barcode" was not found in our global food databases. If this is a real packaged food item, you can scan its nutrition label directly with the camera or enter values manually.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textMutedMocha,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _startLabelOcrForBarcode(barcode);
                      },
                      icon: const Icon(Icons.document_scanner_rounded, size: 16),
                      label: const Text('Scan Label (OCR)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textObsidian,
                        side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _pendingBindingBarcode = barcode;
                        _openMacroSliderSheet();
                      },
                      icon: const Icon(Icons.tune_rounded, size: 16),
                      label: const Text('Enter Macros', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textObsidian,
                        side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryObsidian,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Retry', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } finally {
      _lastDismissedPayload = barcode;
      _lastDismissedTime = DateTime.now();
      _isSheetOpen = false;
      ref.read(cameraScanNotifierProvider.notifier).reset();
      if (mounted && !widget.useSimulatedFeed) {
        unawaited(_startImageStreaming());
      }
    }
  }

  /// Displays intelligent GS1 India Manufacturer Prefix & Pack-Size Sibling Match Sheet
  Future<void> _showOfflineVariantMatchSheet(OfflineVariantMatchException exception) async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;

    await _stopImageStreaming();

    try {
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => OfflineVariantMatchSheet(
          barcode: exception.barcode,
          brandName: exception.brandName,
          siblingProducts: exception.siblingProducts,
          detectedWrapperText: exception.detectedWrapperText,
          detectedProductData: exception.detectedProductData,
          onAnalyzeDetected: (product) async {
            Navigator.of(ctx).pop();
            final activeProfile = _profile ?? UserProfileModel.defaults(widget.userId ?? 'guest_user');
            final evaluated = _productService.evaluateProductData(
              productData: product,
              userProfile: activeProfile,
              barcode: exception.barcode,
            );
            unawaited(OfflineBarcodeRepository.instance.saveProduct(
              barcode: exception.barcode,
              productData: product,
              isUserLearned: true,
            ));
            if (!mounted) return;
            await _showScanResultReport(evaluated, activeProfile);
          },
          onSelectProduct: (product) async {
            Navigator.of(ctx).pop();
            final activeProfile = _profile ?? UserProfileModel.defaults(widget.userId ?? 'guest_user');
            final evaluated = _productService.evaluateProductData(
              productData: product,
              userProfile: activeProfile,
              barcode: exception.barcode,
            );
            // Self-learning: store this variant pack size bound to this product formula
            unawaited(OfflineBarcodeRepository.instance.saveProduct(
              barcode: exception.barcode,
              productData: product,
              isUserLearned: true,
            ));
            if (!mounted) return;
            await _showScanResultReport(evaluated, activeProfile);
          },
          onScanOcr: () {
            Navigator.of(ctx).pop();
            _startLabelOcrForBarcode(exception.barcode);
          },
          onManualEntry: () {
            Navigator.of(ctx).pop();
            _pendingBindingBarcode = exception.barcode;
            _openMacroSliderSheet();
          },
        ),
      );
    } finally {
      _lastDismissedPayload = exception.barcode;
      _lastDismissedTime = DateTime.now();
      _isSheetOpen = false;
      ref.read(cameraScanNotifierProvider.notifier).reset();
      if (mounted && !widget.useSimulatedFeed) {
        unawaited(_startImageStreaming());
      }
    }
  }

  void _startLabelOcrForBarcode(String barcode) {
    setState(() {
      _pendingBindingBarcode = barcode;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Barcode [$barcode] registered. Point camera at Nutrition Facts or Ingredients panel to scan.'),
          backgroundColor: const Color(0xFF0F9D58),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _showWebExtractionFailedDialog(String url) async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;

    await _stopImageStreaming();

    try {
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1.5)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.sugarPeachBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.sugarPeachBorder),
                ),
                child: const Icon(Icons.link_off_rounded, color: AppColors.sugarPeachText, size: 32),
              ),
              const SizedBox(height: 14),
              const Text(
                'Web Link Found, Facts Missing',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textObsidian,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We detected a food product link, but the webpage did not provide verifiable nutrition facts. You can snap a photo of the nutrition label or enter values manually.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textMutedMocha,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        _captureNutritionLabelFromActiveCamera();
                      },
                      icon: const Icon(Icons.camera_alt_rounded, size: 18),
                      label: const Text('Snap Nutrition Label Photo', style: TextStyle(fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4285F4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _openMacroSliderSheet();
                          },
                          icon: const Icon(Icons.tune_rounded, size: 18),
                          label: const Text('Enter Macros', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textObsidian,
                            side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textMutedMocha,
                            side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: const Text('Back to Scanner', style: TextStyle(fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } finally {
      _lastDismissedPayload = url;
      _lastDismissedTime = DateTime.now();
      _isSheetOpen = false;
      ref.read(cameraScanNotifierProvider.notifier).reset();
      if (mounted && !widget.useSimulatedFeed) {
        unawaited(_startImageStreaming());
      }
    }
  }

  Future<void> _showPromotionalQrContextSheet(PromotionalQrContextException exception) async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;

    await _stopImageStreaming();

    String? action;
    try {
      if (!mounted) return;
      final displayTitle = [
        if (exception.brandName != null && exception.brandName!.isNotEmpty) exception.brandName,
        if (exception.productName != null && exception.productName!.isNotEmpty) exception.productName,
      ].join(' ');

      action = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1.5)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F0FE),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF4285F4).withValues(alpha: 0.3)),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Color(0xFF1967D2), size: 32),
                ),
                const SizedBox(height: 14),
                Text(
                  displayTitle.isNotEmpty ? 'Detected $displayTitle' : 'Detected Recipe / Brand QR',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textObsidian,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  exception.message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textMutedMocha,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(ctx).pop('multi_angle'),
                        icon: const Icon(Icons.camera_alt_rounded, size: 18),
                        label: const Text('Scan Backside Nutrition Label', style: TextStyle(fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4285F4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(ctx).pop('macros'),
                            icon: const Icon(Icons.tune_rounded, size: 18),
                            label: const Text('Enter Macros', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textObsidian,
                              side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(ctx).pop('dismiss'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.textMutedMocha,
                              side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('Back to Scanner', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } finally {
      _lastDismissedPayload = exception.url;
      _lastDismissedTime = DateTime.now();
      _isSheetOpen = false;
      if (action == 'multi_angle') {
        ref.read(cameraScanNotifierProvider.notifier).setMultiAngleMode(true);
      } else {
        ref.read(cameraScanNotifierProvider.notifier).reset();
      }
      if (mounted) {
        if (!widget.useSimulatedFeed) {
          unawaited(_startImageStreaming());
        }
        if (action == 'macros') {
          unawaited(_openMacroSliderSheet());
        }
      }
    }
  }

  Future<void> _showScanResultSheet(ScannedProductResult product) async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;

    await _stopImageStreaming();

    try {
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => ScanResultSheet(
          product: product,
          onLogConsumed: () async {
            Navigator.of(ctx).pop();

            // Record scan in Supabase / Local History
            if (widget.userId != null) {
              await HomeDashboardService().recordScan(
                userId: widget.userId!,
                barcode: product.barcode,
              );
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Added ${product.productName} to today\'s consumption budget!'),
                  backgroundColor: AppColors.primaryObsidian,
                  duration: const Duration(seconds: 2),
                ),
              );
            }

            if (widget.onProductResolved != null) {
              widget.onProductResolved!({
                'source': 'barcode',
                'product_name': product.productName,
                'health_score': product.healthScore,
                'eaten': true,
              });
            }

            ref.read(cameraScanNotifierProvider.notifier).reset();
          },
          onDismissWithoutLog: () {
            Navigator.of(ctx).pop();
            if (widget.onProductResolved != null) {
              widget.onProductResolved!({
                'source': 'barcode',
                'product_name': product.productName,
                'health_score': product.healthScore,
                'eaten': false,
              });
            }
            ref.read(cameraScanNotifierProvider.notifier).reset();
          },
        ),
      );
    } finally {
      _lastDismissedPayload = product.barcode;
      _lastDismissedTime = DateTime.now();
      _isSheetOpen = false;
      ref.read(cameraScanNotifierProvider.notifier).reset();
      if (mounted && !widget.useSimulatedFeed) {
        unawaited(_startImageStreaming());
      }
    }
  }

  Future<void> _openMacroSliderSheet() async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;

    await _stopImageStreaming();

    try {
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => QuickMacroSliderSheet(
          onSubmit: (macros) {
            Navigator.of(context).pop();
            final activeProfile = _profile ?? UserProfileModel.defaults(widget.userId ?? 'guest_user');
            final resolved = _productService.resolveManualNutrition(
              macros: macros,
              userProfile: activeProfile,
            );
            if (_pendingBindingBarcode != null) {
              final boundBarcode = _pendingBindingBarcode!;
              _pendingBindingBarcode = null;
              unawaited(OfflineBarcodeRepository.instance.saveProduct(
                barcode: boundBarcode,
                productData: {
                  'barcode': boundBarcode,
                  'product_name': 'Manual Custom Food',
                  'brand_name': 'Custom Entry',
                  'category': 'Custom Snack',
                  'serving_size_g': 30.0,
                  'pack_weight_g': 100.0,
                  'health_score': resolved.healthScore,
                  'nova_grade': resolved.novaGrade,
                  'red_cap_triggered': resolved.redCapTriggered ? 1 : 0,
                  'nutrition_json': jsonEncode({
                    'energy_kj': 450.0,
                    'sugar_g_per_100g': macros['sugar'] ?? 10.0,
                    'sat_fat_g_per_100g': macros['sat_fat'] ?? 5.0,
                    'sodium_mg_per_100g': macros['sodium'] ?? 200.0,
                  }),
                  'additives_json': '[]',
                  'ingredients_json': jsonEncode(['Wheat Flour', 'Sugar', 'Vegetable Oil']),
                },
                isUserLearned: true,
              ));
            }
            _showScanResultSheet(resolved);
          },
        ),
      );
    } finally {
      _isSheetOpen = false;
      if (mounted && !widget.useSimulatedFeed) {
        unawaited(_startImageStreaming());
      }
    }
  }

  /// In-app capture for multi-angle bottle mode (ZERO external camera intent)
  Future<void> _captureMultiAngleFrame() async {
    unawaited(HapticFeedback.lightImpact().catchError((_) => null));
    if (widget.useSimulatedFeed) {
      ref.read(cameraScanNotifierProvider.notifier).addMultiAngleFrame(
        List<int>.generate(200, (i) => (i * 7) % 256),
      );
      return;
    }

    try {
      if (_cameraController == null || !_cameraController!.value.isInitialized) return;
      await _stopImageStreaming();
      final photo = await _cameraController!.takePicture();
      final bytes = await photo.readAsBytes();
      if (bytes.isNotEmpty) {
        ref.read(cameraScanNotifierProvider.notifier).addMultiAngleFrame(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Captured photo (${bytes.length ~/ 1024} KB). Tap Submit or add another angle.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[SmartCameraScreen] Error capturing photo via in-app camera: $e');
    } finally {
      if (mounted && !_isSheetOpen && !_isProcessingScan && !widget.useSimulatedFeed) {
        unawaited(_startImageStreaming());
      }
    }
  }

  /// Secondary gallery photo picker (ImageSource.gallery)
  Future<void> _pickPhotoFromGallery() async {
    unawaited(HapticFeedback.lightImpact().catchError((_) => null));
    if (widget.useSimulatedFeed) {
      ref.read(cameraScanNotifierProvider.notifier).addMultiAngleFrame(
        List<int>.generate(200, (i) => (i * 7) % 256),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        if (bytes.isNotEmpty) {
          ref.read(cameraScanNotifierProvider.notifier).addMultiAngleFrame(bytes);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Selected photo (${bytes.length ~/ 1024} KB). Tap Submit or add another angle.'),
                duration: const Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[SmartCameraScreen] Error picking photo from gallery: $e');
    }
  }

  void _toggleTorch(CameraScanNotifier notifier) {
    notifier.toggleTorch();
    if (!widget.useSimulatedFeed && _cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final isTorchOn = ref.read(cameraScanNotifierProvider).isTorchOn;
        _cameraController!.setFlashMode(isTorchOn ? FlashMode.torch : FlashMode.off);
      } catch (_) {}
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _activePointers = details.pointerCount;
    _baseZoomScale = _currentZoomScale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, CameraScanNotifier notifier) {
    if (details.pointerCount >= 2) {
      if (_activePointers < 2) {
        _activePointers = details.pointerCount;
        _baseZoomScale = _currentZoomScale;
        return;
      }
      _activePointers = details.pointerCount;

      final targetZoom = (_baseZoomScale * details.scale).clamp(1.0, 5.0);
      _currentZoomScale = targetZoom;

      _zoomScaleNotifier.value = _currentZoomScale;
      _isPinchingNotifier.value = true;
      _zoomOverlayTimer?.cancel();

      _dispatchZoomRatio(_currentZoomScale);
    } else {
      _activePointers = details.pointerCount;
    }
  }

  void _handleScaleEnd(ScaleEndDetails details, CameraScanNotifier notifier) {
    _activePointers = 0;
    _zoomThrottleTimer?.cancel();

    _pendingZoomRatio = _currentZoomScale;
    if (!_isZoomDispatching) {
      final toSend = _pendingZoomRatio!;
      _pendingZoomRatio = null;
      _sendZoomToHardware(toSend);
    }

    notifier.setZoomScale(_currentZoomScale);

    _zoomOverlayTimer?.cancel();
    _zoomOverlayTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        _isPinchingNotifier.value = false;
      }
    });
  }

  void _dispatchZoomRatio(double ratio) {
    if (widget.useSimulatedFeed) return;
    _pendingZoomRatio = ratio;

    if (_isZoomDispatching) return;

    final now = DateTime.now();
    final elapsed = now.difference(_lastHardwareZoomTime).inMilliseconds;

    if (elapsed < 16) {
      _zoomThrottleTimer?.cancel();
      _zoomThrottleTimer = Timer(Duration(milliseconds: 16 - elapsed), () {
        if (mounted && _pendingZoomRatio != null && !_isZoomDispatching) {
          final toSend = _pendingZoomRatio!;
          _pendingZoomRatio = null;
          _sendZoomToHardware(toSend);
        }
      });
      return;
    }

    _zoomThrottleTimer?.cancel();
    final toSend = _pendingZoomRatio!;
    _pendingZoomRatio = null;
    _sendZoomToHardware(toSend);
  }

  void _sendZoomToHardware(double ratio) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    _isZoomDispatching = true;
    _lastHardwareZoomTime = DateTime.now();

    _cameraController!.getMaxZoomLevel().then((maxZoom) {
      final clamped = ratio.clamp(1.0, maxZoom);
      return _cameraController!.setZoomLevel(clamped);
    }).then((_) {
      _isZoomDispatching = false;
      if (_pendingZoomRatio != null && mounted) {
        final next = _pendingZoomRatio!;
        _pendingZoomRatio = null;
        _dispatchZoomRatio(next);
      }
    }).catchError((_) {
      _isZoomDispatching = false;
    });
  }

  void _handleTapToFocus(Offset tapPos) {
    HapticFeedback.mediumImpact();

    _tapFocusOffset.value = tapPos;
    _tapFocusTimer?.cancel();
    _tapFocusTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _tapFocusOffset.value = null;
      }
    });

    if (!widget.useSimulatedFeed && _cameraController != null && _cameraController!.value.isInitialized) {
      try {
        final size = MediaQuery.of(context).size;
        final relativeX = (tapPos.dx / size.width).clamp(0.0, 1.0);
        final relativeY = (tapPos.dy / size.height).clamp(0.0, 1.0);

        _cameraController!.setFocusPoint(Offset(relativeX, relativeY));
        _cameraController!.setExposurePoint(Offset(relativeX, relativeY));

        _focusResetTimer?.cancel();
        _focusResetTimer = Timer(const Duration(milliseconds: 3000), () {
          if (mounted && !widget.useSimulatedFeed && _cameraController != null && _cameraController!.value.isInitialized) {
            try {
              _cameraController!.setFocusMode(FocusMode.auto);
            } catch (_) {}
          }
        });
      } catch (e) {
        debugPrint('Error triggering hardware focus: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cameraScanNotifierProvider);
    final notifier = ref.read(cameraScanNotifierProvider.notifier);

    final screenSize = MediaQuery.of(context).size;
    final reticleWidth = (screenSize.width * 0.88).clamp(320.0, 420.0);
    final reticleHeight = (reticleWidth * 0.92).clamp(320.0, 440.0);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Live Camera Feed or Test Viewport with Multi-Touch Pinch-to-Zoom & Tap-to-Focus
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _handleScaleStart,
              onScaleUpdate: (d) => _handleScaleUpdate(d, notifier),
              onScaleEnd: (d) => _handleScaleEnd(d, notifier),
              onTapUp: (details) => _handleTapToFocus(details.globalPosition),
              child: widget.useSimulatedFeed
                  ? _buildSimulatedViewport()
                  : _buildLiveScannerViewport(),
            ),
          ),

          // 2. Central Reticle Overlay
          IgnorePointer(
            child: CameraReticleOverlay(
              status: state.status,
              hasGlareAlert: state.hasGlareAlert,
              reticleWidth: reticleWidth,
              reticleHeight: reticleHeight,
            ),
          ),

          // 3. Specular Glare Alert Banner
          if (state.hasGlareAlert && state.glareBadgeText != null)
            Positioned(
              top: 110,
              left: 24,
              right: 24,
              child: Center(
                child: GlareAlertBanner(message: state.glareBadgeText!),
              ),
            ),

          // 4. Ephemeral Tap-to-Focus Indicator
          _buildTapFocusIndicator(),

          // 5. Ephemeral Pinch-to-Zoom Floating Indicator
          _buildPinchZoomIndicator(),

          // 6. Top Action Bar & Status HUD
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.black45,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                            onPressed: () => Navigator.of(context).maybePop(),
                            tooltip: 'Back',
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Mode Selector Chips
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: GestureDetector(
                              onLongPress: () => BackendSettingsSheet.show(context),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ChoiceChip(
                                      label: const Text('Auto Barcode / QR'),
                                      selected: _scanMode == CameraScanMode.barcodeQr && !state.isMultiAngleMode,
                                      selectedColor: const Color(0xFF10B981),
                                      backgroundColor: const Color(0xD91E293B),
                                      showCheckmark: false,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      side: BorderSide(
                                        color: (_scanMode == CameraScanMode.barcodeQr && !state.isMultiAngleMode)
                                            ? const Color(0xFF10B981)
                                            : Colors.white24,
                                        width: 1.0,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                      labelStyle: TextStyle(
                                        fontSize: 11,
                                        fontWeight: (_scanMode == CameraScanMode.barcodeQr && !state.isMultiAngleMode)
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: (_scanMode == CameraScanMode.barcodeQr && !state.isMultiAngleMode)
                                            ? Colors.white
                                            : const Color(0xE6FFFFFF),
                                      ),
                                      onSelected: (val) {
                                        if (val) {
                                          setState(() => _scanMode = CameraScanMode.barcodeQr);
                                          notifier.setMultiAngleMode(false);
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    ChoiceChip(
                                      label: const Text('Capture Nutrition Label'),
                                      selected: _scanMode == CameraScanMode.nutritionLabel && !state.isMultiAngleMode,
                                      selectedColor: const Color(0xFF10B981),
                                      backgroundColor: const Color(0xD91E293B),
                                      showCheckmark: false,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      side: BorderSide(
                                        color: (_scanMode == CameraScanMode.nutritionLabel && !state.isMultiAngleMode)
                                            ? const Color(0xFF10B981)
                                            : Colors.white24,
                                        width: 1.0,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                      labelStyle: TextStyle(
                                        fontSize: 11,
                                        fontWeight: (_scanMode == CameraScanMode.nutritionLabel && !state.isMultiAngleMode)
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: (_scanMode == CameraScanMode.nutritionLabel && !state.isMultiAngleMode)
                                            ? Colors.white
                                            : const Color(0xE6FFFFFF),
                                      ),
                                      onSelected: (val) {
                                        if (val) {
                                          setState(() => _scanMode = CameraScanMode.nutritionLabel);
                                          notifier.setMultiAngleMode(false);
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    ChoiceChip(
                                      label: const Text('Curved Bottle'),
                                      selected: state.isMultiAngleMode,
                                      selectedColor: const Color(0xFF4285F4),
                                      backgroundColor: const Color(0xD91E293B),
                                      showCheckmark: false,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      side: BorderSide(
                                        color: state.isMultiAngleMode
                                            ? const Color(0xFF4285F4)
                                            : Colors.white24,
                                        width: 1.0,
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                      labelStyle: TextStyle(
                                        fontSize: 11,
                                        fontWeight: state.isMultiAngleMode ? FontWeight.w700 : FontWeight.w600,
                                        color: state.isMultiAngleMode ? Colors.white : const Color(0xE6FFFFFF),
                                      ),
                                      onSelected: (val) {
                                        if (val) {
                                          setState(() => _scanMode = CameraScanMode.multiAngle);
                                          notifier.setMultiAngleMode(true);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Scan Mode Toggle (Live Scan vs Lens Testing Mode)
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.black45,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              _isLiveScanMode ? Icons.qr_code_scanner_rounded : Icons.camera_alt_outlined,
                              color: _isLiveScanMode ? const Color(0xFF0F9D58) : Colors.white70,
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() => _isLiveScanMode = !_isLiveScanMode);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    _isLiveScanMode
                                        ? 'Live Scan Active: Barcodes open Master Verdict'
                                        : 'Lens Test Mode: Scan reports suppressed for camera testing',
                                  ),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            tooltip: _isLiveScanMode ? 'Live Scan Active' : 'Lens Test Mode',
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Torch Toggle Button
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.black45,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              state.isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              color: state.isTorchOn ? const Color(0xFFF4B400) : Colors.white,
                              size: 20,
                            ),
                            onPressed: () => _toggleTorch(notifier),
                            tooltip: 'Torch',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Unknown Barcode Pending Binding Banner
                  if (_pendingBindingBarcode != null)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F9D58).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code_2_rounded, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Barcode [$_pendingBindingBarcode] Scanned — Now Point at Nutrition Table to Capture',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => setState(() => _pendingBindingBarcode = null),
                            child: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
                          ),
                        ],
                      ),
                    )
                  // Live Nutrition Label Auto-Detection Badge
                  else if (_isNutritionLabelDetected)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F9D58).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: const [
                          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.document_scanner_rounded, size: 18, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            _isAutoCaptureEnabled
                                ? 'Nutrition Table in View — Hold Steady to Auto-Snap'
                                : 'Nutrition Table in View — Tap Shutter to Capture Clear Photo',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // 7. In-App Processing Overlay
          if (_isProcessingScan && !_isSheetOpen)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.72),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Color(0xFF0F9D58), strokeWidth: 3),
                      const SizedBox(height: 18),
                      Text(
                        _activeScanningStatus ?? 'Extracting Nutrition Facts & Ingredients...',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Analyzing packaging via AI Computer Vision',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 8. Bottom Controls & Guidance
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.isMultiAngleMode)
                    MultiAngleCaptureStrip(
                      capturedFramesCount: state.capturedFrames.length,
                      maxFrames: 4,
                      isSubmitting: _isProcessingScan,
                      onSubmit: () => _handleMultiAngleSubmit(state.capturedFrames),
                      onClear: notifier.clearMultiAngleFrames,
                    )
                  else ...[
                    // Auto-Scan Label Toggle Pill
                    GestureDetector(
                      onTap: () {
                        setState(() => _isAutoCaptureEnabled = !_isAutoCaptureEnabled);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(_isAutoCaptureEnabled
                                ? 'Auto-Scan Label ON: Automatically snaps when steady over nutrition table'
                                : 'Auto-Scan Label OFF: Tap shutter button to capture'),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _isAutoCaptureEnabled
                              ? const Color(0xFF0F9D58).withValues(alpha: 0.85)
                              : Colors.black54,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _isAutoCaptureEnabled ? const Color(0xFF0F9D58) : Colors.white24,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isAutoCaptureEnabled ? Icons.bolt_rounded : Icons.touch_app_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isAutoCaptureEnabled ? 'Auto-Scan Label: ON' : 'Auto-Scan Label: OFF',
                              style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _isProcessingScan
                            ? (_activeScanningStatus ?? 'Resolving product toxicology...')
                            : 'Tap barcode or ingredients to focus • Pinch to zoom',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Manual Macro Input Button
                      FloatingActionButton.small(
                        heroTag: 'macro_slider_btn',
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                        onPressed: _openMacroSliderSheet,
                        tooltip: 'Quick Macro Sliders',
                        child: const Icon(Icons.tune_rounded),
                      ),
                      const SizedBox(width: 24),
                      // Primary In-App Shutter Button (Handles both single nutrition capture & multi-angle frames)
                      FloatingActionButton(
                        heroTag: 'shutter_btn',
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        onPressed: state.isMultiAngleMode
                            ? _captureMultiAngleFrame
                            : _captureNutritionLabelFromActiveCamera,
                        tooltip: state.isMultiAngleMode ? 'Capture Photo Angle' : 'Capture Nutrition Label',
                        child: const Icon(Icons.camera_alt_rounded, size: 28),
                      ),
                      const SizedBox(width: 24),
                      // Gallery photo picker button
                      FloatingActionButton.small(
                        heroTag: 'gallery_pick_btn',
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                        onPressed: _pickPhotoFromGallery,
                        tooltip: 'Pick Photo from Gallery',
                        child: const Icon(Icons.photo_library_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 9. In-App Capture Preview Confirmation Overlay
          if (_showCapturePreviewOverlay && _capturedPreviewBytes != null)
            Positioned.fill(
              child: _buildCapturePreviewOverlay(),
            ),
        ],
      ),
    );
  }

  Widget _buildTapFocusIndicator() {
    return ValueListenableBuilder<Offset?>(
      valueListenable: _tapFocusOffset,
      builder: (context, offset, _) {
        if (offset == null) return const SizedBox.shrink();

        const double ringSize = 48.0;
        return Positioned(
          left: offset.dx - (ringSize / 2),
          top: offset.dy - (ringSize / 2),
          child: IgnorePointer(
            child: TweenAnimationBuilder<double>(
              key: ValueKey(offset),
              tween: Tween<double>(begin: 1.35, end: 1.0),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              builder: (context, scale, _) {
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: ringSize,
                    height: ringSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0F9D58),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 4.0,
                        height: 4.0,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F9D58),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildPinchZoomIndicator() {
    return ValueListenableBuilder<bool>(
      valueListenable: _isPinchingNotifier,
      builder: (context, isPinching, _) {
        if (!isPinching) return const SizedBox.shrink();

        return Positioned(
          top: 90,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0E1424).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF0F9D58).withValues(alpha: 0.7),
                  width: 1.2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black45,
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: ValueListenableBuilder<double>(
                valueListenable: _zoomScaleNotifier,
                builder: (context, zoom, _) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.zoom_in_rounded, size: 16, color: Color(0xFF0F9D58)),
                      const SizedBox(width: 6),
                      Text(
                        '${zoom.toStringAsFixed(1)}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLiveScannerViewport() {
    if (_cameraController == null || !_isCameraInitialized) {
      return _buildSimulatedViewport(errorMessage: _cameraError ?? 'Initializing hardware camera...');
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _cameraController!.value.previewSize?.height ?? 1080,
          height: _cameraController!.value.previewSize?.width ?? 1920,
          child: CameraPreview(_cameraController!),
        ),
      ),
    );
  }

  Widget _buildSimulatedViewport({String? errorMessage}) {
    return Container(
      color: const Color(0xFF121212),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_outlined, size: 72, color: Colors.white24),
              if (errorMessage != null) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    errorMessage,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              // Quick Sample Test Trigger for tests or demo
              TextButton.icon(
                onPressed: () => _onBarcodeDetected('8901063012117'),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 16, color: AppColors.accentBronze),
                label: const Text(
                  'Simulate Sample Scan (Good Day)',
                  style: TextStyle(color: AppColors.accentBronze, fontSize: 12.5),
                ),
              ),
              TextButton.icon(
                onPressed: () => _onBarcodeDetected('{"product_name": "Organic Almond Butter", "brand_name": "NuttyCraft", "serving_size_g": 32.0, "nutrition": {"sugar_g_per_100g": 4.0, "sat_fat_g_per_100g": 3.0, "sodium_mg_per_100g": 60.0}}'),
                icon: const Icon(Icons.qr_code_2_rounded, size: 16, color: AppColors.safetyGreen),
                label: const Text(
                  'Simulate Product QR Scan',
                  style: TextStyle(color: AppColors.safetyGreen, fontSize: 12.5),
                ),
              ),
              TextButton.icon(
                onPressed: () => _onBarcodeDetected('https://wa.me/912261014560'),
                icon: const Icon(Icons.devices_other_rounded, size: 16, color: AppColors.safetyRed),
                label: const Text(
                  'Simulate Non-Food QR Scan',
                  style: TextStyle(color: AppColors.safetyRed, fontSize: 12.5),
                ),
              ),
              TextButton.icon(
                onPressed: () => _onBarcodeDetected('https://www.youtube.com/watch?v=everest_chole_recipe'),
                icon: const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF4285F4)),
                label: const Text(
                  'Simulate Recipe QR Scan (Everest)',
                  style: TextStyle(color: Color(0xFF4285F4), fontSize: 12.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
