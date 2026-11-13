import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/camera/presentation/widgets/multi_angle_capture_strip.dart';

void main() {
  testWidgets('MultiAngleCaptureStrip renders 4 capture slots and reflects captured count', (tester) async {
    bool submitTriggered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MultiAngleCaptureStrip(
            capturedFramesCount: 2,
            maxFrames: 4,
            onSubmit: () {
              submitTriggered = true;
            },
            onClear: () {},
          ),
        ),
      ),
    );

    expect(find.text('Curved Bottle Multi-Angle Mode (2/4)'), findsOneWidget);
    expect(find.text('Slot 1: Captured'), findsOneWidget);
    expect(find.text('Slot 2: Captured'), findsOneWidget);
    expect(find.text('Slot 3: Empty'), findsOneWidget);

    final submitBtn = find.widgetWithText(ElevatedButton, 'Submit Multi-Angle Cloud Scan');
    expect(submitBtn, findsOneWidget);
    await tester.tap(submitBtn);
    await tester.pump();

    expect(submitTriggered, isTrue);
  });
}
