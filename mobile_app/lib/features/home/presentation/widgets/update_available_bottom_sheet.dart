import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/app_update_service.dart';

/// Modal bottom sheet displaying update details, release notes, live reactive
/// 0% -> 100% download progress, and automatic native installer launch.
class UpdateAvailableBottomSheet extends StatefulWidget {
  final AppUpdateInfo updateInfo;

  const UpdateAvailableBottomSheet({
    super.key,
    required this.updateInfo,
  });

  /// Presents the update modal sheet.
  static Future<void> show(BuildContext context, AppUpdateInfo updateInfo) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !updateInfo.forceUpdate,
      enableDrag: !updateInfo.forceUpdate,
      backgroundColor: Colors.transparent,
      builder: (_) => UpdateAvailableBottomSheet(updateInfo: updateInfo),
    );
  }

  @override
  State<UpdateAvailableBottomSheet> createState() => _UpdateAvailableBottomSheetState();
}

class _UpdateAvailableBottomSheetState extends State<UpdateAvailableBottomSheet> {
  StreamSubscription<DownloadProgress>? _downloadSub;
  DownloadProgress? _currentProgress;

  bool get _isDownloading =>
      _currentProgress != null &&
      (_currentProgress!.status == DownloadStatus.downloading ||
          _currentProgress!.status == DownloadStatus.verifying);

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }

  void _startDownload() {
    setState(() {
      _currentProgress = const DownloadProgress(
        status: DownloadStatus.downloading,
        progress: 0.0,
      );
    });

    _downloadSub?.cancel();
    _downloadSub = AppUpdateService.instance
        .downloadAndInstallApk(
          apkUrl: widget.updateInfo.apkDownloadUrl,
          expectedSha256: widget.updateInfo.sha256,
        )
        .listen(
          (progress) {
            if (mounted) {
              setState(() {
                _currentProgress = progress;
              });
            }
          },
          onError: (err) {
            if (mounted) {
              setState(() {
                _currentProgress = DownloadProgress(
                  status: DownloadStatus.failed,
                  errorMessage: err.toString(),
                );
              });
            }
          },
        );
  }

  void _cancelDownload() {
    _downloadSub?.cancel();
    _downloadSub = null;
    setState(() {
      _currentProgress = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final updateInfo = widget.updateInfo;

    return PopScope(
      canPop: !_isDownloading && !updateInfo.forceUpdate,
      child: Container(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(context).padding.bottom + 20,
        ),
        decoration: const BoxDecoration(
          color: AppColors.canvasCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x28000000),
              blurRadius: 20,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header with icon and version tag
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.accentBronze.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.accentBronze.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    color: AppColors.accentBronze,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              updateInfo.forceUpdate
                                  ? 'Critical Update Required'
                                  : 'Update Available',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textObsidian,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.safetyGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.safetyGreen.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              'v${updateInfo.latestVersion}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.safetyGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Build #${updateInfo.latestBuildNumber} • ${updateInfo.apkSizeMb}${updateInfo.releaseDate.isNotEmpty ? ' • ${updateInfo.releaseDate}' : ''}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textMutedMocha,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 18),

            // Release Notes Container
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.cardBorder, width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: AppColors.accentBronze,
                      ),
                      SizedBox(width: 8),
                      Text(
                        "What's New in this Version",
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textObsidian,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (updateInfo.releaseNotes.isEmpty)
                    const Text(
                      '• General performance improvements and bug fixes.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textMutedMocha,
                        height: 1.4,
                      ),
                    )
                  else
                    ...updateInfo.releaseNotes.take(5).map(
                      (note) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 4, right: 8),
                              child: Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: AppColors.safetyGreen,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                note,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: AppColors.textObsidian,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 18),

            // Reactive Action Panel (Download CTA, Streaming Progress, or Installer Triggers)
            _buildActionSection(),

            if (updateInfo.webpageUrl.isNotEmpty && !_isDownloading) ...[
              const SizedBox(height: 8),
              // Secondary Action: Open Webpage
              OutlinedButton.icon(
                onPressed: () {
                  AppUpdateService.instance.launchUpdateUrl(updateInfo.webpageUrl);
                },
                icon: const Icon(Icons.open_in_browser_rounded, size: 17, color: AppColors.accentBronze),
                label: const Text(
                  'Visit Download Webpage',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textObsidian,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ],

            if (!updateInfo.forceUpdate && !_isDownloading) ...[
              const SizedBox(height: 6),
              TextButton(
                onPressed: () {
                  AppUpdateService.instance.dismissVersion(updateInfo.latestVersion);
                  Navigator.of(context).pop();
                },
                child: const Text(
                  'Remind Me Later',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMutedMocha,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionSection() {
    final progress = _currentProgress;

    // 1. Idle state -> Big primary download button
    if (progress == null || progress.status == DownloadStatus.idle) {
      return ElevatedButton.icon(
        onPressed: _startDownload,
        icon: const Icon(Icons.download_rounded, size: 19),
        label: Text(
          'Download & Install Update (${widget.updateInfo.apkSizeMb})',
          style: const TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryObsidian,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      );
    }

    // 2. Active Downloading state -> 0% -> 100% Progress Bar + MB Counters
    if (progress.status == DownloadStatus.downloading) {
      final totalMbStr = progress.totalBytes > 0
          ? progress.totalMb
          : widget.updateInfo.apkSizeMb.replaceAll(' MB', '');

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder, width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentBronze),
                        value: progress.progress > 0 ? progress.progress : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Downloading update...',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textObsidian,
                      ),
                    ),
                  ],
                ),
                Text(
                  '${progress.percentage}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentBronze,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.progress > 0 ? progress.progress : null,
                minHeight: 8,
                backgroundColor: AppColors.cardBorder.withValues(alpha: 0.6),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accentBronze),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${progress.downloadedMb} MB / $totalMbStr MB',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMutedMocha,
                  ),
                ),
                GestureDetector(
                  onTap: _cancelDownload,
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // 3. Verifying Checksum state
    if (progress.status == DownloadStatus.verifying) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.cardBorder, width: 1.0),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.safetyGreen),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Verifying package integrity (SHA-256)...',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textObsidian,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 4. Ready To Install / Opening installer state
    if (progress.status == DownloadStatus.readyToInstall) {
      final path = progress.downloadedFilePath;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.safetyGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.safetyGreen.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.safetyGreen, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Download complete! Launching package installer...',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.safetyGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (path != null) ...[
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                AppUpdateService.instance.triggerNativeInstall(path);
              },
              icon: const Icon(Icons.install_mobile_rounded, size: 18),
              label: const Text(
                'Tap to Open Installer Again',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryObsidian,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ],
      );
    }

    // 5. Needs Permission state ("Install unknown apps")
    if (progress.status == DownloadStatus.needsPermission) {
      final path = progress.downloadedFilePath;
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7ED),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFDBA74), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.security_update_good_rounded, color: Color(0xFFEA580C), size: 22),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Permission Required to Update',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF9A3412),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Android requires "Allow from this source" permission to update directly. Toggle it ON and the installer will pop up automatically.',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF7C2D12),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: () {
                if (path != null) {
                  // This triggers Android unknown sources settings directly for VeriBite
                  AppUpdateService.instance.triggerNativeInstall(path);
                } else {
                  AppUpdateService.instance.openUnknownSourcesSettings();
                }
              },
              icon: const Icon(Icons.settings_suggest_rounded, size: 18),
              label: const Text(
                'Allow from this Source & Install',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEA580C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      );
    }

    // 6. Download / Verification Failure state
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text(
                'Download Failed',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            progress.errorMessage ?? 'An error occurred while downloading the update.',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF7F1D1D),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _startDownload,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    AppUpdateService.instance.launchUpdateUrl(widget.updateInfo.apkDownloadUrl);
                  },
                  icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                  label: const Text('Browser'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    foregroundColor: const Color(0xFF7F1D1D),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
