import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile_app/services/app_update_service.dart';

void main() {
  group('AppUpdateInfo Model Tests', () {
    test('parses version.json schema correctly and detects update when build is newer', () {
      final jsonMap = {
        'latest_version': '1.0.1',
        'latest_build_number': 2,
        'release_date': '2026-11-12',
        'apk_size_mb': '24.5 MB',
        'webpage_url': 'https://your-webpage-domain.com',
        'apk_download_url':
            'https://github.com/yashsantoshchougule/VeriBite/releases/latest/download/app-release.apk',
        'force_update': false,
        'release_notes': [
          'Faster 3.0s parallel QR & barcode scanner',
          'Live Web & FSSAI Clinical Intelligence deep-search',
          'Non-food image upload guard',
          "Interactive Today's Intake Log & persistent user profile",
        ],
      };

      final info = AppUpdateInfo.fromJson(jsonMap, currentBuild: 1, currentVersion: '1.0.0');

      expect(info.latestVersion, '1.0.1');
      expect(info.latestBuildNumber, 2);
      expect(info.releaseDate, '2026-11-12');
      expect(info.apkSizeMb, '24.5 MB');
      expect(info.webpageUrl, 'https://your-webpage-domain.com');
      expect(info.apkDownloadUrl, contains('app-release.apk'));
      expect(info.forceUpdate, isFalse);
      expect(info.releaseNotes.length, 4);
      expect(info.hasUpdate, isTrue);
    });

    test('detects no update when installed version and build match latest', () {
      final jsonMap = {
        'latest_version': '1.0.0',
        'latest_build_number': 1,
        'release_date': '2026-11-10',
        'apk_size_mb': '24.0 MB',
        'webpage_url': 'https://github.com/yashsantoshchougule/veribite',
        'apk_download_url':
            'https://github.com/yashsantoshchougule/veribite/releases/latest/download/app-release.apk',
        'force_update': false,
        'release_notes': ['Initial release'],
      };

      final info = AppUpdateInfo.fromJson(jsonMap, currentBuild: 1, currentVersion: '1.0.0');

      expect(info.hasUpdate, isFalse);
    });

    test('parses GitHub Release API payload fallback correctly', () {
      final ghMap = {
        'tag_name': 'v1.0.2',
        'html_url': 'https://github.com/yashsantoshchougule/veribite/releases/tag/v1.0.2',
        'published_at': '2026-11-12T10:30:00Z',
        'body': '## Release 1.0.2\n- Improved scanner accuracy\n- Offline nutrition updates',
        'assets': [
          {
            'name': 'app-release.apk',
            'size': 25690112, // ~24.5 MB
            'browser_download_url':
                'https://github.com/yashsantoshchougule/veribite/releases/download/v1.0.2/app-release.apk',
          }
        ],
      };

      final info = AppUpdateInfo.fromGitHubRelease(ghMap, currentBuild: 1, currentVersion: '1.0.0');

      expect(info.latestVersion, '1.0.2');
      expect(info.apkSizeMb, '24.5 MB');
      expect(info.apkDownloadUrl, contains('app-release.apk'));
      expect(info.releaseNotes, contains('Improved scanner accuracy'));
      expect(info.releaseNotes, contains('Offline nutrition updates'));
      expect(info.hasUpdate, isTrue);
    });
  });

  group('Semantic Version Comparison Tests', () {
    test('isVersionGreater handles various semantic version strings', () {
      expect(AppUpdateService.isVersionGreater('1.0.1', '1.0.0'), isTrue);
      expect(AppUpdateService.isVersionGreater('v1.1.0', '1.0.9'), isTrue);
      expect(AppUpdateService.isVersionGreater('2.0.0', '1.9.9'), isTrue);
      expect(AppUpdateService.isVersionGreater('1.0.0', '1.0.0'), isFalse);
      expect(AppUpdateService.isVersionGreater('1.0.0', '1.0.1'), isFalse);
      expect(AppUpdateService.isVersionGreater('0.9.9', '1.0.0'), isFalse);
    });
  });

  group('AppUpdateService Remote Fetch & Dismissal Tests', () {
    setUp(() {
      AppUpdateService.instance.resetDismissedVersion();
    });

    test('checkForUpdate successfully fetches and parses manifest via HTTP client', () async {
      final mockClient = MockClient((request) async {
        if (request.url.path.endsWith('version.json')) {
          return http.Response(
            json.encode({
              'latest_version': '1.0.1',
              'latest_build_number': 2,
              'release_date': '2026-11-12',
              'apk_size_mb': '24.5 MB',
              'webpage_url': 'https://your-webpage-domain.com',
              'apk_download_url':
                  'https://github.com/yashsantoshchougule/VeriBite/releases/latest/download/app-release.apk',
              'force_update': false,
              'release_notes': ['Feature A', 'Feature B'],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final result = await AppUpdateService.instance.checkForUpdate(
        manifestUrl: 'https://example.com/version.json',
        client: mockClient,
      );

      expect(result, isNotNull);
      expect(result!.latestVersion, '1.0.1');
      expect(result.hasUpdate, isTrue);
    });

    test('auto-check suppresses notification if version was dismissed', () async {
      AppUpdateService.instance.dismissVersion('1.0.1');
      expect(AppUpdateService.instance.isVersionDismissed('1.0.1'), isTrue);

      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'latest_version': '1.0.1',
            'latest_build_number': 2,
            'force_update': false,
            'release_notes': ['Notes'],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      // Auto-check (manual: false) -> suppressed (returns null)
      final autoResult = await AppUpdateService.instance.checkForUpdate(
        manual: false,
        manifestUrl: 'https://example.com/version.json',
        client: mockClient,
      );
      expect(autoResult, isNull);

      // Manual check (manual: true) -> ignores dismissal and returns info
      final manualResult = await AppUpdateService.instance.checkForUpdate(
        manual: true,
        manifestUrl: 'https://example.com/version.json',
        client: mockClient,
      );
      expect(manualResult, isNotNull);
      expect(manualResult!.latestVersion, '1.0.1');
    });

    test('force_update: true overrides dismissal even in auto-check', () async {
      AppUpdateService.instance.dismissVersion('1.0.1');

      final mockClient = MockClient((request) async {
        return http.Response(
          json.encode({
            'latest_version': '1.0.1',
            'latest_build_number': 2,
            'force_update': true,
            'release_notes': ['Security Patch'],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final result = await AppUpdateService.instance.checkForUpdate(
        manual: false,
        manifestUrl: 'https://example.com/version.json',
        client: mockClient,
      );

      expect(result, isNotNull);
      expect(result!.forceUpdate, isTrue);
    });

    test('returns null and does not throw on network failure', () async {
      final mockClient = MockClient((request) async {
        throw Exception('Network unreachable');
      });

      final result = await AppUpdateService.instance.checkForUpdate(
        manifestUrl: 'https://example.com/version.json',
        client: mockClient,
      );

      expect(result, isNull);
    });
  });
}
