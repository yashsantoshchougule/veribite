import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Luxury Walkthrough Step Indicator with Elongated Active Pill and Soft Inactive Dots
class PurpleStepIndicator extends StatelessWidget {
  final int activeIndex;
  final int totalSteps;

  const PurpleStepIndicator({
    super.key,
    required this.activeIndex,
    this.totalSteps = 4,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (index) {
        final isActive = index == activeIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          height: 6.0,
          width: isActive ? 28.0 : 6.0,
          decoration: BoxDecoration(
            color: isActive ? AppColors.activeDotNavy : AppColors.inactiveDot,
            borderRadius: BorderRadius.circular(3.0),
          ),
        );
      }),
    );
  }
}
