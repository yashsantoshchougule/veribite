import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/camera/domain/camera_scan_state.dart';
import 'package:mobile_app/features/camera/presentation/widgets/camera_reticle_painter.dart';
import 'package:mobile_app/features/camera/presentation/widgets/glare_alert_banner.dart';

void main() {
  testWidgets('CameraReticleOverlay displays green color when barcode is locked', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CameraReticleOverlay(
            status: CameraScanStatus.barcodeLocked,
            hasGlareAlert: false,
          ),
        ),
      ),
    );

    final customPaintFinder = find.byType(CustomPaint);
    expect(customPaintFinder, findsWidgets);

    final overlay = tester.widget<CameraReticleOverlay>(find.byType(CameraReticleOverlay));
    expect(overlay.status, CameraScanStatus.barcodeLocked);
  });

  testWidgets('CameraReticleOverlay renders with focusPoint and isFocusLocked', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CameraReticleOverlay(
            status: CameraScanStatus.searching,
            hasGlareAlert: false,
            focusPoint: Offset(200, 200),
            isFocusLocked: true,
          ),
        ),
      ),
    );

    final overlay = tester.widget<CameraReticleOverlay>(find.byType(CameraReticleOverlay));
    expect(overlay.isFocusLocked, isTrue);
    expect(overlay.focusPoint, const Offset(200, 200));
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('GlareAlertBanner displays warning text when active', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GlareAlertBanner(
            message: 'Foil Glare Detected — Tilt Packet 15°',
          ),
        ),
      ),
    );

    expect(find.text('Foil Glare Detected — Tilt Packet 15°'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
  });
}
