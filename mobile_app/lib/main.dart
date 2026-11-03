import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/application/supabase_auth_service.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/camera/presentation/smart_camera_screen.dart';
import 'features/onboarding/presentation/starter_walkthrough_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Cloud Authentication if credentials configured
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('Supabase initialization notice: $e');
    }
  }

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
                  onLoginSubmit: (usernameOrEmail, password) async {
                    try {
                      final authService = SupabaseAuthService();
                      if (authService.isAvailable) {
                        await authService.signInWithEmail(
                          email: usernameOrEmail,
                          password: password,
                        );
                      }
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const SmartCameraScreen(),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              e is AuthException ? e.message : 'Login failed: $e',
                            ),
                            backgroundColor: AppColors.safetyRed,
                          ),
                        );
                      }
                    }
                  },
                  onSignInSubmit: (name, username, email, password) async {
                    try {
                      final authService = SupabaseAuthService();
                      if (authService.isAvailable) {
                        final res = await authService.signUp(
                          fullName: name,
                          username: username,
                          email: email,
                          password: password,
                        );
                        if (context.mounted) {
                          if (res.session == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Registration successful! Please check your Gmail to confirm your account.',
                                ),
                                backgroundColor: AppColors.loginBrandPurple,
                              ),
                            );
                            return;
                          }
                        }
                      }
                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const SmartCameraScreen(),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              e is AuthException ? e.message : 'Registration failed: $e',
                            ),
                            backgroundColor: AppColors.safetyRed,
                          ),
                        );
                      }
                    }
                  },
                  onForgotPassword: (email) async {
                    try {
                      final authService = SupabaseAuthService();
                      if (authService.isAvailable) {
                        await authService.resetPasswordForEmail(email);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              e is AuthException ? e.message : 'Reset failed: $e',
                            ),
                            backgroundColor: AppColors.safetyRed,
                          ),
                        );
                      }
                    }
                  },
                  onGoogleSignIn: () async {
                    try {
                      final authService = SupabaseAuthService();
                      if (authService.isAvailable) {
                        await authService.signInWithGoogle();
                      } else {
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) => const SmartCameraScreen(),
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Google Sign-In notice: $e'),
                            backgroundColor: AppColors.loginBrandPurple,
                          ),
                        );
                      }
                    }
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
