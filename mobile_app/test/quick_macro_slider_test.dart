import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/camera/presentation/widgets/quick_macro_slider_sheet.dart';

void main() {
  testWidgets('QuickMacroSliderSheet renders 3 sliders and invokes onSubmit', (tester) async {
    Map<String, double>? submittedMacros;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickMacroSliderSheet(
            initialSugar: 15.0,
            initialSatFat: 6.0,
            initialSodium: 250.0,
            onSubmit: (values) {
              submittedMacros = values;
            },
          ),
        ),
      ),
    );

    // Verify sliders exist
    expect(find.text('Quick Macro Manual Input'), findsOneWidget);
    expect(find.textContaining('Sugar: 15.0g'), findsOneWidget);
    expect(find.textContaining('Saturated Fat: 6.0g'), findsOneWidget);
    expect(find.textContaining('Sodium: 250mg'), findsOneWidget);

    // Tap submit button
    final submitButton = find.widgetWithText(ElevatedButton, 'Compute Health Score & Dosage');
    expect(submitButton, findsOneWidget);
    await tester.tap(submitButton);
    await tester.pump();

    expect(submittedMacros, isNotNull);
    expect(submittedMacros!['sugar_g_per_100g'], 15.0);
    expect(submittedMacros!['sat_fat_g_per_100g'], 6.0);
    expect(submittedMacros!['sodium_mg_per_100g'], 250.0);
  });

  testWidgets('QuickMacroSliderSheet safely clamps out-of-bounds or extreme initial macro values without assertion crash', (tester) async {
    Map<String, double>? submittedMacros;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuickMacroSliderSheet(
            initialSugar: 120.0, // > 100 max
            initialSatFat: 80.0,  // > 60 max
            initialSodium: 4000.0, // > 3000 max
            onSubmit: (values) {
              submittedMacros = values;
            },
          ),
        ),
      ),
    );

    // Verify sliders clamped safely to maximums without throwing assertion error
    expect(find.textContaining('Sugar: 100.0g'), findsOneWidget);
    expect(find.textContaining('Saturated Fat: 60.0g'), findsOneWidget);
    expect(find.textContaining('Sodium: 3000mg'), findsOneWidget);

    final submitButton = find.widgetWithText(ElevatedButton, 'Compute Health Score & Dosage');
    await tester.tap(submitButton);
    await tester.pump();

    expect(submittedMacros!['sugar_g_per_100g'], 100.0);
    expect(submittedMacros!['sat_fat_g_per_100g'], 60.0);
    expect(submittedMacros!['sodium_mg_per_100g'], 3000.0);
  });
}
