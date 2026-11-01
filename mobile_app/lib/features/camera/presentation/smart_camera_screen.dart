import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/features/camera/application/camera_scan_notifier.dart';
import 'package:mobile_app/features/camera/presentation/widgets/camera_reticle_painter.dart';
import 'package:mobile_app/features/camera/presentation/widgets/glare_alert_banner.dart';
import 'package:mobile_app/features/camera/presentation/widgets/multi_angle_capture_strip.dart';
import 'package:mobile_app/features/camera/presentation/widgets/quick_macro_slider_sheet.dart';

class SmartCameraScreen extends ConsumerWidget {
  final ValueChanged<Map<String, dynamic>>? onProductResolved;

  const SmartCameraScreen({
    super.key,
    this.onProductResolved,
  });

  void _openMacroSliderSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickMacroSliderSheet(
        onSubmit: (macros) {
          Navigator.of(context).pop();
          if (onProductResolved != null) {
            onProductResolved!({
              'source': 'manual_slider',
              'nutrition': macros,
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(cameraScanNotifierProvider);
    final notifier = ref.read(cameraScanNotifierProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Simulated camera feed / viewfinder viewport
          Container(
            color: const Color(0xFF121212),
            child: const Center(
              child: Icon(Icons.videocam_outlined, size: 72, color: Colors.white24),
            ),
          ),

          // Central Reticle Overlay
          CameraReticleOverlay(
            status: state.status,
            hasGlareAlert: state.hasGlareAlert,
          ),

          // Specular Glare Alert Banner
          if (state.hasGlareAlert && state.glareBadgeText != null)
            Positioned(
              top: 110,
              left: 24,
              right: 24,
              child: Center(
                child: GlareAlertBanner(message: state.glareBadgeText!),
              ),
            ),

          // Top Action Bar
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
                      onPressed: notifier.toggleTorch,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Controls & Fallbacks
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
                        if (onProductResolved != null) {
                          onProductResolved!({
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
                      child: const Text(
                        'Align barcode or ingredients within reticle box',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
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
                        onPressed: () => _openMacroSliderSheet(context, ref),
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
}
