import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../onboarding/presentation/widgets/watermark_painter.dart';
import '../application/user_profile_manager.dart';
import '../application/user_profile_service.dart';
import '../domain/user_profile_model.dart';

/// Production-ready User Details Input Screen (Page 3) matching the Warm Luxury
/// Alabaster and Midnight Obsidian editorial aesthetic.
/// Captures mandatory biometrics (weight & life stage) and optional health guardrails
/// with strict per-account isolation and full skip capabilities.
class UserDetailsScreen extends StatefulWidget {
  final String userId;
  final VoidCallback onComplete;
  final UserProfileService? profileService;
  final bool isEditMode;

  const UserDetailsScreen({
    super.key,
    required this.userId,
    required this.onComplete,
    this.profileService,
    this.isEditMode = false,
  });

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  late final UserProfileService _profileService;
  late final TextEditingController _weightController;
  Timer? _debounceTimer;

  // Essential Biometrics
  double _weightKg = 65.0;
  bool _isChild = false;
  int? _exactAge;

  // Optional Physical Profile
  String? _selectedGender; // 'Male', 'Female', 'Other'
  double? _heightCm;

  // Optional Health Guardrails (Multi-Select)
  bool _isDiabetic = false;
  bool _isHypertensive = false;
  bool _isPregnancySafe = false;
  bool _isLowSugar = false;

  // Optional Allergens (Multi-Select)
  final Set<String> _selectedAllergens = {};

  // Optional Dietary Preference
  String? _selectedDiet;

  // Regional Voice Read-Out Language preference
  String _language = 'en';

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _profileService = widget.profileService ?? UserProfileService();
    final initialWeight = UserProfileManager.instance.isInitialized
        ? UserProfileManager.instance.weightKg
        : 65.0;
    _weightKg = initialWeight;
    _weightController = TextEditingController(text: initialWeight.toStringAsFixed(0));
    _loadExistingProfile();
  }

  @override
  void dispose() {
    if (_debounceTimer?.isActive == true) {
      _debounceTimer?.cancel();
      _profileService.saveProfile(_buildCurrentProfile());
    }
    _weightController.dispose();
    super.dispose();
  }

  UserProfileModel _buildCurrentProfile({bool isCompleted = true}) {
    return UserProfileModel(
      userId: widget.userId,
      weightKg: _weightKg,
      isChild: _isChild,
      age: _exactAge,
      gender: _selectedGender,
      heightCm: _heightCm,
      isDiabetic: _isDiabetic,
      isHypertensive: _isHypertensive,
      isPregnancySafe: _isPregnancySafe,
      isLowSugar: _isLowSugar,
      allergens: _selectedAllergens.toList(),
      dietaryPreference: _selectedDiet,
      language: _language,
      isCompleted: isCompleted,
      updatedAt: DateTime.now(),
    );
  }

  void _triggerAutoSave() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final profile = _buildCurrentProfile();
        await _profileService.saveProfile(profile);
      } catch (e) {
        debugPrint('[UserDetailsScreen] Auto-save notice: $e');
      }
    });
  }

  Future<void> _loadExistingProfile() async {
    final existing = await _profileService.getProfile(widget.userId);
    if (existing != null && mounted) {
      setState(() {
        _weightKg = existing.weightKg;
        _isChild = existing.isChild;
        _exactAge = existing.age;
        _selectedGender = existing.gender;
        _heightCm = existing.heightCm;
        _isDiabetic = existing.isDiabetic;
        _isHypertensive = existing.isHypertensive;
        _isPregnancySafe = existing.isPregnancySafe;
        _isLowSugar = existing.isLowSugar;
        _selectedAllergens.clear();
        _selectedAllergens.addAll(existing.allergens);
        _selectedDiet = existing.dietaryPreference;
        _language = existing.language;
        _weightController.text = existing.weightKg.toStringAsFixed(0);
      });
    }
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    _debounceTimer?.cancel();

    setState(() {
      _isSaving = true;
    });

    try {
      final profile = _buildCurrentProfile(isCompleted: true);
      await _profileService.saveProfile(profile);

      if (mounted) {
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: AppColors.safetyRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _handleSkip() async {
    if (_isSaving) return;
    _debounceTimer?.cancel();

    setState(() {
      _isSaving = true;
    });

    try {
      // If user already has custom saved profile (e.g. non-default weight or completed), do not destroy it!
      final current = await _profileService.getProfile(widget.userId);
      if (current == null || !current.isCompleted) {
        final defaultProfile = UserProfileModel.defaults(widget.userId);
        await _profileService.saveProfile(defaultProfile);
      }

      if (mounted) {
        widget.onComplete();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not proceed with defaults: $e'),
            backgroundColor: AppColors.safetyRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      body: CustomPaint(
        painter: const WatermarkPainter(),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Top Bar with Step Progress & Skip Action
              _buildTopBar(),

              // 2. Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Editorial Headline
                      _buildEditorialHeader(),

                      const SizedBox(height: 20),

                      // Essential Biometrics (Weight & Life Stage)
                      _buildEssentialBiometricsCard(),

                      const SizedBox(height: 18),

                      // Optional Gender & Physical Profile
                      _buildGenderSection(),

                      const SizedBox(height: 18),

                      // Optional Health Guardrails (Diabetic, Hypertension, etc.)
                      _buildHealthGuardrailsSection(),

                      const SizedBox(height: 18),

                      // Optional Allergens & Dietary Preferences
                      _buildAllergenAndDietSection(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // 3. Persistent Bottom Action Bar
              _buildBottomActionBar(),
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
                if (widget.isEditMode) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textObsidian),
                    onPressed: () => Navigator.of(context).maybePop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                  const SizedBox(width: 4),
                ] else ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryObsidian,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.eco_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.isEditMode ? 'Edit Profile' : 'Personalize Limits',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textObsidian,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (widget.isEditMode)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textMutedMocha),
              onPressed: () => Navigator.of(context).maybePop(),
              tooltip: 'Close',
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              child: TextButton(
                onPressed: _isSaving ? null : _handleSkip,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Skip for now',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentBronze,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditorialHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.stepPillBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.stepPillBorder, width: 1.0),
          ),
          child: Text(
            widget.isEditMode ? 'PROFILE SETTINGS • EDIT CEILINGS' : 'Step 1 of 1 • Health Baseline',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textObsidian,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          widget.isEditMode ? 'Edit Safe Limits' : 'Tailor Your Safe Limits',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.textObsidian,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.isEditMode
              ? 'Update your body weight or dietary guardrails. Changes take effect instantly across all barcode scans.'
              : 'Safe daily sugar ceilings and chemical intake portions are calculated directly from your body weight and health needs.',
          style: const TextStyle(
            fontSize: 14,
            height: 1.4,
            color: AppColors.textMutedMocha,
          ),
        ),
      ],
    );
  }

  // Essential Biometrics: Weight Slider and Adult/Child Life Stage Toggle
  Widget _buildEssentialBiometricsCard() {
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
                          'Body Weight',
                          style: TextStyle(
                            fontSize: 16,
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryObsidian.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Essential',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryObsidian,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Large Weight Readout with Steppers
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                    iconSize: 28,
                    color: _weightKg > 15 ? AppColors.primaryObsidian : AppColors.cardBorder,
                    onPressed: _weightKg > 15
                        ? () {
                            setState(() {
                              _weightKg = (_weightKg - 1.0).clamp(15.0, 120.0);
                              _weightController.text = _weightKg.toStringAsFixed(0);
                            });
                            _triggerAutoSave();
                          }
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _weightKg.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textObsidian,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'kg',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentBronze,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded),
                    iconSize: 28,
                    color: _weightKg < 120 ? AppColors.primaryObsidian : AppColors.cardBorder,
                    onPressed: _weightKg < 120
                        ? () {
                            setState(() {
                              _weightKg = (_weightKg + 1.0).clamp(15.0, 120.0);
                              _weightController.text = _weightKg.toStringAsFixed(0);
                            });
                            _triggerAutoSave();
                          }
                        : null,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Direct Numeric Input Field for custom exact weights (e.g. 87 kg)
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 180),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.stepPillBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.stepPillBorder, width: 1.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_outlined, size: 14, color: AppColors.accentBronze),
                    const SizedBox(width: 6),
                    Expanded(
                      child: TextField(
                        controller: _weightController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textObsidian,
                        ),
                        decoration: const InputDecoration(
                          hintText: '87',
                          suffixText: 'kg',
                          suffixStyle: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentBronze,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(vertical: 6),
                        ),
                        onChanged: (text) {
                          final parsed = double.tryParse(text.trim());
                          if (parsed != null && parsed >= 15.0 && parsed <= 250.0) {
                            setState(() {
                              _weightKg = parsed.clamp(15.0, 120.0);
                            });
                            _triggerAutoSave();
                          }
                        },
                        onSubmitted: (text) {
                          final parsed = double.tryParse(text.trim());
                          if (parsed != null && parsed >= 15.0 && parsed <= 250.0) {
                            setState(() {
                              _weightKg = parsed.clamp(15.0, 120.0);
                            });
                            _triggerAutoSave();
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Quick 1-tap preset chips for instant friction-free weight selection
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [50.0, 60.0, 70.0, 80.0].map((preset) {
                  final isSelected = (_weightKg - preset).abs() < 0.5;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _weightKg = preset;
                          _weightController.text = _weightKg.toStringAsFixed(0);
                        });
                        _triggerAutoSave();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primaryObsidian : AppColors.stepPillBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.primaryObsidian : AppColors.stepPillBorder,
                            width: 1.0,
                          ),
                        ),
                        child: Text(
                          '${preset.toInt()} kg',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                            color: isSelected ? Colors.white : AppColors.textObsidian,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryObsidian,
              inactiveTrackColor: AppColors.stepPillBorder,
              thumbColor: AppColors.primaryObsidian,
              overlayColor: AppColors.primaryObsidian.withValues(alpha: 0.12),
              trackHeight: 4,
            ),
            child: Slider(
              value: _weightKg,
              min: 15.0,
              max: 120.0,
              divisions: 210,
              onChanged: (val) {
                setState(() {
                  _weightKg = val;
                  _weightController.text = _weightKg.toStringAsFixed(0);
                });
                _triggerAutoSave();
              },
            ),
          ),

          const Divider(color: AppColors.cardBorder, height: 26),

          // Life Stage Selector (Adult vs Child)
          const Text(
            'Life Stage',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textObsidian,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _buildLifeStageButton(
                  title: 'Adult (18+)',
                  subtitle: 'Standard WHO ceilings',
                  isSelected: !_isChild,
                  onTap: () {
                    setState(() {
                      _isChild = false;
                      if (_weightKg < 40) _weightKg = 65.0;
                      _weightController.text = _weightKg.toStringAsFixed(0);
                    });
                    _triggerAutoSave();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildLifeStageButton(
                  title: 'Child / Teen',
                  subtitle: '< 18 yrs • Stricter limits',
                  isSelected: _isChild,
                  onTap: () {
                    setState(() {
                      _isChild = true;
                      if (_weightKg > 45) _weightKg = 22.0;
                      _weightController.text = _weightKg.toStringAsFixed(0);
                    });
                    _triggerAutoSave();
                  },
                ),
              ),
            ],
          ),

          if (_isChild) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3F2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFECDCA), width: 1.0),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_rounded, color: AppColors.safetyRed, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Child Hyperactivity Guard active: flags EU-banned synthetic dyes & halves sugar limits.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFB42318),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLifeStageButton({
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryObsidian : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryObsidian : AppColors.cardBorder,
            width: 1.4,
          ),
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textObsidian,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? Colors.white70 : AppColors.textMutedMocha,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Optional Gender Section
  Widget _buildGenderSection() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Gender (Optional)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textObsidian,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Skippable',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.accentBronze,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildGenderChip('Male'),
              const SizedBox(width: 10),
              _buildGenderChip('Female'),
              const SizedBox(width: 10),
              _buildGenderChip('Other'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGenderChip(String label) {
    final isSelected = _selectedGender == label;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedGender = isSelected ? null : label;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryObsidian : AppColors.stepPillBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primaryObsidian : AppColors.stepPillBorder,
              width: 1.2,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textObsidian,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Optional Health Guardrails (Diabetic, Hypertension, etc.)
  Widget _buildHealthGuardrailsSection() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Health Conditions (Optional)',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textObsidian,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Multi-select',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.accentBronze,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Triggers instant warnings when scanned products contain harmful hidden ingredients.',
            style: TextStyle(
              fontSize: 12.5,
              color: AppColors.textMutedMocha,
            ),
          ),
          const SizedBox(height: 14),

          _buildGuardrailTile(
            title: 'Type-2 Diabetic / Pre-Diabetic',
            subtitle: 'Flags high-GI split sugars (maltodextrin) & caps free sugars to ≤ 2g',
            icon: Icons.water_drop_outlined,
            isActive: _isDiabetic,
            onToggle: () => setState(() => _isDiabetic = !_isDiabetic),
          ),
          const SizedBox(height: 8),

          _buildGuardrailTile(
            title: 'Hypertension (High Blood Pressure)',
            subtitle: 'Enforces strict sodium ceiling (≤ 120mg) & flags MSG / sodium preservatives',
            icon: Icons.favorite_border_rounded,
            isActive: _isHypertensive,
            onToggle: () => setState(() => _isHypertensive = !_isHypertensive),
          ),
          const SizedBox(height: 8),

          _buildGuardrailTile(
            title: 'Pregnancy-Safe Guard',
            subtitle: 'Flags artificial intense sweeteners (aspartame, saccharin) & high caffeine',
            icon: Icons.pregnant_woman_rounded,
            isActive: _isPregnancySafe,
            onToggle: () => setState(() => _isPregnancySafe = !_isPregnancySafe),
          ),
          const SizedBox(height: 8),

          _buildGuardrailTile(
            title: 'Low Sugar / Weight Guard',
            subtitle: 'Alerts when added sugar exceeds 10% of total product calories',
            icon: Icons.scale_outlined,
            isActive: _isLowSugar,
            onToggle: () => setState(() => _isLowSugar = !_isLowSugar),
          ),
        ],
      ),
    );
  }

  Widget _buildGuardrailTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isActive,
    required VoidCallback onToggle,
  }) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.stepPillBg : AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.primaryObsidian : AppColors.cardBorder,
            width: isActive ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 22,
              color: isActive ? AppColors.primaryObsidian : AppColors.accentBronze,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                      color: AppColors.textObsidian,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.textMutedMocha,
                    ),
                  ),
                ],
              ),
            ),
            Checkbox(
              value: isActive,
              onChanged: (_) => onToggle(),
              activeColor: AppColors.primaryObsidian,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
            ),
          ],
        ),
      ),
    );
  }

  // Optional Allergens & Dietary Preferences
  Widget _buildAllergenAndDietSection() {
    final allergens = ['Gluten', 'Dairy / Lactose', 'Peanuts', 'Soy', 'Tree Nuts'];
    final diets = ['Vegetarian', 'Vegan', 'Jain', 'Non-Veg'];

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
          const Text(
            'Allergies (Optional)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textObsidian,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allergens.map((allergen) {
              final isSelected = _selectedAllergens.contains(allergen);
              return FilterChip(
                label: Text(allergen),
                selected: isSelected,
                onSelected: (val) {
                  setState(() {
                    if (val) {
                      _selectedAllergens.add(allergen);
                    } else {
                      _selectedAllergens.remove(allergen);
                    }
                  });
                },
                selectedColor: AppColors.primaryObsidian,
                backgroundColor: AppColors.stepPillBg,
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textObsidian,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? AppColors.primaryObsidian : AppColors.cardBorder,
                  ),
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),

          const Divider(color: AppColors.cardBorder, height: 26),

          const Text(
            'Dietary Lifestyle (Optional)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textObsidian,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: diets.map((diet) {
              final isSelected = _selectedDiet == diet;
              return ChoiceChip(
                label: Text(diet),
                selected: isSelected,
                onSelected: (val) {
                  setState(() {
                    _selectedDiet = val ? diet : null;
                  });
                },
                selectedColor: AppColors.primaryObsidian,
                backgroundColor: AppColors.stepPillBg,
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textObsidian,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? AppColors.primaryObsidian : AppColors.cardBorder,
                  ),
                ),
                showCheckmark: false,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // Persistent Bottom Action Bar
  Widget _buildBottomActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(
          top: BorderSide(color: AppColors.cardBorder, width: 1.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x1A8C7A6B),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryObsidian,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.isEditMode ? 'Save Changes' : 'Save & Open Scanner',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
            ),
          ),
          if (!widget.isEditMode) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isSaving ? null : _handleSkip,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Skip for now & use standard defaults (65 kg Adult)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMutedMocha,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
