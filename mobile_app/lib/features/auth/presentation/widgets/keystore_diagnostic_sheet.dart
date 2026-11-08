import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/config/oauth_config.dart';
import '../../../../core/theme/app_colors.dart';

/// Bottom sheet presented when native Google Sign-In encounters an unregistered
/// Android keystore fingerprint (ApiException: 10 / DEVELOPER_ERROR).
/// Provides full diagnostic fingerprints and a 1-tap "Continue with Instant Local Profile" fallback.
class KeystoreDiagnosticSheet extends StatelessWidget {
  final VoidCallback onContinueWithLocalProfile;
  final VoidCallback? onRetryBrowserOAuth;
  final String? rawError;

  const KeystoreDiagnosticSheet({
    super.key,
    required this.onContinueWithLocalProfile,
    this.onRetryBrowserOAuth,
    this.rawError,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onContinueWithLocalProfile,
    VoidCallback? onRetryBrowserOAuth,
    String? rawError,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => KeystoreDiagnosticSheet(
        onContinueWithLocalProfile: onContinueWithLocalProfile,
        onRetryBrowserOAuth: onRetryBrowserOAuth,
        rawError: rawError,
      ),
    );
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primaryObsidian,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1.5)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Warning Icon Header
            Center(
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.sugarPeachBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.sugarPeachBorder),
                ),
                child: const Icon(
                  Icons.vpn_key_rounded,
                  color: AppColors.sugarPeachText,
                  size: 32,
                ),
              ),
            ),
            const SizedBox(height: 16),

            const Text(
              'Google Sign-In Keystore Notice',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textObsidian,
              ),
            ),
            const SizedBox(height: 8),

            const Text(
              'Google Play Services blocked native sign-in (ApiException: 10) because this build is signed with a local debug keystore that is not yet registered in your Google Cloud Console.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textMutedMocha,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),

            // Fingerprint Box
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.canvasCream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder, width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHashRow(
                    context,
                    label: 'Package ID',
                    value: OAuthConfig.applicationId,
                  ),
                  const Divider(height: 16, color: AppColors.cardBorder),
                  _buildHashRow(
                    context,
                    label: 'SHA-1 Fingerprint',
                    value: OAuthConfig.debugSha1,
                  ),
                  const Divider(height: 16, color: AppColors.cardBorder),
                  _buildHashRow(
                    context,
                    label: 'SHA-256 Fingerprint',
                    value: OAuthConfig.debugSha256,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // Primary Action: Instant Local Profile
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                onContinueWithLocalProfile();
              },
              icon: const Icon(Icons.bolt_rounded, size: 20),
              label: const Text(
                'Continue with Instant Local Profile',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryObsidian,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),

            // Secondary Action: Retry Web OAuth (PKCE)
            if (onRetryBrowserOAuth != null) ...[
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onRetryBrowserOAuth!();
                },
                icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                label: const Text(
                  'Try Zero-Keystore Browser OAuth',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF4285F4),
                  side: const BorderSide(color: Color(0xFF4285F4), width: 1.2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 8),
            ],

            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancel & Return to Login',
                style: TextStyle(color: AppColors.textMutedMocha, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHashRow(
    BuildContext context, {
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMutedMocha,
                ),
              ),
              const SizedBox(height: 3),
              SelectableText(
                value,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                  color: AppColors.textObsidian,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.accentBronze),
          tooltip: 'Copy $label',
          onPressed: () => _copyToClipboard(context, value, label),
        ),
      ],
    );
  }
}
