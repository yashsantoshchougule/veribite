import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../onboarding/presentation/widgets/watermark_painter.dart';
import 'widgets/google_logo_icon.dart';
import 'widgets/login_feature_chip.dart';

/// Production-ready VeriBite Authentication Screen supporting dual sliding
/// sections: Login (2 fields + forgot password) and Sign-In (5 fields).
/// Styled in the Warm Luxury Alabaster & Midnight Obsidian editorial aesthetic
/// with butter-smooth sliding transitions and synchronized tab pill navigation.
class LoginScreen extends StatefulWidget {
  final VoidCallback? onGoogleSignIn;
  final ValueChanged<String>? onContinueWithCredential;
  final Function(String username, String password)? onLoginSubmit;
  final Function(String name, String username, String email, String password)? onSignInSubmit;
  final ValueChanged<String>? onForgotPassword;
  final VoidCallback? onSkipOrGuest;

  const LoginScreen({
    super.key,
    this.onGoogleSignIn,
    this.onContinueWithCredential,
    this.onLoginSubmit,
    this.onSignInSubmit,
    this.onForgotPassword,
    this.onSkipOrGuest,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  // Active Tab: 0 = Login, 1 = Sign In
  int _activeTabIndex = 0;
  double _horizontalDragAccumulator = 0;

  // Animation controller for butter-smooth sliding transitions
  late final AnimationController _slideController;
  late final Animation<double> _slideAnimation;

  // Login Form Controllers
  final TextEditingController _loginUsernameController = TextEditingController();
  final TextEditingController _loginPasswordController = TextEditingController();
  bool _obscureLoginPassword = true;
  String? _loginErrorMessage;

  // Sign-In (Registration) 5-Field Controllers
  final TextEditingController _signNameController = TextEditingController();
  final TextEditingController _signUsernameController = TextEditingController();
  final TextEditingController _signEmailController = TextEditingController();
  final TextEditingController _signPasswordController = TextEditingController();
  final TextEditingController _signConfirmPasswordController = TextEditingController();
  bool _obscureSignPassword = true;
  bool _obscureSignConfirmPassword = true;
  String? _signErrorMessage;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _slideController.dispose();
    _loginUsernameController.dispose();
    _loginPasswordController.dispose();
    _signNameController.dispose();
    _signUsernameController.dispose();
    _signEmailController.dispose();
    _signPasswordController.dispose();
    _signConfirmPasswordController.dispose();
    super.dispose();
  }

  void _switchToTab(int index) {
    if (_activeTabIndex != index) {
      setState(() {
        _activeTabIndex = index;
        _loginErrorMessage = null;
        _signErrorMessage = null;
      });
      if (index == 1) {
        _slideController.forward();
      } else {
        _slideController.reverse();
      }
    }
  }

  void _handleLogin() {
    setState(() {
      _loginErrorMessage = null;
    });

    final username = _loginUsernameController.text.trim();
    final password = _loginPasswordController.text;

    if (username.isEmpty) {
      setState(() {
        _loginErrorMessage = 'Please enter your username or email';
      });
      return;
    }

    if (password.isEmpty) {
      setState(() {
        _loginErrorMessage = 'Please enter your password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (widget.onLoginSubmit != null) {
      widget.onLoginSubmit!(username, password);
    } else if (widget.onContinueWithCredential != null) {
      widget.onContinueWithCredential!(username);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logging in as $username...'),
          backgroundColor: AppColors.primaryObsidian,
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _handleSignIn() {
    setState(() {
      _signErrorMessage = null;
    });

    final name = _signNameController.text.trim();
    final username = _signUsernameController.text.trim();
    final email = _signEmailController.text.trim();
    final password = _signPasswordController.text;
    final confirmPassword = _signConfirmPasswordController.text;

    if (name.isEmpty) {
      setState(() {
        _signErrorMessage = 'Please enter your full name';
      });
      return;
    }

    if (username.isEmpty) {
      setState(() {
        _signErrorMessage = 'Please choose a username';
      });
      return;
    }

    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      setState(() {
        _signErrorMessage = 'Please enter a valid Gmail / email address';
      });
      return;
    }

    if (password.isEmpty || password.length < 6) {
      setState(() {
        _signErrorMessage = 'Password must be at least 6 characters';
      });
      return;
    }

    if (password != confirmPassword) {
      setState(() {
        _signErrorMessage = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (widget.onSignInSubmit != null) {
      widget.onSignInSubmit!(name, username, email, password);
    } else if (widget.onContinueWithCredential != null) {
      widget.onContinueWithCredential!(email);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Account created successfully for $username!'),
          backgroundColor: AppColors.primaryObsidian,
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _showForgotPasswordSheet() {
    final resetEmailController = TextEditingController(
      text: _loginUsernameController.text.contains('@')
          ? _loginUsernameController.text.trim()
          : '',
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.canvasCream,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: AppColors.cardBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8C7A6B).withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Reset Password',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textObsidian,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Enter your Gmail address to receive a secure password reset link.',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textMutedMocha,
                ),
              ),
              const SizedBox(height: 16),
              _buildInputField(
                controller: resetEmailController,
                hintText: 'Enter your Gmail address',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline_rounded,
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final email = resetEmailController.text.trim();
                    if (email.isEmpty || !email.contains('@')) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter a valid Gmail address'),
                          backgroundColor: AppColors.safetyRed,
                        ),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop();
                    if (widget.onForgotPassword != null) {
                      widget.onForgotPassword!(email);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Password reset link sent to $email'),
                        backgroundColor: AppColors.primaryObsidian,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryObsidian,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Send Reset Link via Gmail',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _handleGoogleSignIn() {
    if (widget.onGoogleSignIn != null) {
      widget.onGoogleSignIn!();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connecting with Google...'),
          backgroundColor: AppColors.primaryObsidian,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      body: CustomPaint(
        painter: const WatermarkPainter(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset + 16 : 24),
            physics: const ClampingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Header Card with Brand Logo & Feature Badges
                _buildTopHeaderArea(),

                const SizedBox(height: 24),

                // Middle Auth Area with Swipe Gesture Detection
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: GestureDetector(
                    onHorizontalDragStart: (_) {
                      _horizontalDragAccumulator = 0;
                    },
                    onHorizontalDragUpdate: (details) {
                      _horizontalDragAccumulator += details.primaryDelta ?? 0;
                    },
                    onHorizontalDragEnd: (details) {
                      final velocity = details.primaryVelocity ?? 0;
                      if ((_horizontalDragAccumulator < -40 || velocity < -120) && _activeTabIndex == 0) {
                        // Swiped Left -> Move to Sign In
                        _switchToTab(1);
                      } else if ((_horizontalDragAccumulator > 40 || velocity > 120) && _activeTabIndex == 1) {
                        // Swiped Right -> Move to Login
                        _switchToTab(0);
                      }
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Column(
                      children: [
                        // "Welcome to VeriBite" Heading
                        const Text(
                          'Welcome to VeriBite',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textObsidian,
                            letterSpacing: -0.4,
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Animated Dual Tab Selector [ Login | Sign In ] with Sliding Indicator
                        _buildTabSelector(),

                        const SizedBox(height: 22),

                        // Butter-Smooth Sliding Form Carousel
                        _buildSlidingFormArea(),

                        const SizedBox(height: 28),

                        // Legal Terms & Privacy Footer
                        _buildFooterDisclaimer(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Full-bleed squircle app logo tile matching starter palette
  Widget _buildAppLogoTile() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8C7A6B).withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Image.asset(
          'assets/images/app_logo.png',
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.primaryObsidian,
            child: const Icon(
              Icons.eco_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
        ),
      ),
    );
  }

  // Top header with warm luxury card surface, logo, headline, and 2 value chips
  Widget _buildTopHeaderArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 24, bottom: 26, left: 16, right: 16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        border: Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8C7A6B).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildAppLogoTile(),

          const SizedBox(height: 18),

          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Join 1 million+ smart consumers',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22.5,
                fontWeight: FontWeight.w800,
                color: AppColors.textObsidian,
                letterSpacing: -0.4,
              ),
            ),
          ),

          const SizedBox(height: 6),

          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Scan smarter. Choose wiser.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.accentBronze,
                letterSpacing: -0.1,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // 2 Value Chips: Personalized insights & Instant results
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              LoginFeatureChip(
                icon: Icons.shield_outlined,
                label: 'Personalized insights',
              ),
              LoginFeatureChip(
                icon: Icons.bolt_rounded,
                label: 'Instant results',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Tab bar switcher [ Login | Sign In ] with physically sliding Midnight Obsidian indicator
  Widget _buildTabSelector() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.stepPillBg,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.stepPillBorder, width: 1.2),
      ),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = (constraints.maxWidth - 4) / 2;
          return Stack(
            children: [
              // Gliding Midnight Obsidian pill indicator
              AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(_slideAnimation.value * tabWidth, 0),
                    child: Container(
                      width: tabWidth,
                      height: constraints.maxHeight,
                      decoration: BoxDecoration(
                        color: AppColors.primaryObsidian,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.14),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              // Tab text labels and click handlers
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _switchToTab(0),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        alignment: Alignment.center,
                        child: AnimatedBuilder(
                          animation: _slideAnimation,
                          builder: (context, child) {
                            final isLoginActive = _slideAnimation.value < 0.5;
                            return FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isLoginActive ? FontWeight.w700 : FontWeight.w500,
                                  color: Color.lerp(
                                    Colors.white,
                                    AppColors.textMutedMocha,
                                    _slideAnimation.value,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _switchToTab(1),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        alignment: Alignment.center,
                        child: AnimatedBuilder(
                          animation: _slideAnimation,
                          builder: (context, child) {
                            final isSignInActive = _slideAnimation.value >= 0.5;
                            return FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: isSignInActive ? FontWeight.w700 : FontWeight.w500,
                                  color: Color.lerp(
                                    AppColors.textMutedMocha,
                                    Colors.white,
                                    _slideAnimation.value,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  // Butter-Smooth Sliding Form Area with synchronized height interpolation
  Widget _buildSlidingFormArea() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        return AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            // Smoothly interpolate card height between Login (~420px) and Sign In (~580px)
            final currentHeight = 420.0 + (580.0 - 420.0) * _slideAnimation.value;

            return SizedBox(
              height: currentHeight,
              child: ClipRect(
                child: Stack(
                  children: [
                    // Login Form: slides smoothly to the left
                    Transform.translate(
                      offset: Offset(-_slideAnimation.value * width, 0),
                      child: Opacity(
                        opacity: (1.0 - _slideAnimation.value * 1.5).clamp(0.0, 1.0),
                        child: IgnorePointer(
                          ignoring: _slideAnimation.value > 0.5,
                          child: SizedBox(
                            width: width,
                            child: _buildLoginSection(),
                          ),
                        ),
                      ),
                    ),
                    // Sign In Form: slides smoothly in from the right
                    Transform.translate(
                      offset: Offset((1.0 - _slideAnimation.value) * width, 0),
                      child: Opacity(
                        opacity: (_slideAnimation.value * 1.5 - 0.5).clamp(0.0, 1.0),
                        child: IgnorePointer(
                          ignoring: _slideAnimation.value <= 0.5,
                          child: SizedBox(
                            width: width,
                            child: _buildSignInSection(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Section 1: Login Form (2 Fields: Username, Password)
  Widget _buildLoginSection() {
    return KeyedSubtree(
      key: const ValueKey('login_section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Username Input
          _buildInputField(
            controller: _loginUsernameController,
            hintText: 'Username',
            keyboardType: TextInputType.text,
            prefixIcon: Icons.person_outline_rounded,
          ),

          const SizedBox(height: 14),

          // 2. Password Input with Obscure Toggle
          _buildInputField(
            controller: _loginPasswordController,
            hintText: 'Password',
            obscureText: _obscureLoginPassword,
            prefixIcon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureLoginPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AppColors.accentBronze,
              ),
              onPressed: () {
                setState(() {
                  _obscureLoginPassword = !_obscureLoginPassword;
                });
              },
            ),
          ),

          // Forgot Password Action (Right-aligned)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _showForgotPasswordSheet,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Forgot Password?',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentBronze,
                ),
              ),
            ),
          ),

          if (_loginErrorMessage != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _loginErrorMessage!,
                style: const TextStyle(
                  color: AppColors.safetyRed,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Primary "Login" Button (Midnight Obsidian)
          _buildPrimaryButton(
            label: 'Login',
            onPressed: _handleLogin,
          ),

          const SizedBox(height: 18),

          // Divider
          const Center(
            child: Text(
              'Or',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.accentBronze,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Continue with Google Button
          _buildGoogleButton(),

          const SizedBox(height: 20),

          // Shift to Sign In (Right)
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMutedMocha,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _switchToTab(1),
                    child: const Text(
                      'Create new account',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textObsidian,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.textObsidian,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Section 2: Sign-In Form (5 Fields: Name, Username, Gmail, Password, Confirm Password)
  Widget _buildSignInSection() {
    return KeyedSubtree(
      key: const ValueKey('signin_section'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Name
          _buildInputField(
            controller: _signNameController,
            hintText: 'Full Name',
            keyboardType: TextInputType.name,
            prefixIcon: Icons.badge_outlined,
          ),

          const SizedBox(height: 12),

          // 2. Username to set
          _buildInputField(
            controller: _signUsernameController,
            hintText: 'Username to set',
            keyboardType: TextInputType.text,
            prefixIcon: Icons.alternate_email_rounded,
          ),

          const SizedBox(height: 12),

          // 3. Gmail / Email
          _buildInputField(
            controller: _signEmailController,
            hintText: 'Gmail Address',
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline_rounded,
          ),

          const SizedBox(height: 12),

          // 4. Password
          _buildInputField(
            controller: _signPasswordController,
            hintText: 'Password',
            obscureText: _obscureSignPassword,
            prefixIcon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureSignPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AppColors.accentBronze,
              ),
              onPressed: () {
                setState(() {
                  _obscureSignPassword = !_obscureSignPassword;
                });
              },
            ),
          ),

          const SizedBox(height: 12),

          // 5. Confirm Password
          _buildInputField(
            controller: _signConfirmPasswordController,
            hintText: 'Confirm Password',
            obscureText: _obscureSignConfirmPassword,
            prefixIcon: Icons.lock_reset_rounded,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureSignConfirmPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: AppColors.accentBronze,
              ),
              onPressed: () {
                setState(() {
                  _obscureSignConfirmPassword = !_obscureSignConfirmPassword;
                });
              },
            ),
          ),

          if (_signErrorMessage != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _signErrorMessage!,
                style: const TextStyle(
                  color: AppColors.safetyRed,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Primary "Sign In" Button (Midnight Obsidian)
          _buildPrimaryButton(
            label: 'Sign In',
            onPressed: _handleSignIn,
          ),

          const SizedBox(height: 18),

          // Shift to Login (Left)
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textMutedMocha,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _switchToTab(0),
                    child: const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textObsidian,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.textObsidian,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Divider
          const Center(
            child: Text(
              'Or',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.accentBronze,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Continue with Google Button
          _buildGoogleButton(),
        ],
      ),
    );
  }

  // Reusable Pill Input Field matching starter luxury card surfaces
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    IconData? prefixIcon,
    Widget? suffixIcon,
  }) {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textObsidian,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
            color: AppColors.textMutedMocha.withValues(alpha: 0.65),
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
          ),
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 20, color: AppColors.accentBronze)
              : null,
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: AppColors.cardSurface,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(
              color: AppColors.cardBorder,
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(
              color: AppColors.primaryObsidian,
              width: 1.6,
            ),
          ),
        ),
      ),
    );
  }

  // Primary Action Button (Midnight Obsidian matching starter screen Next button)
  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryObsidian,
          disabledBackgroundColor: AppColors.primaryObsidian.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.1,
                ),
              ),
      ),
    );
  }

  // Outlined Google Sign-In Button matching starter frosted card surface
  Widget _buildGoogleButton() {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.cardSurface,
          side: const BorderSide(
            color: AppColors.cardBorder,
            width: 1.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          elevation: 0,
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GoogleLogoIcon(size: 20),
              SizedBox(width: 10),
              Text(
                'Continue with Google',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textObsidian,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Legal Disclaimer Footer matching starter body copy
  Widget _buildFooterDisclaimer() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'By continuing you agree to VeriBite',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textMutedMocha,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Opening Terms & Conditions...'),
                    backgroundColor: AppColors.primaryObsidian,
                  ),
                );
              },
              child: const Text(
                'Terms & Conditions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentBronze,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.accentBronze,
                ),
              ),
            ),
            const Text(
              ' & ',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textMutedMocha,
              ),
            ),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Opening Privacy Policy...'),
                    backgroundColor: AppColors.primaryObsidian,
                  ),
                );
              },
              child: const Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentBronze,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.accentBronze,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
