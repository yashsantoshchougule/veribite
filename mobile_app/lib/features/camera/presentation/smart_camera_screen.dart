import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

/// Smart Camera Viewfinder Screen for VeriBite.
/// Integrates live MobileScanner hardware stream, barcode lock-on, specular glare detection,
/// multi-angle capture for curved bottles, and interactive ScanResultSheet.
class SmartCameraScreen extends ConsumerStatefulWidget {
  final String? userId;
  final UserProfileModel? userProfile;
  final ValueChanged<Map<String, dynamic>>? onProductResolved;
  final bool useSimulatedFeed;
  final bool disableResultSheet;

  const SmartCameraScreen({
    super.key,
    this.userId,
    this.userProfile,
    this.onProductResolved,
    this.useSimulatedFeed = false,
    this.disableResultSheet = true, // Temporarily disabled by default for camera testing
  });

  @override
  ConsumerState<SmartCameraScreen> createState() => _SmartCameraScreenState();
}

class _SmartCameraScreenState extends ConsumerState<SmartCameraScreen> {
  late final MobileScannerController _scannerController;
  late final ProductScannerService _productService;
  UserProfileModel? _profile;
  bool _isProcessingScan = false;

  double _baseZoomScale = 1.0;
  double _currentZoomScale = 1.0;
  int _activePointers = 0;
  bool _isZoomDispatching = false;
  double? _pendingZoomRatio;
  DateTime _lastHardwareZoomTime = DateTime.fromMillisecondsSinceEpoch(0);
  final ValueNotifier<double> _zoomScaleNotifier = ValueNotifier<double>(1.0);
  final ValueNotifier<bool> _isPinchingNotifier = ValueNotifier<bool>(false);
  Timer? _zoomOverlayTimer;
  Timer? _zoomThrottleTimer;
  Timer? _focusResetTimer;

  @override
  void initState() {
    super.initState();
    _productService = ProductScannerService();
    _profile = widget.userProfile;

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      cameraResolution: const Size(1920, 1080),
      formats: const [BarcodeFormat.all],
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
    _zoomOverlayTimer?.cancel();
    _zoomThrottleTimer?.cancel();
    _focusResetTimer?.cancel();
    _zoomScaleNotifier.dispose();
    _isPinchingNotifier.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  void _handleBarcodeCapture(BarcodeCapture capture) {
    if (_isProcessingScan) return;

    for (final barcode in capture.barcodes) {
      final rawVal = barcode.rawValue;
      if (rawVal != null && rawVal.trim().isNotEmpty) {
        _onBarcodeDetected(rawVal.trim());
        break;
      }
    }
  }

  Future<void> _onBarcodeDetected(String rawBarcode) async {
    // TEMPORARY: Result sheet popup suppressed for camera testing
    if (widget.disableResultSheet) {
      await HapticFeedback.selectionClick();
      debugPrint('[Camera Test Mode] Barcode detected: $rawBarcode (Result sheet suppressed)');
      return;
    }

    if (_isProcessingScan) return;
    setState(() => _isProcessingScan = true);

    final notifier = ref.read(cameraScanNotifierProvider.notifier);
    notifier.onBarcodeScanned(rawBarcode);

    final activeProfile = _profile ?? UserProfileModel.defaults(widget.userId ?? 'guest_user');

    try {
      final resolvedProduct = await _productService.resolveBarcode(
        barcode: rawBarcode,
        userProfile: activeProfile,
      );

      if (!mounted) return;
      _showScanResultSheet(resolvedProduct);
    } catch (e) {
      debugPrint('Error resolving barcode $rawBarcode: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not resolve product for barcode: $rawBarcode'),
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

  void _showScanResultSheet(ScannedProductResult product) {
    showModalBottomSheet(
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
    ).then((_) {
      ref.read(cameraScanNotifierProvider.notifier).reset();
    });
  }

  void _openMacroSliderSheet() {
    showModalBottomSheet(
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
    HapticFeedback.selectionClick();

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

          // 5. Ephemeral Pinch-to-Zoom Floating Indicator (Isolated via ValueListenableBuilder)
          _buildPinchZoomIndicator(),

          // 6. Top Action Bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).maybePop(),
                      tooltip: 'Back',
                    ),
                  ),
                  const Spacer(),
                  // Mode Selector Chips
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ChoiceChip(
                          label: const Text('Barcode / Auto', style: TextStyle(fontSize: 12)),
                          selected: !state.isMultiAngleMode,
                          selectedColor: const Color(0xFF0F9D58),
                          labelStyle: TextStyle(
                            color: !state.isMultiAngleMode ? Colors.white : Colors.white70,
                          ),
                          onSelected: (val) {
                            if (val) notifier.setMultiAngleMode(false);
                          },
                        ),
                        const SizedBox(width: 4),
                        ChoiceChip(
                          label: const Text('Curved Bottle', style: TextStyle(fontSize: 12)),
                          selected: state.isMultiAngleMode,
                          selectedColor: const Color(0xFF4285F4),
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
                  const Spacer(),
                  // Torch Toggle Button
                  CircleAvatar(
                    backgroundColor: Colors.black45,
                    child: IconButton(
                      icon: Icon(
                        state.isTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: state.isTorchOn ? const Color(0xFFF4B400) : Colors.white,
                      ),
                      onPressed: () => _toggleTorch(notifier),
                      tooltip: 'Torch',
                    ),
                  ),
                ],
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
                      onSubmit: () {
                        if (widget.onProductResolved != null) {
                          widget.onProductResolved!({
                            'source': 'multi_angle_vision',
                            'frames_count': state.capturedFrames.length,
                          });
                        }
                      },
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
                            ? 'Resolving product toxicology...'
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
                          onPressed: () => notifier.addMultiAngleFrame([0xFF, 0xD8]),
                          child: const Icon(Icons.camera_alt_rounded, size: 28),
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
          ],
        ),
      ),
    );
  }
}
