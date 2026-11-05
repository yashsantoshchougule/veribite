import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/features/camera/presentation/smart_camera_screen.dart';
import 'package:mobile_app/features/camera/presentation/widgets/camera_reticle_painter.dart';
import 'package:mobile_app/features/camera/presentation/widgets/quick_macro_slider_sheet.dart';
import 'package:mobile_app/features/camera/presentation/widgets/scan_result_sheet.dart';

void main() {
  testWidgets('SmartCameraScreen renders reticle, torch toggle, and mode chips', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SmartCameraScreen(useSimulatedFeed: true),
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
          home: SmartCameraScreen(useSimulatedFeed: true),
        ),
      ),
    );

    // Tap Curved Bottle chip
    await tester.tap(find.text('Curved Bottle'));
    await tester.pump();

    // Verify multi-angle capture strip shows up
    expect(find.textContaining('Curved Bottle Multi-Angle Mode'), findsOneWidget);
  });

  testWidgets('SmartCameraScreen sample scan triggers lock-on and presents ScanResultSheet', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SmartCameraScreen(useSimulatedFeed: true),
        ),
      ),
    );

    // Tap sample scan button
    final sampleButton = find.text('Simulate Sample Scan (Good Day)');
    expect(sampleButton, findsOneWidget);

    await tester.tap(sampleButton);
    await tester.pumpAndSettle();

    // Verify ScanResultSheet appeared with Good Day cookies
    expect(find.byType(ScanResultSheet), findsOneWidget);
    expect(find.text('Good Day Butter Cookies'), findsOneWidget);
    expect(find.text('Britannia • Biscuits & Cookies'), findsOneWidget);
    expect(find.text('I Ate This (Add to Today\'s Sugar Budget)'), findsOneWidget);
    expect(find.text('Just Checking (Don\'t Add to Budget)'), findsOneWidget);
  });

  testWidgets('tapping manual macro input button opens QuickMacroSliderSheet', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SmartCameraScreen(useSimulatedFeed: true),
        ),
      ),
    );

    // Tap manual macro button
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();

    // Verify QuickMacroSliderSheet opened
    expect(find.byType(QuickMacroSliderSheet), findsOneWidget);
    expect(find.text('Quick Macro Manual Input'), findsOneWidget);
  });

  testWidgets('SmartCameraScreen renders enlarged reticle (>= 320px) and macro zoom selector', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SmartCameraScreen(useSimulatedFeed: true),
        ),
      ),
    );

    final overlay = tester.widget<CameraReticleOverlay>(find.byType(CameraReticleOverlay));
    expect(overlay.reticleWidth, greaterThanOrEqualTo(320.0));
    expect(overlay.reticleHeight, greaterThanOrEqualTo(300.0));

    // Verify 1-tap macro zoom options
    expect(find.text('1.0x'), findsOneWidget);
    expect(find.text('1.5x Macro'), findsOneWidget);
    expect(find.text('2.0x'), findsOneWidget);
  });

  testWidgets('tapping inside reticle locks focus and renders AF lock indicators', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SmartCameraScreen(useSimulatedFeed: true),
        ),
      ),
    );

    // Center of screen (default 800x600 in test environment) is inside reticle
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();

    // Verify AF lock pill and guidance text are displayed
    expect(find.text('AF Lock Active • Tap to Release'), findsOneWidget);
    expect(find.textContaining('Target locked • Hold steady'), findsOneWidget);

    final overlay = tester.widget<CameraReticleOverlay>(find.byType(CameraReticleOverlay));
    expect(overlay.isFocusLocked, isTrue);
    expect(overlay.focusPoint, isNotNull);

    // Tapping the AF lock release pill clears focus
    await tester.tap(find.text('AF Lock Active • Tap to Release'));
    await tester.pump();

    expect(find.text('AF Lock Active • Tap to Release'), findsNothing);
    final overlayAfter = tester.widget<CameraReticleOverlay>(find.byType(CameraReticleOverlay));
    expect(overlayAfter.isFocusLocked, isFalse);
  });

  testWidgets('tapping outside reticle box auto-releases focus lock', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SmartCameraScreen(useSimulatedFeed: true),
        ),
      ),
    );

    // Lock focus first
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();
    expect(find.text('AF Lock Active • Tap to Release'), findsOneWidget);

    // Tap outside reticle (e.g. top-left corner at 15, 15)
    await tester.tapAt(const Offset(15, 15));
    await tester.pump();

    expect(find.text('AF Lock Active • Tap to Release'), findsNothing);
    final overlay = tester.widget<CameraReticleOverlay>(find.byType(CameraReticleOverlay));
    expect(overlay.isFocusLocked, isFalse);
  });

  testWidgets('tapping macro zoom button updates active zoom scale', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SmartCameraScreen(useSimulatedFeed: true),
        ),
      ),
    );

    // Tap 1.5x Macro
    await tester.tap(find.text('1.5x Macro'));
    await tester.pump();

    // Tap 2.0x
    await tester.tap(find.text('2.0x'));
    await tester.pump();

    // Verify widget did not throw and remains stable
    expect(find.text('2.0x'), findsOneWidget);
  });
}
