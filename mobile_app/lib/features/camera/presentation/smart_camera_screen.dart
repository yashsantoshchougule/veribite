import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_colors.dart';
import '../../home/application/home_dashboard_service.dart';
import '../../profile/application/user_profile_service.dart';
import '../../profile/domain/user_profile_model.dart';
import '../application/camera_scan_notifier.dart';
import '../application/product_scanner_service.dart';
import 'widgets/camera_reticle_painter.dart';
import 'widgets/glare_alert_banner.dart';
import 'widgets/multi_angle_capture_strip.dart';
import 'widgets/quick_macro_slider_sheet.dart';
import 'widgets/scan_result_sheet.dart';
import '../../results/presentation/verdict_report_screen.dart';

/// Smart Camera Viewfinder Screen for VeriBite.
/// Integrates live MobileScanner hardware stream, barcode lock-on, specular glare detection,
/// multi-angle capture for curved bottles, and interactive ScanResultSheet.
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
    this.disableResultSheet = false, // Live scan active by default, toggleable on screen
    this.productService,
  });

  @override
  ConsumerState<SmartCameraScreen> createState() => _SmartCameraScreenState();
}

class _SmartCameraScreenState extends ConsumerState<SmartCameraScreen> {
  late final MobileScannerController _scannerController;
  late final ProductScannerService _productService;
  UserProfileModel? _profile;
  bool _isProcessingScan = false;
  late bool _isLiveScanMode;
  bool _isSheetOpen = false;
  String? _lastDismissedPayload;
  DateTime? _lastDismissedTime;
  Timer? _qrDebounceTimer;
  String? _pendingQrPayload;
  List<int>? _pendingQrFrame;
  String? _activeScanningStatus;

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

  @override
  void initState() {
    super.initState();
    _isLiveScanMode = !widget.disableResultSheet;
    _productService = widget.productService ?? ProductScannerService();
    _profile = widget.userProfile;

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      cameraResolution: const Size(1920, 1080),
      formats: const [BarcodeFormat.all],
      autoZoom: true,
      returnImage: true,
    );

    if (_profile == null && widget.userId != null) {
      _loadProfile();
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
    _qrDebounceTimer?.cancel();
    _zoomOverlayTimer?.cancel();
    _zoomThrottleTimer?.cancel();
    _focusResetTimer?.cancel();
    _tapFocusTimer?.cancel();
    _zoomScaleNotifier.dispose();
    _isPinchingNotifier.dispose();
    _tapFocusOffset.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _handleBarcodeCapture(BarcodeCapture capture) {
    if (_isProcessingScan || _isSheetOpen) return;

    Barcode? oneDBarcode;
    Barcode? qrBarcode;

    for (final b in capture.barcodes) {
      final raw = b.rawValue?.trim();
      if (raw == null || raw.isEmpty) continue;

      if (b.format == BarcodeFormat.ean13 ||
          b.format == BarcodeFormat.ean8 ||
          b.format == BarcodeFormat.upcA ||
          b.format == BarcodeFormat.upcE ||
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
      _pendingQrFrame = null;

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

      // Immediately reject non-web QR payloads (e.g. upi://, WIFI:, tel:, mailto:, vCard) without debounce
      if (trimmed.startsWith('upi:') ||
          trimmed.startsWith('wifi:') ||
          trimmed.startsWith('WIFI:') ||
          trimmed.startsWith('tel:') ||
          trimmed.startsWith('mailto:') ||
          trimmed.startsWith('begin:vcard') ||
          trimmed.startsWith('BEGIN:VCARD')) {
        _qrDebounceTimer?.cancel();
        _qrDebounceTimer = null;
        _pendingQrPayload = null;
        _pendingQrFrame = null;
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

      // If a QR debounce timer is already running: update frame if available and continue
      if (_qrDebounceTimer != null && _qrDebounceTimer!.isActive) {
        if (capture.image != null) {
          _pendingQrFrame = capture.image;
        }
        return;
      }

      // Stage 1: Buffer QR payload & frame for 450ms while listening for 1D barcode
      _pendingQrPayload = trimmed;
      _pendingQrFrame = capture.image;

      _qrDebounceTimer = Timer(const Duration(milliseconds: 450), () {
        if (!mounted || _isProcessingScan || _isSheetOpen) return;
        final payload = _pendingQrPayload;
        final frame = _pendingQrFrame;
        _pendingQrPayload = null;
        _pendingQrFrame = null;
        if (payload != null) {
          _onBarcodeDetected(payload, frameImage: frame);
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
      await _showScanResultReport(resolvedProduct, activeProfile);
    } on PromotionalQrContextException catch (e) {
      if (!mounted) return;
      await _showPromotionalQrContextSheet(e);
    } on NonFoodScanException catch (e) {
      if (!mounted) return;
      await _showNonFoodDialog(e.message, rawBarcode);
    } on ProductNotFoundException catch (e) {
      if (!mounted) return;
      await _showProductNotFoundDialog(e.barcode);
    } on FoodWebExtractionException catch (e) {
      if (!mounted) return;
      await _showWebExtractionFailedDialog(e.url);
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

  Future<void> _handleMultiAngleSubmit(List<List<int>> frames) async {
    if (_isProcessingScan || _isSheetOpen || frames.isEmpty) return;

    setState(() => _isProcessingScan = true);
    final activeProfile = _profile ?? UserProfileModel.defaults(widget.userId ?? 'guest_user');

    try {
      unawaited(HapticFeedback.mediumImpact().catchError((_) => null));

      final resolvedProduct = await _productService.resolveMultiAngleScan(
        frames: frames,
        userProfile: activeProfile,
      );

      if (!mounted) return;
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
      }
    }
  }

  Future<void> _showScanResultReport(ScannedProductResult product, UserProfileModel profile) async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;

    try {
      await _scannerController.stop();
    } catch (_) {}

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
      if (mounted) {
        try {
          await _scannerController.start();
        } catch (_) {}
      }
    }
  }

  Future<void> _showNonFoodDialog(String message, String rawPayload) async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;

    try {
      await _scannerController.stop();
    } catch (_) {}

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
      if (mounted) {
        try {
          await _scannerController.start();
        } catch (_) {}
      }
    }
  }

  Future<void> _showProductNotFoundDialog(String barcode) async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;

    try {
      await _scannerController.stop();
    } catch (_) {}

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
                'Barcode "$barcode" was not found in our global food databases. If this is a real packaged food item, you can enter its nutritional values manually.',
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
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryObsidian,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('Try Again', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
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
      if (mounted) {
        try {
          await _scannerController.start();
        } catch (_) {}
      }
    }
  }

  Future<void> _showWebExtractionFailedDialog(String url) async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;

    try {
      await _scannerController.stop();
    } catch (_) {}

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
                        ref.read(cameraScanNotifierProvider.notifier).setMultiAngleMode(true);
                        _captureMultiAngleFrame();
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
      if (mounted) {
        try {
          await _scannerController.start();
        } catch (_) {}
      }
    }
  }

  Future<void> _showPromotionalQrContextSheet(PromotionalQrContextException exception) async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;

    try {
      await _scannerController.stop();
    } catch (_) {}

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
        try {
          await _scannerController.start();
        } catch (_) {}
        if (action == 'macros') {
          _openMacroSliderSheet();
        }
      }
    }
  }

  Future<void> _showScanResultSheet(ScannedProductResult product) async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;

    try {
      await _scannerController.stop();
    } catch (_) {}

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
      if (mounted) {
        try {
          await _scannerController.start();
        } catch (_) {}
      }
    }
  }

  Future<void> _openMacroSliderSheet() async {
    if (_isSheetOpen) return;
    _isSheetOpen = true;

    try {
      await _scannerController.stop();
    } catch (_) {}

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
            _showScanResultSheet(resolved);
          },
        ),
      );
    } finally {
      _isSheetOpen = false;
      if (mounted) {
        try {
          await _scannerController.start();
        } catch (_) {}
      }
    }
  }

  Future<void> _captureMultiAngleFrame() async {
    unawaited(HapticFeedback.lightImpact().catchError((_) => null));
    if (widget.useSimulatedFeed) {
      ref.read(cameraScanNotifierProvider.notifier).addMultiAngleFrame(
        List<int>.generate(200, (i) => (i * 7) % 256),
      );
      return;
    }

    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 85,
      );
      if (photo != null) {
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
      }
    } catch (e) {
      debugPrint('[SmartCameraScreen] Error capturing photo via camera: $e');
    }
  }

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
    if (!widget.useSimulatedFeed) {
      try {
        _scannerController.toggleTorch();
      } catch (_) {}
    }
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _activePointers = details.pointerCount;
    _baseZoomScale = _currentZoomScale;
  }

  void _handleScaleUpdate(ScaleUpdateDetails details, CameraScanNotifier notifier) {
    if (details.pointerCount >= 2) {
      // Re-anchor baseline if transitioning into a multi-finger pinch gesture
      if (_activePointers < 2) {
        _activePointers = details.pointerCount;
        _baseZoomScale = _currentZoomScale;
        return;
      }
      _activePointers = details.pointerCount;

      // Direct 1:1 hardware magnification ratio without artificial lag or non-linear jumps
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

    // Guarantee the final settled zoom ratio reaches camera hardware
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

    // Pace requests to max ~60fps (16ms) to avoid saturating Camera2 capture session
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
    _isZoomDispatching = true;
    _lastHardwareZoomTime = DateTime.now();

    _scannerController.setZoomRatio(ratio).then((_) {
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

    // Show ephemeral pulsing focus ring at tapped coordinates for 1.2s
    _tapFocusOffset.value = tapPos;
    _tapFocusTimer?.cancel();
    _tapFocusTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        _tapFocusOffset.value = null;
      }
    });

    if (!widget.useSimulatedFeed) {
      try {
        final size = MediaQuery.of(context).size;
        final relativeX = (tapPos.dx / size.width).clamp(0.0, 1.0);
        final relativeY = (tapPos.dy / size.height).clamp(0.0, 1.0);

        // 1. Hardware optical auto-focus metering (CameraX / iOS AVCaptureDevice)
        _scannerController.setFocusPoint(Offset(relativeX, relativeY));

        // 2. Safety fallback: automatically reset focus back to continuous mode after 3.0s
        // ensuring the lens NEVER gets stuck in a blurred lock state
        _focusResetTimer?.cancel();
        _focusResetTimer = Timer(const Duration(milliseconds: 3000), () {
          if (mounted && !widget.useSimulatedFeed) {
            try {
              _scannerController.resetFocus();
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
    final reticleRect = Rect.fromCenter(
      center: Offset(screenSize.width / 2, screenSize.height / 2),
      width: reticleWidth,
      height: reticleHeight,
    );

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
                  : _buildLiveScannerViewport(scanWindow: reticleRect),
            ),
          ),

          // 2. Central Reticle Overlay (Clean corner brackets, zero permanent or tap badges)
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

          // 4. Ephemeral Tap-to-Focus Indicator (Transient pulse ring)
          _buildTapFocusIndicator(),

          // 5. Ephemeral Pinch-to-Zoom Floating Indicator (Isolated via ValueListenableBuilder)
          _buildPinchZoomIndicator(),

          // 6. Top Action Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
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
                                label: const Text('Barcode / Auto', style: TextStyle(fontSize: 11)),
                                selected: !state.isMultiAngleMode,
                                selectedColor: const Color(0xFF0F9D58),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                labelStyle: TextStyle(
                                  color: !state.isMultiAngleMode ? Colors.white : Colors.white70,
                                ),
                                onSelected: (val) {
                                  if (val) notifier.setMultiAngleMode(false);
                                },
                              ),
                              const SizedBox(width: 4),
                              ChoiceChip(
                                label: const Text('Curved Bottle', style: TextStyle(fontSize: 11)),
                                selected: state.isMultiAngleMode,
                                selectedColor: const Color(0xFF4285F4),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                                labelStyle: TextStyle(
                                  color: state.isMultiAngleMode ? Colors.white : Colors.white70,
                                ),
                                onSelected: (val) {
                                  if (val) notifier.setMultiAngleMode(true);
                                },
                              ),
                            ],
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
            ),
          ),

          // 7. Bottom Controls & Guidance (Zero permanent badges or clutter)
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
                  else
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
                      if (state.isMultiAngleMode) ...[
                        const SizedBox(width: 24),
                        // Capture shutter button for multi-angle
                        FloatingActionButton(
                          heroTag: 'shutter_btn',
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          onPressed: _captureMultiAngleFrame,
                          tooltip: 'Capture Photo Angle',
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
                    ],
                  ),
                ],
              ),
            ),
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

  Widget _buildLiveScannerViewport({Rect? scanWindow}) {
    return MobileScanner(
      controller: _scannerController,
      scanWindow: scanWindow,
      onDetect: _handleBarcodeCapture,
      errorBuilder: (context, error) {
        return _buildSimulatedViewport(
          errorMessage: 'Camera preview unavailable: ${error.errorCode.name}',
        );
      },
    );
  }

  Widget _buildSimulatedViewport({String? errorMessage}) {
    return Container(
      color: const Color(0xFF121212),
      child: Center(
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
    );
  }
}
