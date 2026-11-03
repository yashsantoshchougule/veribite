import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';

void main() {
  testWidgets('ScannerApp boots to StarterWalkthroughScreen smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: ScannerApp()));

    expect(find.textContaining('Point & Scan'), findsOneWidget);
    expect(find.text('Next Step →'), findsOneWidget);
  });
}
