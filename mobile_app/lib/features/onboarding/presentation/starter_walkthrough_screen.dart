import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/responsive_layout.dart';
import '../domain/walkthrough_step.dart';
import 'widgets/purple_step_indicator.dart';
import 'widgets/step_graphic_card.dart';
import 'widgets/walkthrough_nav_bar.dart';

class StarterWalkthroughScreen extends StatefulWidget {
  final VoidCallback? onFinish;

  const StarterWalkthroughScreen({super.key, this.onFinish});

  @override
  State<StarterWalkthroughScreen> createState() => _StarterWalkthroughScreenState();
}

class _StarterWalkthroughScreenState extends State<StarterWalkthroughScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final List<WalkthroughStep> _steps = WalkthroughStep.defaultSteps;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _skipToLast() {
    _pageController.animateToPage(
      _steps.length - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveLayout.horizontalPadding(context);
    final isSmall = ResponsiveLayout.isSmallPhone(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceLavender,
      body: SafeArea(
        child: ResponsiveLayout.constrainedContainer(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padding, vertical: isSmall ? 8.0 : 16.0),
            child: Column(
              children: [
                // Top App Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.shield_outlined, color: AppColors.darkPurple, size: 24),
                          SizedBox(width: 6),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'NutriGuard',
                                style: TextStyle(
                                  color: AppColors.darkPurple,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_currentPage < _steps.length - 1)
                      TextButton(
                        onPressed: _skipToLast,
                        style: TextButton.styleFrom(
                          minimumSize: Size.zero,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: AppColors.primaryPurple,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 32),
                  ],
                ),
                const SizedBox(height: 12),

                // Carousel Body
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: _steps.length,
                    onPageChanged: (idx) => setState(() => _currentPage = idx),
                    itemBuilder: (context, index) {
                      final step = _steps[index];
                      return SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 8),
                            StepGraphicCard(stepNumber: step.stepNumber),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.lightPurple,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'STEP ${step.stepNumber} OF ${_steps.length}',
                                style: const TextStyle(
                                  color: AppColors.darkPurple,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              step.title,
                              style: TextStyle(
                                color: AppColors.textDark,
                                fontWeight: FontWeight.bold,
                                fontSize: isSmall ? 20 : 24,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              step.subtitle,
                              style: TextStyle(
                                color: AppColors.textMuted,
                                fontSize: isSmall ? 13 : 15,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 12),
                PurpleStepIndicator(activeIndex: _currentPage, totalSteps: _steps.length),
                const SizedBox(height: 16),

                // Bottom Nav Buttons
                WalkthroughNavBar(
                  currentIndex: _currentPage,
                  totalSteps: _steps.length,
                  onNext: _nextPage,
                  onBack: _previousPage,
                  onFinish: () {
                    if (widget.onFinish != null) {
                      widget.onFinish!();
                    }
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
