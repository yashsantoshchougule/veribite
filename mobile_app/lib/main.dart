import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/application/supabase_auth_service.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/onboarding/presentation/starter_walkthrough_screen.dart';
import 'features/profile/application/user_profile_service.dart';
import 'features/profile/presentation/user_details_screen.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Cloud Authentication if credentials configured
  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.supabaseUrl,
        anonKey: SupabaseConfig.supabaseAnonKey,
      );

      // Listen for OAuth deep link callback (Google Sign-In)
      Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (data.event == AuthChangeEvent.signedIn) {
          final navContext = rootNavigatorKey.currentContext;
          if (navContext != null) {
            ScannerApp._navigatePostAuth(navContext, userId: data.session?.user.id);
          }
        }
      });
    } catch (e) {
      debugPrint('Supabase initialization notice: $e');
    }
  }

  runApp(const ProviderScope(child: ScannerApp()));
}

class ScannerApp extends StatelessWidget {
  const ScannerApp({super.key});

  static Future<void> _navigatePostAuth(BuildContext context, {String? userId}) async {
    final uid = userId ?? SupabaseAuthService().currentUser?.id ?? 'local_user';
    final profileService = UserProfileService();
    final hasCompleted = await profileService.hasCompletedProfile(uid);

    if (!context.mounted) return;

    if (hasCompleted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => HomeScreen(userId: uid),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => UserDetailsScreen(
            userId: uid,
            onComplete: () {
              if (context.mounted) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => HomeScreen(userId: uid),
                  ),
                );
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'VeriBite Safe Consumption Scanner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: AppColors.primaryObsidian,
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.canvasCream,
      ),
      home: const AppStartupGate(),
    );
  }
}

/// Dynamic Startup Gate: Handles Cold Boot Session Routing & Skip-Retry Lifecycle
class AppStartupGate extends StatelessWidget {
  const AppStartupGate({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = SupabaseAuthService();
    final user = authService.currentUser;

    // 1. If no user is logged in, boot to Starter Walkthrough
    if (user == null) {
      return _buildWalkthrough(context);
    }

    // 2. If authenticated session exists, evaluate profile completion lifecycle
    return FutureBuilder<bool>(
      future: UserProfileService().hasCompletedProfile(user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: AppColors.canvasCream,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryObsidian),
              ),
            ),
          );
        }

        final hasCompleted = snapshot.data ?? false;
        if (hasCompleted) {
          // Profile previously filled and saved -> Straight to Dashboard
          return HomeScreen(userId: user.id);
        } else {
          // User skipped previously and cut app -> Prompt User Details again until filled
          return UserDetailsScreen(
            userId: user.id,
            onComplete: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => HomeScreen(userId: user.id),
                ),
              );
            },
          );
        }
      },
    );
  }

  static Widget _buildWalkthrough(BuildContext context) {
    return StarterWalkthroughScreen(
      onFinish: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LoginScreen(
              onLoginSubmit: (usernameOrEmail, password) async {
                try {
                  final authService = SupabaseAuthService();
                  String? uid;
                  if (authService.isAvailable) {
                    final res = await authService.signInWithEmail(
                      email: usernameOrEmail,
                      password: password,
                    );
                    uid = res.user?.id;
                  }
                  if (context.mounted) {
                    await ScannerApp._navigatePostAuth(context, userId: uid);
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
                  String? uid;
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
                    uid = res.user?.id;
                  }
                  if (context.mounted) {
                    await ScannerApp._navigatePostAuth(context, userId: uid);
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
                      await ScannerApp._navigatePostAuth(context);
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
              onContinueWithCredential: (credential) async {
                await ScannerApp._navigatePostAuth(context);
              },
            ),
          ),
        );
      },
    );
  }
}
