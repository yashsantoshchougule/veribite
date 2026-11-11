import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../main.dart';
import '../../auth/application/supabase_auth_service.dart';
import '../../camera/presentation/widgets/backend_settings_sheet.dart';
import '../../home/presentation/widgets/update_available_bottom_sheet.dart';
import '../../legal/presentation/legal_policy_screen.dart';
import '../../../services/app_update_service.dart';
import '../../onboarding/presentation/widgets/watermark_painter.dart';
import '../application/user_profile_manager.dart';
import '../application/user_profile_service.dart';
import '../domain/user_profile_model.dart';
import 'user_details_screen.dart';

/// Page 12: Profile & Health Command Center Screen
/// Displays active biometrics, calculated WHO/ICMR safe consumption ceilings,
/// medical guardrails, allergens watchlist, regional voice language, and account controls.
class ProfileScreen extends StatefulWidget {
  final String userId;
  final UserProfileService? profileService;
  final SupabaseAuthService? authService;

  const ProfileScreen({
    super.key,
    required this.userId,
    this.profileService,
    this.authService,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final UserProfileService _profileService;
  late final SupabaseAuthService _authService;

  UserProfileModel? _profile;
  bool _isLoading = true;
  bool _isCheckingForUpdates = false;

  @override
  void initState() {
    super.initState();
    _profileService = widget.profileService ?? UserProfileService();
    _authService = widget.authService ?? SupabaseAuthService();
    UserProfileManager.instance.addListener(_onProfileManagerUpdated);
    _loadProfile();
  }

  @override
  void dispose() {
    UserProfileManager.instance.removeListener(_onProfileManagerUpdated);
    super.dispose();
  }

  void _onProfileManagerUpdated() {
    if (mounted) {
      setState(() {
        _profile = UserProfileManager.instance.profile;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    final profile = await _profileService.getProfile(widget.userId);
    if (mounted) {
      setState(() {
        _profile = profile ??
            (UserProfileManager.instance.isInitialized
                ? UserProfileManager.instance.profile
                : UserProfileModel.defaults(widget.userId));
        _isLoading = false;
      });
    }
  }

  Future<void> _handleManualUpdateCheck() async {
    if (_isCheckingForUpdates) return;
    setState(() => _isCheckingForUpdates = true);

    try {
      final info = await AppUpdateService.instance.checkForUpdate(manual: true);
      if (!mounted) return;

      if (info != null && info.hasUpdate) {
        await UpdateAvailableBottomSheet.show(context, info);
      } else if (info != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "You're on the latest version of VeriBite (v${AppUpdateService.currentVersion}).",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.primaryObsidian,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to check for updates. Please check your internet connection.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            backgroundColor: AppColors.safetyAmber,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingForUpdates = false);
      }
    }
  }

  void _openEditBiometrics() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserDetailsScreen(
          userId: widget.userId,
          profileService: _profileService,
          isEditMode: true,
          onComplete: () {
            Navigator.of(context).pop();
            _loadProfile();
          },
        ),
      ),
    );
  }

  Future<void> _updateLanguage(String langCode) async {
    if (_profile == null) return;
    final updated = _profile!.copyWith(language: langCode);
    setState(() {
      _profile = updated;
    });
    await _profileService.saveProfile(updated);
  }

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text(
          'Sign Out of VeriBite',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.textObsidian,
          ),
        ),
        content: const Text(
          'Are you sure you want to sign out? Your offline database and personal health limits remain securely stored on this device.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textMutedMocha,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textMutedMocha,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryObsidian,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _authService.signOut();
      _profileService.clearUserCache(widget.userId);

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (ctx) => ScannerApp.buildLoginScreen(ctx)),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.canvasCream,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryObsidian),
          ),
        ),
      );
    }

    final profile = _profile ?? UserProfileModel.defaults(widget.userId);
    final user = _authService.currentUser;
    final displayName = user?.userMetadata?['full_name'] as String? ??
        (user?.email != null ? user!.email!.split('@').first : 'VeriBite Consumer');
    final email = user?.email ?? (widget.userId.contains('@') ? widget.userId : 'Offline Guest Account');

    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      body: CustomPaint(
        painter: const WatermarkPainter(),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Top Navigation Bar
              _buildTopBar(),

              // 2. Scrollable Body
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // A. User Identity & Account Passport
                          _buildUserPassportCard(displayName, email),

                          const SizedBox(height: 16),

                          // B. Active Biometrics & Medical Guardrails Card
                          _buildBiometricsCard(profile),

                          const SizedBox(height: 16),

                          // C. Calculated Safe Consumption Ceilings (WHO / ICMR Limits)
                          _buildSafeCeilingsCard(profile),

                          const SizedBox(height: 16),

                          // D. Allergens & Dietary Lifestyle Watchlist
                          _buildAllergensAndDietCard(profile),

                          const SizedBox(height: 16),

                          // E. Regional Voice Read-Out Language Selector
                          _buildLanguageSelectorCard(profile),

                          const SizedBox(height: 16),

                          // F. Offline Toxicology & Privacy Status
                          _buildOfflineEngineCard(),

                          const SizedBox(height: 20),

                          // G. Sign Out Action
                          _buildSignOutButton(),

                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(
          bottom: BorderSide(color: AppColors.cardBorder, width: 1.0),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textObsidian),
                  onPressed: () => Navigator.of(context).maybePop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  tooltip: 'Back',
                ),
                const SizedBox(width: 4),
                const Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'My Health Profile',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textObsidian,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => Navigator.of(context).maybePop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Done',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.accentBronze,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserPassportCard(String name, String email) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'V';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primaryObsidian,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E1424).withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.accentBronze.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accentBronze, width: 1.4),
            ),
            alignment: Alignment.center,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    email,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFFC7BEB3),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_user_rounded, size: 12, color: AppColors.safetyGreen),
                        SizedBox(width: 4),
                        Text(
                          'Verified Account • Isolated Storage',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFE6DFD5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBiometricsCard(UserProfileModel profile) {
    final weight = profile.weightKg;
    final isChild = profile.isChild;

    final activeGuards = <String>[];
    if (profile.isDiabetic) activeGuards.add('Type-2 Diabetic');
    if (profile.isHypertensive) activeGuards.add('Hypertension Guard');
    if (profile.isPregnancySafe) activeGuards.add('Pregnancy Safe');
    if (profile.isLowSugar) activeGuards.add('Low Sugar Ceiling');
    if (isChild) activeGuards.add('Child Guard (<18 yrs)');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8C7A6B).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.monitor_weight_outlined, size: 20, color: AppColors.accentBronze),
                    SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Active Biometrics & Life Stage',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textObsidian,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openEditBiometrics,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.stepPillBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.stepPillBorder, width: 1.0),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, size: 13, color: AppColors.accentBronze),
                      SizedBox(width: 4),
                      Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textObsidian,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Weight & Stage Display
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.canvasCream,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder, width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      weight.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textObsidian,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Text(
                      'kg',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accentBronze,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isChild ? 'Child / Teen (< 18 yrs)' : 'Adult (18+ Standard)',
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textObsidian,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isChild ? 'Southampton azo dye hyperactivity cap active' : 'Standard WHO Acceptable Daily Intake limits',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedMocha,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (activeGuards.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: activeGuards.map((guard) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.stepPillBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.stepPillBorder, width: 1.0),
                  ),
                  child: Text(
                    '🛡️ $guard',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textObsidian,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSafeCeilingsCard(UserProfileModel profile) {
    final weight = profile.weightKg;
    final isChild = profile.isChild;
    final isDiabetic = profile.isDiabetic;
    final isHypertensive = profile.isHypertensive;

    // Mathematical WHO limits scaled to weight
    final double dailySugarLimit = isDiabetic ? 10.0 : (isChild ? 15.0 : 25.0);
    final double singleSnackSugar = isDiabetic ? 2.0 : 5.0;
    final double sodiumLimit = isHypertensive ? 1500.0 : (2000.0 * (weight / 65.0)).clamp(1000.0, 2000.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8C7A6B).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 20, color: AppColors.safetyGreen),
              SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Calculated Safe Daily Ceilings',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textObsidian,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Calibrated strictly against WHO/ICMR standards for your body mass:',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMutedMocha,
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _buildCeilingTile(
                  label: 'Free Sugar Max',
                  value: '${dailySugarLimit.toStringAsFixed(0)}g',
                  sub: 'Per day limit',
                  color: AppColors.safetyGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCeilingTile(
                  label: 'Single Snack',
                  value: '≤ ${singleSnackSugar.toStringAsFixed(0)}g',
                  sub: '1-packet cap',
                  color: AppColors.accentBronze,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildCeilingTile(
                  label: 'Sodium Cap',
                  value: '${sodiumLimit.toStringAsFixed(0)}mg',
                  sub: 'Scaled to wt',
                  color: AppColors.safetyAmber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCeilingTile({
    required String label,
    required String value,
    required String sub,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.canvasCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textMutedMocha,
              ),
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              sub,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textMutedMocha,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergensAndDietCard(UserProfileModel profile) {
    final allergens = profile.allergens;
    final diet = profile.dietaryPreference ?? 'Standard Balanced';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8C7A6B).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.restaurant_menu_rounded, size: 20, color: AppColors.accentBronze),
                    SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Allergens & Diet Watchlist',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textObsidian,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _openEditBiometrics,
                child: const Text(
                  'Change',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentBronze,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              const Text(
                'Dietary Lifestyle: ',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMutedMocha, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.safetyGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  diet,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.safetyGreen,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (allergens.isEmpty)
            const Text(
              'No specific allergens flagged. All 14 common allergens monitored passively.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMutedMocha,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: allergens.map((allergen) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.safetyAmber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.safetyAmber.withValues(alpha: 0.3), width: 1.0),
                  ),
                  child: Text(
                    '⚠️ $allergen',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF9C4221),
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelectorCard(UserProfileModel profile) {
    final currentLang = profile.language;

    final languages = [
      {'code': 'en', 'label': 'English'},
      {'code': 'hi', 'label': 'Hindi (हिंदी)'},
      {'code': 'mr', 'label': 'Marathi (मराठी)'},
      {'code': 'ta', 'label': 'Tamil (தமிழ்)'},
      {'code': 'te', 'label': 'Telugu (తెలుగు)'},
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8C7A6B).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.record_voice_over_rounded, size: 20, color: AppColors.accentBronze),
              SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Regional Voice Read-Out Language',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textObsidian,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Audible toxicology analysis and safe dosage reports will speak in this language:',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textMutedMocha,
            ),
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: languages.map((lang) {
              final isSelected = currentLang == lang['code'];
              return GestureDetector(
                onTap: () => _updateLanguage(lang['code']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primaryObsidian : AppColors.stepPillBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.primaryObsidian : AppColors.stepPillBorder,
                      width: 1.2,
                    ),
                  ),
                  child: Text(
                    lang['label']!,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textObsidian,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineEngineCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.cloud_done_rounded, size: 20, color: AppColors.accentBronze),
              SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Offline Engine & Privacy Guard',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textObsidian,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '• 6,450+ chemical INS / E-numbers loaded offline in SQLite.\n'
            '• 56+ hidden split sugar aliases verified locally.\n'
            '• Zero third-party telemetry, ads, or tracking cookies.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: AppColors.textMutedMocha,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LegalPolicyScreen(initialTab: LegalTab.terms),
                      ),
                    );
                  },
                  icon: const Icon(Icons.description_outlined, size: 15, color: AppColors.textObsidian),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Terms of Service',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textObsidian,
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const LegalPolicyScreen(initialTab: LegalTab.privacy),
                      ),
                    );
                  },
                  icon: const Icon(Icons.shield_outlined, size: 15, color: AppColors.textObsidian),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Privacy Policy',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textObsidian,
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.stepPillBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.cardBorder, width: 1.0),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: const Icon(Icons.system_update_rounded, size: 18, color: AppColors.accentBronze),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'VeriBite v${AppUpdateService.currentVersion}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textObsidian,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Build #${AppUpdateService.currentBuildNumber} • Release Channel',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMutedMocha,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _isCheckingForUpdates ? null : _handleManualUpdateCheck,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.primaryObsidian,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  child: _isCheckingForUpdates
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Check',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => BackendSettingsSheet.show(context),
              icon: const Icon(Icons.dns_rounded, size: 16, color: AppColors.accentBronze),
              label: const Text(
                'Backend & Vision Proxy Settings',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textObsidian,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignOutButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _handleSignOut,
        icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.safetyRed),
        label: const Text(
          'Sign Out of Account',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: AppColors.safetyRed,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFF3C7C7), width: 1.2),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      ),
    );
  }
}
