import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Status states for APK download and installation lifecycle
enum DownloadStatus {
  idle,
  downloading,
  verifying,
  readyToInstall,
  needsPermission,
  failed,
}

/// Reactive state model emitted during APK download and verification
class DownloadProgress {
  final DownloadStatus status;
  final int bytesDownloaded;
  final int totalBytes;
  final double progress; // 0.0 to 1.0
  final String? errorMessage;
  final String? downloadedFilePath;

  const DownloadProgress({
    required this.status,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.progress = 0.0,
    this.errorMessage,
    this.downloadedFilePath,
  });

  String get downloadedMb => (bytesDownloaded / (1024 * 1024)).toStringAsFixed(1);
  String get totalMb => (totalBytes > 0)
      ? (totalBytes / (1024 * 1024)).toStringAsFixed(1)
      : '?';
  int get percentage => (progress * 100).clamp(0, 100).toInt();
}

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
  final String? sha256;

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
    this.sha256,
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
      sha256: json['sha256']?.toString(),
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
      if (sha256 != null) 'sha256': sha256,
    };
  }
}

/// In-App Update Checker & Native Installer Service.
/// Communicates with an external manifest server or GitHub Releases API to check
/// for newer app builds, parse release notes, streams in-app APK downloads with
/// real-time progress, and launches native Android PackageInstaller automatically.
class AppUpdateService {
  AppUpdateService._internal();
  static final AppUpdateService instance = AppUpdateService._internal();

  static const MethodChannel _installerChannel =
      MethodChannel('com.veribite.app/apk_installer');

  /// Installed app version matching pubspec.yaml
  static const String currentVersion = '1.0.1';

  /// Installed build number matching pubspec.yaml
  static const int currentBuildNumber = 5;

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

  /// Streams in-app APK download with real-time progress, optional SHA-256 verification,
  /// and automatically triggers the native package installer when 100% complete.
  Stream<DownloadProgress> downloadAndInstallApk({
    required String apkUrl,
    String? expectedSha256,
  }) async* {
    yield const DownloadProgress(
      status: DownloadStatus.downloading,
      bytesDownloaded: 0,
      totalBytes: 0,
      progress: 0.0,
    );

    final client = http.Client();
    IOSink? sink;
    File? tempFile;

    try {
      final request = http.Request('GET', Uri.parse(apkUrl));
      request.headers['User-Agent'] = 'VeriBite-App-Updater/1.0';
      final response = await client.send(request);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        yield DownloadProgress(
          status: DownloadStatus.failed,
          errorMessage: 'Server returned HTTP ${response.statusCode}',
        );
        return;
      }

      final totalBytes = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      tempFile = File('${tempDir.path}/VeriBite-update.apk');
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      sink = tempFile.openWrite();
      int downloadedBytes = 0;
      int lastYieldMs = DateTime.now().millisecondsSinceEpoch;

      await for (final chunk in response.stream) {
        sink.add(chunk);
        downloadedBytes += chunk.length;

        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (nowMs - lastYieldMs >= 60 || (totalBytes > 0 && downloadedBytes >= totalBytes)) {
          lastYieldMs = nowMs;
          final fraction = totalBytes > 0
              ? (downloadedBytes / totalBytes).clamp(0.0, 1.0)
              : 0.0;
          yield DownloadProgress(
            status: DownloadStatus.downloading,
            bytesDownloaded: downloadedBytes,
            totalBytes: totalBytes,
            progress: fraction,
          );
        }
      }

      await sink.flush();
      await sink.close();
      sink = null;

      // Download complete
      yield DownloadProgress(
        status: DownloadStatus.downloading,
        bytesDownloaded: downloadedBytes,
        totalBytes: downloadedBytes,
        progress: 1.0,
      );

      // Verify SHA-256 integrity if specified
      if (expectedSha256 != null && expectedSha256.trim().isNotEmpty) {
        yield DownloadProgress(
          status: DownloadStatus.verifying,
          bytesDownloaded: downloadedBytes,
          totalBytes: downloadedBytes,
          progress: 1.0,
        );

        final digest = await crypto.sha256.bind(tempFile.openRead()).first;
        final actualHex = digest.toString().toLowerCase();
        final targetHex = expectedSha256.trim().toLowerCase();

        if (actualHex != targetHex) {
          yield DownloadProgress(
            status: DownloadStatus.failed,
            bytesDownloaded: downloadedBytes,
            totalBytes: downloadedBytes,
            progress: 1.0,
            errorMessage: 'Checksum mismatch. Downloaded file may be corrupted.',
          );
          return;
        }
      }

      // Automatically launch native PackageInstaller dialog
      yield DownloadProgress(
        status: DownloadStatus.readyToInstall,
        bytesDownloaded: downloadedBytes,
        totalBytes: downloadedBytes,
        progress: 1.0,
        downloadedFilePath: tempFile.path,
      );

      final installResult = await triggerNativeInstall(tempFile.path);
      if (installResult == 'NEEDS_PERMISSION') {
        yield DownloadProgress(
          status: DownloadStatus.needsPermission,
          bytesDownloaded: downloadedBytes,
          totalBytes: downloadedBytes,
          progress: 1.0,
          downloadedFilePath: tempFile.path,
        );
      } else {
        yield DownloadProgress(
          status: DownloadStatus.readyToInstall,
          bytesDownloaded: downloadedBytes,
          totalBytes: downloadedBytes,
          progress: 1.0,
          downloadedFilePath: tempFile.path,
        );
      }
    } catch (e) {
      if (sink != null) {
        try {
          await sink.close();
        } catch (_) {}
      }
      yield DownloadProgress(
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      );
    } finally {
      client.close();
    }
  }

  /// Check if the app has permission to install unknown apps (Android 8.0+)
  Future<bool> canRequestPackageInstalls() async {
    try {
      final res = await _installerChannel.invokeMethod<bool>('canRequestPackageInstalls');
      return res ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Trigger native package installer dialog for a downloaded APK path
  Future<String?> triggerNativeInstall(String filePath) async {
    try {
      final res = await _installerChannel.invokeMethod<String>(
        'installApk',
        {'filePath': filePath},
      );
      return res;
    } catch (e) {
      debugPrint('[AppUpdateService] triggerNativeInstall error: $e');
      return null;
    }
  }

  /// Open Android system "Allow from this source" settings for VeriBite
  Future<void> openUnknownSourcesSettings() async {
    try {
      await _installerChannel.invokeMethod('openUnknownSourcesSettings');
    } catch (e) {
      debugPrint('[AppUpdateService] openUnknownSourcesSettings error: $e');
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
