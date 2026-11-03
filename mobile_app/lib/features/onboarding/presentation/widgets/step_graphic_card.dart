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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightPurple, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryPurple.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Center(
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.center,
            child: _buildGraphicContent(context),
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
    return SizedBox(
      width: 360,
      height: 180,
      child: Container(
        color: const Color(0xFF1E142B),
        padding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Viewfinder box
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.accentViolet, width: 2),
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF2B1D3D),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.qr_code_scanner, size: 48, color: AppColors.lightPurple),
                    const SizedBox(height: 6),
                    const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Barcode & Nutrition Table',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppColors.primaryPurple, borderRadius: BorderRadius.circular(8)),
                      child: const Text('Offline Ready • < 20ms', style: TextStyle(color: Colors.white, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            ),
            // Horizontal scan laser
            Positioned(
              left: 10,
              right: 10,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: Colors.cyanAccent,
                  boxShadow: [BoxShadow(color: Colors.cyanAccent.withValues(alpha: 0.8), blurRadius: 6)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2Toxicology() {
    return SizedBox(
      width: 360,
      height: 180,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.safetyRedBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.safetyRed, width: 1.5),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock, size: 18, color: AppColors.safetyRed),
                    SizedBox(width: 6),
                    Text('39/100 Hard Red Cap Triggered', style: TextStyle(color: AppColors.safetyRed, fontWeight: FontWeight.bold, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7ED),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('🍬 Split-Sugar Cluster Detected (32% Share)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.deepOrange)),
                ),
                SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Sugar • Liquid Glucose • Invert Syrup • Maltodextrin', style: TextStyle(fontSize: 11, color: Colors.black87)),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.safetyRedBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.safetyRed),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'INS 110 Sunset Yellow: Banned in EU schools for hyperactivity.',
                    style: TextStyle(fontSize: 10, color: AppColors.safetyRed, fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3SafeDosage() {
    return SizedBox(
      width: 360,
      height: 180,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLavender,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primaryPurple),
                ),
                child: const Text(
                  '👤 Active Profile: Child (20kg) • Diabetic Guard',
                  style: TextStyle(color: AppColors.darkPurple, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EDF7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primaryPurple, width: 1.5),
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('SAFE SERVING CEILING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.darkPurple)),
                SizedBox(height: 2),
                Text('16 Grams (1 Piece)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.darkPurple)),
                Text('Schedule: Max 2-3 Times / Week (WHO Free Sugar Ceiling)', style: TextStyle(fontSize: 10, color: Colors.black54)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('Daily JECFA Chemical ADI Limit:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(value: 0.35, minHeight: 6, color: AppColors.safetyRed, backgroundColor: Colors.grey.shade200),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep4Swaps() {
    return SizedBox(
      width: 360,
      height: 180,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.safetyMintBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.safetyMint),
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
                      Text('Clean Swap: 100% Rolled Oats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.safetyMint)),
                      Text('Score 88/100 • 85% Less Sugar • 0 Additives', style: TextStyle(fontSize: 10, color: Colors.black87)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Text('1-Tap Quick Commerce Delivery:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.darkPurple)),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                _partnerBadge('Blinkit', Colors.amber.shade800),
                const SizedBox(width: 6),
                _partnerBadge('Zepto', Colors.purple.shade700),
                const SizedBox(width: 6),
                _partnerBadge('Instamart', Colors.deepOrange),
                const SizedBox(width: 6),
                _partnerBadge('BigBasket', Colors.red.shade700),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceLavender,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.smart_toy_outlined, size: 16, color: AppColors.primaryPurple),
                SizedBox(width: 6),
                Expanded(
                  child: Text('AI Advisor: Grounded in WHO & FSSAI verified citations.', style: TextStyle(fontSize: 10, color: AppColors.darkPurple)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _partnerBadge(String title, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
