import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/features/camera/presentation/smart_camera_screen.dart';
import 'package:mobile_app/features/camera/presentation/widgets/camera_reticle_painter.dart';

void main() {
  testWidgets('SmartCameraScreen renders reticle, torch toggle, and mode chips', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SmartCameraScreen(),
        ),
      ),
    );

    // Verify reticle overlay is rendered
    expect(find.byType(CameraReticleOverlay), findsOneWidget);

    // Verify torch icon button
    expect(find.byIcon(Icons.flash_off_rounded), findsOneWidget);

    // Verify mode chips
    expect(find.text('Barcode / Auto'), findsOneWidget);
    expect(find.text('Curved Bottle'), findsOneWidget);

    // Verify manual macro input trigger button
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
  });

  testWidgets('SmartCameraScreen toggles multi-angle mode on chip tap', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SmartCameraScreen(),
        ),
      ),
    );

    // Tap Curved Bottle chip
    await tester.tap(find.text('Curved Bottle'));
    await tester.pump();

    // Verify multi-angle capture strip shows up
    expect(find.textContaining('Curved Bottle Multi-Angle Mode'), findsOneWidget);
  });
}
