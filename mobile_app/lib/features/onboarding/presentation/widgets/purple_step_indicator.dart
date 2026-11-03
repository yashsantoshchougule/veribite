import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

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
          height: 8.0,
          width: isActive ? 28.0 : 8.0,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primaryPurple : AppColors.lightPurple,
            borderRadius: BorderRadius.circular(4.0),
          ),
        );
      }),
    );
  }
}
