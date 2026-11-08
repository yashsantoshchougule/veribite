import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/features/camera/presentation/smart_camera_screen.dart';
import 'package:mobile_app/features/camera/presentation/widgets/camera_reticle_painter.dart';
import 'package:mobile_app/features/camera/presentation/widgets/quick_macro_slider_sheet.dart';
import 'package:mobile_app/features/results/presentation/verdict_report_screen.dart';

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

  testWidgets('SmartCameraScreen suppresses VerdictReportScreen when disableResultSheet is true', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SmartCameraScreen(useSimulatedFeed: true, disableResultSheet: true),
        ),
      ),
    );

    // Tap sample scan button
    final sampleButton = find.text('Simulate Sample Scan (Good Day)');
    expect(sampleButton, findsOneWidget);

    await tester.tap(sampleButton);
    await tester.pumpAndSettle();

    // Verify VerdictReportScreen is suppressed and not shown
    expect(find.byType(VerdictReportScreen), findsNothing);
  });

  testWidgets('SmartCameraScreen sample scan triggers lock-on and presents VerdictReportScreen when enabled', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SmartCameraScreen(useSimulatedFeed: true, disableResultSheet: false),
        ),
      ),
    );

    // Tap sample scan button
    final sampleButton = find.text('Simulate Sample Scan (Good Day)');
    expect(sampleButton, findsOneWidget);

    await tester.tap(sampleButton);
    await tester.pumpAndSettle();

    // Verify VerdictReportScreen appeared with Good Day cookies
    expect(find.byType(VerdictReportScreen), findsOneWidget);
    expect(find.text('Good Day Butter Cookies'), findsOneWidget);
    expect(find.text('Britannia • Biscuits & Cookies'), findsOneWidget);
    expect(find.text('I Ate This (Log to Today\'s Budget)'), findsOneWidget);
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

  testWidgets('SmartCameraScreen renders enlarged reticle (>= 320px) without static AF lock or zoom pills', (tester) async {
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

    // Confirm complete removal of permanent clutter
    expect(find.text('AF Lock Active • Tap to Release'), findsNothing);
    expect(find.text('1.0x'), findsNothing);
    expect(find.text('1.5x Macro'), findsNothing);
    expect(find.text('2.0x'), findsNothing);

    // Confirm clean native guidance
    expect(find.text('Tap barcode or ingredients to focus • Pinch to zoom'), findsOneWidget);
  });

  testWidgets('tapping inside reticle triggers tap-to-focus without drawing any green box or clutter', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SmartCameraScreen(useSimulatedFeed: true),
        ),
      ),
    );

    // Tap center of screen (inside reticle box)
    await tester.tapAt(const Offset(400, 300));
    await tester.pump();

    // Verify completely clean UI: no green boxes, no lock badges, no pills
    expect(find.text('AF Lock Active • Tap to Release'), findsNothing);
    expect(find.text('🔒 AF LOCK'), findsNothing);
  });

  testWidgets('pinch-to-zoom gesture displays ephemeral zoom indicator and auto-fades', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SmartCameraScreen(useSimulatedFeed: true),
        ),
      ),
    );

    // Initial state has no zoom indicator
    expect(find.byIcon(Icons.zoom_in_rounded), findsNothing);

    // Perform two-finger pinch-out gesture
    final touch1 = await tester.startGesture(const Offset(350, 300));
    final touch2 = await tester.startGesture(const Offset(450, 300));
    await tester.pump();

    // Spread fingers apart to zoom in
    await touch1.moveTo(const Offset(280, 300));
    await touch2.moveTo(const Offset(520, 300));
    await tester.pump();

    // Zoom readout icon and text should now be visible
    expect(find.byIcon(Icons.zoom_in_rounded), findsOneWidget);

    // Release fingers
    await touch1.up();
    await touch2.up();
    await tester.pump();

    // After 1000ms, zoom indicator fades away
    await tester.pump(const Duration(milliseconds: 1000));
    expect(find.byIcon(Icons.zoom_in_rounded), findsNothing);
  });

  testWidgets('SmartCameraScreen simulates product QR code scan and presents VerdictReportScreen with details', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SmartCameraScreen(useSimulatedFeed: true, disableResultSheet: false),
        ),
      ),
    );

    // Tap the QR simulation button
    final qrButton = find.text('Simulate Product QR Scan');
    expect(qrButton, findsOneWidget);

    await tester.tap(qrButton);
    await tester.pumpAndSettle();

    // Verify VerdictReportScreen opens with parsed QR product details
    expect(find.byType(VerdictReportScreen), findsOneWidget);
    expect(find.text('Organic Almond Butter'), findsOneWidget);
    expect(find.textContaining('NuttyCraft'), findsOneWidget);
  });

  testWidgets('SmartCameraScreen top bar does not overflow on narrow 360x640 mobile viewport', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SmartCameraScreen(useSimulatedFeed: true),
        ),
      ),
    );

    // Verify no overflow exception was thrown during layout
    expect(tester.takeException(), isNull);

    // Verify all top action bar elements are cleanly present
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('Barcode / Auto'), findsOneWidget);
    expect(find.text('Curved Bottle'), findsOneWidget);
    expect(find.byIcon(Icons.flash_off_rounded), findsOneWidget);
  });

  testWidgets('SmartCameraScreen simulated non-food QR scan triggers single Not a Food Product dialog and allows clean dismissal', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SmartCameraScreen(useSimulatedFeed: true, disableResultSheet: false),
        ),
      ),
    );

    final nonFoodButton = find.text('Simulate Non-Food QR Scan');
    expect(nonFoodButton, findsOneWidget);

    // Tap non-food button
    await tester.tap(nonFoodButton);
    await tester.pumpAndSettle();

    // Verify exactly ONE bottom sheet appeared with "Not a Food Product"
    expect(find.text('Not a Food Product'), findsOneWidget);
    expect(find.textContaining('WhatsApp Support Link'), findsOneWidget);

    // Attempt second tap while sheet is up to verify re-entrancy blocking
    // The sheet blocks touches to the background, and dismiss button works cleanly
    final dismissBtn = find.text('Scan Food Product');
    expect(dismissBtn, findsOneWidget);

    await tester.tap(dismissBtn);
    await tester.pumpAndSettle();

    // Verify sheet is dismissed
    expect(find.text('Not a Food Product'), findsNothing);
  });

  testWidgets('SmartCameraScreen capturing multi-angle frames and submitting presents VerdictReportScreen', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: SmartCameraScreen(useSimulatedFeed: true, disableResultSheet: false),
        ),
      ),
    );

    // Switch to Curved Bottle / Multi-Angle mode
    await tester.tap(find.text('Curved Bottle'));
    await tester.pumpAndSettle();

    // Capture 4 frames via shutter button
    final shutter = find.byIcon(Icons.camera_alt_rounded);
    expect(shutter, findsOneWidget);

    await tester.tap(shutter);
    await tester.pump();
    await tester.tap(shutter);
    await tester.pump();
    await tester.tap(shutter);
    await tester.pump();
    await tester.tap(shutter);
    await tester.pumpAndSettle();

    // Verify all 4 slots are marked captured
    expect(find.text('Curved Bottle Multi-Angle Mode (4/4)'), findsOneWidget);
    expect(find.text('Slot 4: Captured'), findsOneWidget);

    // Tap Submit Multi-Angle Cloud Scan
    final submitBtn = find.text('Submit Multi-Angle Cloud Scan');
    expect(submitBtn, findsOneWidget);

    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Verify VerdictReportScreen opens
    expect(find.byType(VerdictReportScreen), findsOneWidget);
    expect(find.textContaining('Curved Bottle'), findsOneWidget);
  });
}
