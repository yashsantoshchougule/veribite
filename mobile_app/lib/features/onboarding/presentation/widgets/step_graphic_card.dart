import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/responsive_layout.dart';

class StepGraphicCard extends StatelessWidget {
  final int stepNumber;

  const StepGraphicCard({super.key, required this.stepNumber});

  @override
  Widget build(BuildContext context) {
    final height = ResponsiveLayout.graphicHeight(context);

    return Container(
      height: height,
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8C7A6B).withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: SizedBox(
              width: 360,
              height: 195,
              child: _buildGraphicContent(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGraphicContent(BuildContext context) {
    switch (stepNumber) {
      case 1:
        return _buildStep1Scanner();
      case 2:
        return _buildStep2Toxicology();
      case 3:
        return _buildStep3SafeDosage();
      case 4:
      default:
        return _buildStep4Swaps();
    }
  }

  Widget _buildStep1Scanner() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF7F2EC),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: Container(
          width: 320,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.cardBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Reticle bracket accents
              Positioned(top: 0, left: 0, child: _reticleCorner(top: true, left: true)),
              Positioned(top: 0, right: 0, child: _reticleCorner(top: true, left: false)),
              Positioned(bottom: 0, left: 0, child: _reticleCorner(top: false, left: true)),
              Positioned(bottom: 0, right: 0, child: _reticleCorner(top: false, left: false)),

              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.qr_code_scanner_rounded, size: 44, color: AppColors.textObsidian),
                  const SizedBox(height: 8),
                  // Cyan laser scan line
                  Container(
                    height: 2.2,
                    width: 250,
                    decoration: BoxDecoration(
                      color: AppColors.scanLaserCyan,
                      borderRadius: BorderRadius.circular(2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.scanLaserCyan.withValues(alpha: 0.8),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Barcode & Nutrition Table',
                    style: TextStyle(
                      color: AppColors.textObsidian,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEDE4F7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD3BDEB), width: 1),
                    ),
                    child: const Text(
                      'Offline Ready • < 20ms',
                      style: TextStyle(
                        color: Color(0xFF5E35B1),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reticleCorner({required bool top, required bool left}) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        border: Border(
          top: top ? const BorderSide(color: AppColors.scanBracketGold, width: 2) : BorderSide.none,
          bottom: !top ? const BorderSide(color: AppColors.scanBracketGold, width: 2) : BorderSide.none,
          left: left ? const BorderSide(color: AppColors.scanBracketGold, width: 2) : BorderSide.none,
          right: !left ? const BorderSide(color: AppColors.scanBracketGold, width: 2) : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildStep2Toxicology() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 39/100 Hard Red Cap Pill
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.safetyRedBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.safetyRedBorder, width: 1.2),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 17, color: AppColors.safetyRed),
                  SizedBox(width: 6),
                  Text(
                    '39/100 Hard Red Cap Triggered',
                    style: TextStyle(
                      color: AppColors.safetyRed,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Split Sugar Cluster Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.sugarPeachBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.sugarPeachBorder, width: 1.2),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  children: [
                    Text('🍬 ', style: TextStyle(fontSize: 13)),
                    Text(
                      'Split-Sugar Cluster Detected (32% Share)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: AppColors.sugarPeachText,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Sugar • Liquid Glucose • Invert Syrup • Maltodextrin',
                  style: TextStyle(fontSize: 11, color: AppColors.textMutedMocha),
                ),
              ),
            ],
          ),
        ),

        // Additive Warning Pill
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.safetyRedBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.safetyRedBorder, width: 1.2),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 17, color: AppColors.safetyRed),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'INS 110 Sunset Yellow: Banned in EU schools for hyperactivity.',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.safetyRed,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3SafeDosage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Active Profile Pill
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.profilePillBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.profilePillBorder, width: 1.2),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_rounded, size: 16, color: Color(0xFF1E88E5)),
                  SizedBox(width: 6),
                  Text(
                    'Active Profile: Child (20kg) • Diabetic Guard',
                    style: TextStyle(
                      color: AppColors.textObsidian,
                      fontWeight: FontWeight.bold,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Central Gold Ceiling Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: AppColors.ceilingCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.ceilingCardBorder, width: 1.4),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SAFE SERVING CEILING',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: AppColors.ceilingGoldText,
                ),
              ),
              SizedBox(height: 2),
              Text(
                '16 Grams (1 Piece)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'serif',
                  color: AppColors.textObsidian,
                ),
              ),
              Text(
                'Schedule: Max 2-3 Times / Week (WHO Free Sugar Ceiling)',
                style: TextStyle(fontSize: 10, color: AppColors.textMutedMocha),
              ),
            ],
          ),
        ),

        // Daily JECFA Limit Progress
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                'Daily JECFA Chemical ADI Limit:',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textObsidian,
                ),
              ),
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                value: 0.35,
                minHeight: 6,
                color: Color(0xFF8B0000),
                backgroundColor: AppColors.progressTrack,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep4Swaps() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clean Swap Pill
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.safetyMintBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.safetyMintBorder, width: 1.2),
          ),
          child: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.safetyMint, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Clean Swap: 100% Rolled Oats',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 11.5,
                        color: AppColors.safetyMint,
                      ),
                    ),
                    Text(
                      'Score 88/100 • 85% Less Sugar • 0 Additives',
                      style: TextStyle(fontSize: 10.5, color: Color(0xFF2E3A2F)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const Text(
          '1-Tap Quick Commerce Delivery:',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.bold,
            color: AppColors.textObsidian,
          ),
        ),

        // Quick Commerce Brand Badges
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            children: [
              _partnerBadge('Blinkit', const Color(0xFFF4B400)),
              const SizedBox(width: 6),
              _partnerBadge('Zepto', const Color(0xFF7B1FA2)),
              const SizedBox(width: 6),
              _partnerBadge('Instamart', const Color(0xFFE65100)),
              const SizedBox(width: 6),
              _partnerBadge('BigBasket', const Color(0xFFC62828)),
            ],
          ),
        ),

        // AI Advisor Pill
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.aiAdvisorBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.smart_toy_outlined, size: 16, color: AppColors.aiAdvisorText),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'AI Advisor: Grounded in WHO & FSSAI verified citations.',
                  style: TextStyle(fontSize: 10.5, color: AppColors.aiAdvisorText),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _partnerBadge(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
