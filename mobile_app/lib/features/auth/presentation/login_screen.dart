import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import 'widgets/google_logo_icon.dart';
import 'widgets/login_feature_chip.dart';

/// Production-ready VeriBite Login & Authentication Screen
/// Modeled after the high-converting consumer food intelligence onboarding flow.
class LoginScreen extends StatefulWidget {
  final VoidCallback? onGoogleSignIn;
  final ValueChanged<String>? onContinueWithCredential;
  final VoidCallback? onSkipOrGuest;

  const LoginScreen({
    super.key,
    this.onGoogleSignIn,
    this.onContinueWithCredential,
    this.onSkipOrGuest,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _credentialController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _credentialController.dispose();
    super.dispose();
  }

  bool _isValidEmail(String input) {
    final emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[\w\-]{2,6}$');
    return emailRegex.hasMatch(input.trim());
  }

  bool _isValidPhone(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'\D'), '');
    return digitsOnly.length >= 10 && digitsOnly.length <= 13;
  }

  void _handleContinue() {
    setState(() {
      _errorMessage = null;
    });

    final input = _credentialController.text.trim();
    if (input.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your email or phone number';
      });
      return;
    }

    if (!_isValidEmail(input) && !_isValidPhone(input)) {
      setState(() {
        _errorMessage = 'Enter a valid email address or 10-digit mobile number';
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (widget.onContinueWithCredential != null) {
      widget.onContinueWithCredential!(input);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verifying credential for $input...'),
          backgroundColor: AppColors.loginBrandPurple,
        ),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _handleGoogleSignIn() {
    if (widget.onGoogleSignIn != null) {
      widget.onGoogleSignIn!();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connecting with Google...'),
          backgroundColor: AppColors.loginBrandPurple,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: bottomInset > 0 ? bottomInset + 16 : 24),
          physics: const ClampingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Soft Lavender Header Canvas
              _buildTopHeaderArea(),

              const SizedBox(height: 28),

              // Middle Form & Actions Area
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // "Welcome to VeriBite" Heading
                      const Text(
                        'Welcome to VeriBite',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                          letterSpacing: -0.4,
                        ),
                      ),

                      const SizedBox(height: 22),

                      // "Continue with Google" Outlined Button
                      _buildGoogleButton(),

                      const SizedBox(height: 20),

                      // "Or" Divider
                      const Text(
                        'Or',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8F95A5),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Email / Phone Input Field
                      _buildCredentialInput(),

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.safetyRed,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Primary "Continue" Button
                      _buildContinueButton(),

                      const SizedBox(height: 44),

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
    );
  }

  Widget _buildTopHeaderArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 24, bottom: 28, left: 16, right: 16),
      decoration: BoxDecoration(
        color: AppColors.loginBgWash,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF543EE8).withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Logo squircle tile
          _buildAppLogoTile(),

          const SizedBox(height: 18),

          // Main Header Headline
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Join 1 million+ smart consumers',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111827),
                letterSpacing: -0.4,
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Subtitle
          const FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              'Scan smarter. Choose wiser.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: AppColors.loginSubtitlePurple,
                letterSpacing: -0.1,
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Value Proposition Pills - Row 1
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
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
              LoginFeatureChip(
                icon: Icons.star_outline_rounded,
                label: 'Earn rewards',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppLogoTile() {
    return Container(
      width: 66,
      height: 66,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF543EE8).withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(
          'assets/images/app_logo.png',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.loginBrandPurple,
            child: const Icon(
              Icons.eco_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _handleGoogleSignIn,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(
            color: AppColors.loginGoogleBorder,
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
                  color: Color(0xFF1F2937),
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCredentialInput() {
    return SizedBox(
      height: 52,
      child: TextField(
        controller: _credentialController,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _handleContinue(),
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF111827),
        ),
        decoration: InputDecoration(
          hintText: 'Enter your Email/Phone',
          hintStyle: const TextStyle(
            color: AppColors.loginInputHint,
            fontSize: 14.5,
            fontWeight: FontWeight.w400,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: BorderSide(
              color: _errorMessage != null ? AppColors.safetyRed : AppColors.loginInputBorder,
              width: 1.2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(28),
            borderSide: const BorderSide(
              color: AppColors.loginBrandPurple,
              width: 1.6,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleContinue,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.loginBrandPurple,
          disabledBackgroundColor: AppColors.loginBrandPurple.withValues(alpha: 0.6),
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
            : const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.1,
                ),
              ),
      ),
    );
  }

  Widget _buildFooterDisclaimer() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'By continuing you agree to VeriBite',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
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
                  const SnackBar(content: Text('Opening Terms & Conditions...')),
                );
              },
              child: const Text(
                'Terms & Conditions',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.loginBrandPurple,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.loginBrandPurple,
                ),
              ),
            ),
            const Text(
              ' & ',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Opening Privacy Policy...')),
                );
              },
              child: const Text(
                'Privacy Policy',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.loginBrandPurple,
                  decoration: TextDecoration.underline,
                  decorationColor: AppColors.loginBrandPurple,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
