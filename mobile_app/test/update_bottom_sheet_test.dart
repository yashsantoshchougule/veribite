import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/home/presentation/widgets/update_available_bottom_sheet.dart';
import 'package:mobile_app/services/app_update_service.dart';

void main() {
  Widget buildTestableBottomSheet(AppUpdateInfo info) {
    return MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () => UpdateAvailableBottomSheet.show(context, info),
              child: const Text('Show Sheet'),
            ),
          ),
        ),
      ),
    );
  }

  group('UpdateAvailableBottomSheet Widget Tests', () {
    testWidgets('renders version, size, release date, and release notes correctly', (tester) async {
      const info = AppUpdateInfo(
        latestVersion: '1.0.1',
        latestBuildNumber: 2,
        releaseDate: '2026-11-12',
        apkSizeMb: '24.5 MB',
        webpageUrl: 'https://your-webpage-domain.com',
        apkDownloadUrl:
            'https://github.com/yashsantoshchougule/VeriBite/releases/latest/download/app-release.apk',
        forceUpdate: false,
        releaseNotes: [
          'Faster 3.0s parallel QR & barcode scanner',
          'Live Web & FSSAI Clinical Intelligence deep-search',
          'Non-food image upload guard',
          "Interactive Today's Intake Log & persistent user profile",
        ],
        hasUpdate: true,
      );

      await tester.pumpWidget(buildTestableBottomSheet(info));
      await tester.pumpAndSettle();

      // Tap button to show bottom sheet
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Assertions
      expect(find.text('Update Available'), findsOneWidget);
      expect(find.text('v1.0.1'), findsOneWidget);
      expect(find.textContaining('Build #2 • 24.5 MB • 2026-11-12'), findsOneWidget);
      expect(find.text("What's New in this Version"), findsOneWidget);
      expect(find.text('Faster 3.0s parallel QR & barcode scanner'), findsOneWidget);
      expect(find.text('Non-food image upload guard'), findsOneWidget);
      expect(find.text('Download & Install Update (24.5 MB)'), findsOneWidget);
      expect(find.text('Visit Download Webpage'), findsOneWidget);
      expect(find.text('Remind Me Later'), findsOneWidget);
    });

    testWidgets('omits Remind Me Later button and shows Critical Update when forceUpdate is true', (tester) async {
      const info = AppUpdateInfo(
        latestVersion: '2.0.0',
        latestBuildNumber: 5,
        releaseDate: '2026-11-20',
        apkSizeMb: '25.0 MB',
        webpageUrl: 'https://your-webpage-domain.com',
        apkDownloadUrl: 'https://example.com/app-release.apk',
        forceUpdate: true,
        releaseNotes: ['Mandatory security and database migration'],
        hasUpdate: true,
      );

      await tester.pumpWidget(buildTestableBottomSheet(info));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Critical Update Required'), findsOneWidget);
      expect(find.text('Remind Me Later'), findsNothing);
    });

    testWidgets('tapping Remind Me Later dismisses bottom sheet and sets dismissed version', (tester) async {
      AppUpdateService.instance.resetDismissedVersion();

      const info = AppUpdateInfo(
        latestVersion: '1.0.1',
        latestBuildNumber: 2,
        releaseDate: '2026-11-12',
        apkSizeMb: '24.5 MB',
        webpageUrl: '',
        apkDownloadUrl: 'https://example.com/app-release.apk',
        forceUpdate: false,
        releaseNotes: ['Minor fix'],
        hasUpdate: true,
      );

      await tester.pumpWidget(buildTestableBottomSheet(info));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      expect(find.byType(UpdateAvailableBottomSheet), findsOneWidget);

      await tester.tap(find.text('Remind Me Later'));
      await tester.pumpAndSettle();

      expect(find.byType(UpdateAvailableBottomSheet), findsNothing);
      expect(AppUpdateService.instance.isVersionDismissed('1.0.1'), isTrue);
    });
  });
}

