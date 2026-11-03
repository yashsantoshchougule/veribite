import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class WalkthroughNavBar extends StatelessWidget {
  final int currentIndex;
  final int totalSteps;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onFinish;

  const WalkthroughNavBar({
    super.key,
    required this.currentIndex,
    this.totalSteps = 4,
    required this.onNext,
    required this.onBack,
    required this.onFinish,
  });

  @override
  Widget build(BuildContext context) {
    final isLastStep = currentIndex == totalSteps - 1;

    // Step 1: Full-width Next Step button
    if (currentIndex == 0) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryObsidian,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 2,
          ),
          onPressed: onNext,
          child: const Center(
            child: Text(
              'Next Step →',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.2),
            ),
          ),
        ),
      );
    }

    // Steps 2, 3, 4: Split Bar (Back on Left, Next / Finish on Right)
    return Row(
      children: [
        // Back Button
        Expanded(
          flex: 4,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              backgroundColor: AppColors.backButtonBg,
              foregroundColor: AppColors.backButtonText,
              side: const BorderSide(color: AppColors.backButtonBorder, width: 1.2),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: onBack,
            child: const Text(
              '← Back',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Forward Button
        Expanded(
          flex: 6,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryObsidian,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
            ),
            onPressed: isLastStep ? onFinish : onNext,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  isLastStep ? 'Get Started & Sign In →' : 'Next Step →',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.2),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
