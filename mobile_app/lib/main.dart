import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/camera/presentation/smart_camera_screen.dart';
import 'features/onboarding/presentation/starter_walkthrough_screen.dart';

void main() {
  runApp(const ProviderScope(child: ScannerApp()));
}

class ScannerApp extends StatelessWidget {
  const ScannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VeriBite Safe Consumption Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: AppColors.primaryObsidian,
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.canvasCream,
      ),
      home: Builder(
        builder: (context) => StarterWalkthroughScreen(
          onFinish: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LoginScreen(
                  onGoogleSignIn: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const SmartCameraScreen(),
                      ),
                    );
                  },
                  onContinueWithCredential: (credential) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const SmartCameraScreen(),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
