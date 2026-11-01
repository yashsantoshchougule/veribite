import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/features/camera/application/camera_scan_notifier.dart';
import 'package:mobile_app/features/camera/domain/camera_scan_state.dart';

void main() {
  test('CameraScanNotifier transitions to barcodeLocked on valid EAN-13', () {
    final container = ProviderContainer();
    final notifier = container.read(cameraScanNotifierProvider.notifier);

    notifier.onBarcodeScanned('8901030383786');
    final state = container.read(cameraScanNotifierProvider);

    expect(state.status, CameraScanStatus.barcodeLocked);
    expect(state.barcode, '8901030383786');
  });

  test('CameraScanNotifier flags glare alert when saturated pixels exceed 18%', () {
    final container = ProviderContainer();
    final notifier = container.read(cameraScanNotifierProvider.notifier);

    final saturatedPixels = List<int>.filled(25, 255) + List<int>.filled(75, 100);
    notifier.onLuminanceSample(saturatedPixels);
    final state = container.read(cameraScanNotifierProvider);

    expect(state.hasGlareAlert, isTrue);
    expect(state.glareBadgeText, contains('Foil Glare Detected'));
  });

  test('CameraScanNotifier adds captured frame for multi-angle mode', () {
    final container = ProviderContainer();
    final notifier = container.read(cameraScanNotifierProvider.notifier);

    notifier.setMultiAngleMode(true);
    notifier.addMultiAngleFrame([1, 2, 3]);
    final state = container.read(cameraScanNotifierProvider);

    expect(state.isMultiAngleMode, isTrue);
    expect(state.capturedFrames.length, 1);
  });
}
