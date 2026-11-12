import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

/// Data model representing a remote update release manifest.
class AppUpdateInfo {
  final String latestVersion;
  final int latestBuildNumber;
  final String releaseDate;
  final String apkSizeMb;
  final String webpageUrl;
  final String apkDownloadUrl;
  final bool forceUpdate;
  final List<String> releaseNotes;
  final bool hasUpdate;

  const AppUpdateInfo({
    required this.latestVersion,
    required this.latestBuildNumber,
    required this.releaseDate,
    required this.apkSizeMb,
    required this.webpageUrl,
    required this.apkDownloadUrl,
    required this.forceUpdate,
    required this.releaseNotes,
    required this.hasUpdate,
  });

  factory AppUpdateInfo.fromJson(
    Map<String, dynamic> json, {
    int currentBuild = AppUpdateService.currentBuildNumber,
    String currentVersion = AppUpdateService.currentVersion,
  }) {
    final versionStr = json['latest_version']?.toString() ?? '1.0.0';
    final buildNum = json['latest_build_number'] is int
        ? json['latest_build_number'] as int
        : int.tryParse(json['latest_build_number']?.toString() ?? '1') ?? 1;

    final hasUpdate = buildNum > currentBuild ||
        AppUpdateService.isVersionGreater(versionStr, currentVersion);

    final rawNotes = json['release_notes'];
    final List<String> notes = [];
    if (rawNotes is List) {
      for (final item in rawNotes) {
        if (item != null) notes.add(item.toString());
      }
    }

    return AppUpdateInfo(
      latestVersion: versionStr,
      latestBuildNumber: buildNum,
      releaseDate: json['release_date']?.toString() ?? '',
      apkSizeMb: json['apk_size_mb']?.toString() ?? '24.5 MB',
      webpageUrl: json['webpage_url']?.toString() ??
          'https://github.com/yashsantoshchougule/veribite',
      apkDownloadUrl: json['apk_download_url']?.toString() ??
          'https://github.com/yashsantoshchougule/veribite/releases/latest/download/app-release.apk',
      forceUpdate: json['force_update'] == true,
      releaseNotes: notes,
      hasUpdate: hasUpdate,
    );
  }

  factory AppUpdateInfo.fromGitHubRelease(
    Map<String, dynamic> json, {
    int currentBuild = AppUpdateService.currentBuildNumber,
    String currentVersion = AppUpdateService.currentVersion,
  }) {
    final tagName = (json['tag_name']?.toString() ?? 'v1.0.0').replaceFirst('v', '');
    final htmlUrl = json['html_url']?.toString() ??
        'https://github.com/yashsantoshchougule/veribite';

    String apkUrl = '$htmlUrl/releases/latest/download/app-release.apk';
    String apkSize = '24.5 MB';

    final assets = json['assets'];
    if (assets is List) {
      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = asset['name']?.toString() ?? '';
          if (name.endsWith('.apk')) {
            apkUrl = asset['browser_download_url']?.toString() ?? apkUrl;
            final sizeBytes = asset['size'] as int?;
            if (sizeBytes != null) {
              apkSize = '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
            }
            break;
          }
        }
      }
    }

    final body = json['body']?.toString() ?? '';
    final notes = body
        .split('\n')
        .map((l) => l.trim().replaceAll(RegExp(r'^[-*]\s*'), ''))
        .where((l) => l.isNotEmpty && !l.startsWith('#'))
        .toList();

    return AppUpdateInfo(
      latestVersion: tagName,
      latestBuildNumber: currentBuild + 1,
      releaseDate: json['published_at']?.toString().split('T').first ?? '',
      apkSizeMb: apkSize,
      webpageUrl: htmlUrl,
      apkDownloadUrl: apkUrl,
      forceUpdate: false,
      releaseNotes: notes.isNotEmpty ? notes : ['New stability improvements and fixes'],
      hasUpdate: AppUpdateService.isVersionGreater(tagName, currentVersion),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'latest_version': latestVersion,
      'latest_build_number': latestBuildNumber,
      'release_date': releaseDate,
      'apk_size_mb': apkSizeMb,
      'webpage_url': webpageUrl,
      'apk_download_url': apkDownloadUrl,
      'force_update': forceUpdate,
      'release_notes': releaseNotes,
      'has_update': hasUpdate,
    };
  }
}

/// In-App Update Checker Service.
/// Communicates with an external manifest server or GitHub Releases API to check
/// for newer app builds, parse release notes, and launch downloads cleanly.
class AppUpdateService {
  AppUpdateService._internal();
  static final AppUpdateService instance = AppUpdateService._internal();

  /// Installed app version matching pubspec.yaml
  static const String currentVersion = '1.0.1';

  /// Installed build number matching pubspec.yaml
  static const int currentBuildNumber = 2;

  /// Configurable remote manifest URL (defaulting to raw repository version.json)
  static const String defaultManifestUrl = String.fromEnvironment(
    'VERIBITE_UPDATE_MANIFEST_URL',
    defaultValue: 'https://raw.githubusercontent.com/yashsantoshchougule/VeriBite/main/version.json',
  );

  /// GitHub fallback API
  static const String githubReleasesApiUrl =
      'https://api.github.com/repos/yashsantoshchougule/VeriBite/releases/latest';

  /// In-memory session tracking for dismissed update versions so auto-checks
  /// do not continually nag the user unless forceUpdate is specified.
  String? _dismissedVersion;

  void dismissVersion(String version) {
    _dismissedVersion = version;
  }

  bool isVersionDismissed(String version) {
    return _dismissedVersion == version;
  }

  void resetDismissedVersion() {
    _dismissedVersion = null;
  }

  /// Checks for newer releases.
  /// When [manual] is true, checks are performed even if previously dismissed.
  Future<AppUpdateInfo?> checkForUpdate({
    bool manual = false,
    String? manifestUrl,
    http.Client? client,
  }) async {
    final httpClient = client ?? http.Client();
    final url = manifestUrl ?? defaultManifestUrl;

    try {
      // 1. Attempt fetching primary manifest URL
      if (url.isNotEmpty) {
        try {
          final response = await httpClient
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 4));
          if (response.statusCode == 200) {
            final data = json.decode(utf8.decode(response.bodyBytes));
            if (data is Map<String, dynamic>) {
              final info = AppUpdateInfo.fromJson(data);
              if (!manual && !info.forceUpdate && isVersionDismissed(info.latestVersion)) {
                return null;
              }
              return info;
            }
          }
        } catch (e) {
          debugPrint('[AppUpdateService] Primary manifest fetch failed ($url): $e');
        }
      }

      // 2. Fallback check against GitHub Releases API
      try {
        final ghResponse = await httpClient
            .get(
              Uri.parse(githubReleasesApiUrl),
              headers: {'Accept': 'application/vnd.github.v3+json'},
            )
            .timeout(const Duration(seconds: 4));
        if (ghResponse.statusCode == 200) {
          final data = json.decode(utf8.decode(ghResponse.bodyBytes));
          if (data is Map<String, dynamic>) {
            final info = AppUpdateInfo.fromGitHubRelease(data);
            if (!manual && !info.forceUpdate && isVersionDismissed(info.latestVersion)) {
              return null;
            }
            return info;
          }
        }
      } catch (e) {
        debugPrint('[AppUpdateService] GitHub fallback fetch failed: $e');
      }

      return null;
    } finally {
      if (client == null) {
        httpClient.close();
      }
    }
  }

  /// Launch external browser or download link cleanly using url_launcher
  Future<bool> launchUpdateUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('[AppUpdateService] Could not launch URL: $url ($e)');
    }
    return false;
  }

  /// Compares semantic versions (e.g., '1.0.1' > '1.0.0' returns true)
  static bool isVersionGreater(String remote, String local) {
    try {
      final cleanRemote = remote.trim().replaceAll(RegExp(r'^[vV]'), '');
      final cleanLocal = local.trim().replaceAll(RegExp(r'^[vV]'), '');

      final remoteParts = cleanRemote.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      final localParts = cleanLocal.split('.').map((p) => int.tryParse(p) ?? 0).toList();

      final maxLength = remoteParts.length > localParts.length ? remoteParts.length : localParts.length;

      for (int i = 0; i < maxLength; i++) {
        final r = i < remoteParts.length ? remoteParts[i] : 0;
        final l = i < localParts.length ? localParts[i] : 0;
        if (r > l) return true;
        if (r < l) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}

