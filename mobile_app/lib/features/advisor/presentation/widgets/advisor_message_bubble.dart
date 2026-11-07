import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/advisor_chat_model.dart';

/// Formatted message card for both user questions and AI advisor answers.
/// AI bubbles display official regulatory citation tags, safe portion badges,
/// and engine provenance pills (Gemini 2.5 Flash vs Offline Fallback) styled
/// with VeriBite's Warm Luxury Alabaster & Midnight Obsidian palette.
class AdvisorMessageBubble extends StatelessWidget {
  final ChatMessage message;
  final VoidCallback? onToggleSpeak;
  final bool isSpeaking;

  const AdvisorMessageBubble({
    super.key,
    required this.message,
    this.onToggleSpeak,
    this.isSpeaking = false,
  });

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return _buildUserBubble(context);
    }
    return _buildAdvisorBubble(context);
  }

  Widget _buildUserBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(left: 48, right: 16, top: 6, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primaryObsidian,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(color: AppColors.primaryObsidian),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8C7A6B).withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14.5,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildAdvisorBubble(BuildContext context) {
    final isGemini = message.source.startsWith('gemini');
    final isOffline = message.source == 'local_offline';

    final badgeLabel = isGemini
        ? 'Gemini 3.5 Flash • Live AI'
        : isOffline
            ? 'Offline Scientific Engine'
            : 'Rule-Based Evidence Fallback';

    final badgeColor = isGemini
        ? AppColors.safetyMint
        : isOffline
            ? AppColors.accentBronze
            : AppColors.textObsidian;

    final badgeBg = isGemini
        ? AppColors.safetyMintBg
        : isOffline
            ? AppColors.ceilingCardBg
            : AppColors.stepPillBg;

    final badgeBorder = isGemini
        ? AppColors.safetyMintBorder
        : isOffline
            ? AppColors.ceilingCardBorder
            : AppColors.stepPillBorder;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 36, top: 6, bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: AppColors.cardBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8C7A6B).withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Engine Header & Provenance Badge with zero layout overflow
            Row(
              children: [
                const Icon(
                  Icons.auto_awesome_rounded,
                  size: 16,
                  color: AppColors.safetyMint,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'VeriBite AI Advisor',
                    style: TextStyle(
                      color: AppColors.textObsidian,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: badgeBorder),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      color: badgeColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onToggleSpeak != null) ...[
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: onToggleSpeak,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isSpeaking ? AppColors.safetyMint : AppColors.stepPillBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSpeaking ? AppColors.safetyMintBorder : AppColors.stepPillBorder,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isSpeaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                            size: 12,
                            color: isSpeaking ? Colors.white : AppColors.textObsidian,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isSpeaking ? 'Stop' : 'Listen',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isSpeaking ? Colors.white : AppColors.textObsidian,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),

            // Message Body Text (Crisp Obsidian on Ivory Surface)
            Text(
              message.text,
              style: const TextStyle(
                color: AppColors.textObsidian,
                fontSize: 14,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),

            // Safe Dosage & Schedule Card (if available)
            if (message.safePortionGrams != null || message.frequencySchedule != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.ceilingCardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.ceilingCardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined, size: 20, color: AppColors.accentBronze),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (message.safePortionGrams != null)
                            Text(
                              'Prescribed Safe Portion: ${message.safePortionGrams!.toStringAsFixed(0)}g',
                              style: const TextStyle(
                                color: AppColors.textObsidian,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          if (message.frequencySchedule != null)
                            Text(
                              'Schedule: ${message.frequencySchedule}',
                              style: const TextStyle(
                                color: AppColors.textMutedMocha,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Verified Citation Pills
            if (message.citations.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(color: AppColors.cardBorder, height: 1),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_outlined, size: 14, color: AppColors.safetyMint),
                  const SizedBox(width: 6),
                  const Text(
                    'Scientific Groundings: ',
                    style: TextStyle(
                      color: AppColors.textMutedMocha,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: message.citations.map((citation) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppColors.stepPillBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.stepPillBorder),
                          ),
                          child: Text(
                            citation,
                            style: const TextStyle(
                              color: AppColors.textObsidian,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
