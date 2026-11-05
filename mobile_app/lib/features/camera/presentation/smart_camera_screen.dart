import 'package:flutter/material.dart';
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

  const SmartCameraScreen({
    super.key,
    this.userId,
    this.userProfile,
    this.onProductResolved,
    this.useSimulatedFeed = false,
  });

  @override
  ConsumerState<SmartCameraScreen> createState() => _SmartCameraScreenState();
}

class _SmartCameraScreenState extends ConsumerState<SmartCameraScreen> {
  late final MobileScannerController _scannerController;
  late final ProductScannerService _productService;
  UserProfileModel? _profile;
  bool _isProcessingScan = false;

  @override
  void initState() {
    super.initState();
    _productService = ProductScannerService();
    _profile = widget.userProfile;

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(cameraScanNotifierProvider);
    final notifier = ref.read(cameraScanNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Live Camera Feed or Test Viewport
          if (widget.useSimulatedFeed)
            _buildSimulatedViewport()
          else
            _buildLiveScannerViewport(),

          // 2. Central Reticle Overlay
          IgnorePointer(
            child: CameraReticleOverlay(
              status: state.status,
              hasGlareAlert: state.hasGlareAlert,
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

          // 4. Top Action Bar
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

          // 5. Bottom Controls & Guidance
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
                            : 'Align barcode or ingredients within reticle box',
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

  Widget _buildLiveScannerViewport() {
    return MobileScanner(
      controller: _scannerController,
      onDetect: _handleBarcodeCapture,
      errorBuilder: (context, error, child) {
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
