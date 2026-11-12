import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/app_update_service.dart';

/// Modal bottom sheet displaying update details, release notes, and download CTAs.
class UpdateAvailableBottomSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Container(
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
                  ...updateInfo.releaseNotes.map(
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

          // Primary Action: Download APK
          ElevatedButton.icon(
            onPressed: () {
              AppUpdateService.instance.launchUpdateUrl(updateInfo.apkDownloadUrl);
              if (!updateInfo.forceUpdate) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.download_rounded, size: 19),
            label: Text(
              'Download & Install Update (${updateInfo.apkSizeMb})',
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
          ),

          if (updateInfo.webpageUrl.isNotEmpty) ...[
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

          if (!updateInfo.forceUpdate) ...[
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
    );
  }
}

