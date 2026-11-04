import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('ScannerApp boots to StarterWalkthroughScreen on 1st time install', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: ScannerApp()));
    await tester.pumpAndSettle();

    expect(find.textContaining('Point & Scan'), findsOneWidget);
    expect(find.text('Next Step →'), findsOneWidget);
  });

  testWidgets('ScannerApp boots directly to LoginScreen if walkthrough already completed', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'veribite_has_seen_walkthrough': true,
    });

    await tester.pumpWidget(const ProviderScope(child: ScannerApp()));
    await tester.pumpAndSettle();

    // Directly renders LoginScreen, never displays StarterWalkthroughScreen
    expect(find.text('Welcome to VeriBite'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.textContaining('Point & Scan'), findsNothing);
  });
}
