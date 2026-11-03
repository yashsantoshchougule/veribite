import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_colors.dart';
import 'features/onboarding/presentation/starter_walkthrough_screen.dart';

void main() {
  runApp(const ProviderScope(child: ScannerApp()));
}

class ScannerApp extends StatelessWidget {
  const ScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NutriGuard Safe Consumption Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: AppColors.primaryPurple,
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.surfaceLavender,
      ),
      home: StarterWalkthroughScreen(
        onFinish: () {
          // Navigates to Login / Authentication or Dashboard screen
        },
      ),
    );
  }
}
