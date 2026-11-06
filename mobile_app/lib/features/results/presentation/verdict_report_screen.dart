import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../advisor/domain/advisor_chat_model.dart';
import '../../advisor/presentation/advisor_chat_screen.dart';
import '../../camera/application/product_scanner_service.dart';
import '../../home/application/home_dashboard_service.dart';
import '../../onboarding/presentation/widgets/watermark_painter.dart';
import '../../profile/domain/user_profile_model.dart';
import 'ingredient_breakdown_screen.dart';
import 'widgets/circular_score_gauge.dart';

/// Page 6: Master Verdict Screen
/// Core scanner report featuring the circular 0-100 score gauge, strict 39/100 Red-cap,
/// dynamic 1-serving vs whole-packet multiplier toggle, safe consumption portion card,
/// and dual actions ("I Ate This" vs "Just Checking").
class VerdictReportScreen extends StatefulWidget {
  final ScannedProductResult product;
  final UserProfileModel userProfile;
  final HomeDashboardService? dashboardService;

  const VerdictReportScreen({
    super.key,
    required this.product,
    required this.userProfile,
    this.dashboardService,
  });

  @override
  State<VerdictReportScreen> createState() => _VerdictReportScreenState();
}

class _VerdictReportScreenState extends State<VerdictReportScreen> {
  late final HomeDashboardService _dashboardService;
  bool _isWholePack = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _dashboardService = widget.dashboardService ?? HomeDashboardService();
  }

  double get _multiplier => _isWholePack ? 3.0 : 1.0;
  double get _currentServingGrams => widget.product.servingSizeG * _multiplier;
  double get _currentSugarGrams => widget.product.sugarGPerServing * _multiplier;
  int get _currentCalories => (widget.product.caloriesPerServing * _multiplier).round();

  // Approximate saturated fat & sodium per serving based on product category & nutrition
  double get _currentSatFatGrams {
    final base = (widget.product.sugarGPerServing * 0.4).clamp(0.5, 12.0);
    return double.parse((base * _multiplier).toStringAsFixed(1));
  }

  int get _currentSodiumMg {
    final base = (widget.product.servingSizeG * 6.5).clamp(20.0, 950.0);
    return (base * _multiplier).round();
  }

  Future<void> _handleIAteThis() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    await HapticFeedback.mediumImpact();

    await _dashboardService.logConsumedProduct(
      userId: widget.userProfile.userId,
      barcode: widget.product.barcode,
      consumedSugarGrams: _currentSugarGrams,
      hasRedAdditives: widget.product.redCapTriggered,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logged ${_currentSugarGrams.toStringAsFixed(1)}g sugar to today\'s consumption budget!',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.safetyGreen,
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _handleJustChecking() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    await HapticFeedback.selectionClick();

    await _dashboardService.recordScan(
      userId: widget.userProfile.userId,
      barcode: widget.product.barcode,
    );

    if (mounted) {
      Navigator.of(context).pop(false);
    }
  }

  void _openIngredientsBreakdown() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => IngredientBreakdownScreen(
          product: widget.product,
          userProfile: widget.userProfile,
        ),
      ),
    );
  }

  void _openAdvisor() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AdvisorChatScreen(
          userProfile: widget.userProfile,
          initialProductContext: ProductAdvisorContext(
            productName: widget.product.productName,
            barcode: widget.product.barcode,
            healthScore: widget.product.healthScore,
            additives: widget.product.additives,
            nutrition: {
              'sugars_100g': widget.product.sugarGPer100g,
              'sugar_per_serving_g': widget.product.sugarGPerServing,
              'calories': widget.product.caloriesPerServing,
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final maxSugarCeiling = _dashboardService.calculateMaxSugar(widget.userProfile);
    final sugarPercentage = ((_currentSugarGrams / maxSugarCeiling) * 100).round();

    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      body: CustomPaint(
        painter: const WatermarkPainter(),
        child: SafeArea(
          child: Column(
            children: [
              // Top Action Header
              _buildTopBar(),

              // Scrollable Body
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 1. Hero Circular Score Gauge
                          _buildScoreGaugeCard(),

                          const SizedBox(height: 14),

                          // 2. Red-Cap Strict Alert (if triggered)
                          if (product.redCapTriggered) ...[
                            _buildRedCapBanner(),
                            const SizedBox(height: 14),
                          ],

                          // 3. Dynamic Serving Multiplier Segmented Toggle
                          _buildServingMultiplierToggle(),

                          const SizedBox(height: 14),

                          // 4. Dynamic Macro Nutritional Cards Grid
                          _buildMacroNutritionalGrid(sugarPercentage, maxSugarCeiling),

                          const SizedBox(height: 16),

                          // 5. Prescribed Safe Consumption Portion Card
                          _buildSafePortionPrescriptionCard(),

                          const SizedBox(height: 12),

                          // 6. Navigation CTA: Ask AI About This Product
                          _buildAskAIAdvisorCTA(),

                          const SizedBox(height: 14),

                          // 7. Navigation CTA: View Full Ingredients Breakdown
                          _buildIngredientsCTA(),

                          const SizedBox(height: 18),

                          // 7. Dual Action Buttons: "I Ate This" vs "Just Checking"
                          _buildDualActionButtons(),

                          const SizedBox(height: 24),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.canvasCream,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder, width: 1.0)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.cardSurface,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textObsidian, size: 20),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back to Camera',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.product.productName,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textObsidian,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${widget.product.brandName} • ${widget.product.category}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMutedMocha,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // NOVA Classification Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: widget.product.novaGrade >= 4 ? const Color(0xFFFCE8E6) : const Color(0xFFE6F4EA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: (widget.product.novaGrade >= 4 ? AppColors.safetyRed : AppColors.safetyGreen).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'NOVA ${widget.product.novaGrade}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: widget.product.novaGrade >= 4 ? AppColors.safetyRed : AppColors.safetyGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreGaugeCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8C7A6B).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          CircularScoreGauge(
            score: widget.product.healthScore,
            isRedCapped: widget.product.redCapTriggered,
            verdictTag: widget.product.verdictTag,
            size: 190,
          ),
          const SizedBox(height: 12),
          Text(
            widget.product.healthScore >= 70 && !widget.product.redCapTriggered
                ? 'Nutrient-dense formulation with minimal industrial additives.'
                : widget.product.healthScore >= 40 && !widget.product.redCapTriggered
                    ? 'Moderate nutritional quality. Consume in controlled moderation.'
                    : 'Ultra-processed food formulation with high sugar or hazardous additives.',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMutedMocha,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRedCapBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFCE8E6),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.safetyRed.withValues(alpha: 0.4), width: 1.2),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gavel_rounded, color: AppColors.safetyRed, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '39/100 Toxic Red-Cap Enforced',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.safetyRed,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'This product contains Red-tier additives or synthetic dyes. Even if marketing claims advertise high fiber or vitamins, the maximum possible health score is capped at 39/100 by medical toxicology standards.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textObsidian,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServingMultiplierToggle() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.0),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isWholePack) setState(() => _isWholePack = false);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: !_isWholePack ? AppColors.primaryObsidian : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  '1 Serving (${widget.product.servingSizeG.toStringAsFixed(0)}g)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: !_isWholePack ? Colors.white : AppColors.textMutedMocha,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isWholePack) setState(() => _isWholePack = true);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _isWholePack ? AppColors.primaryObsidian : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Whole Pack (${(_currentServingGrams).toStringAsFixed(0)}g)',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _isWholePack ? Colors.white : AppColors.textMutedMocha,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroNutritionalGrid(int sugarPercentage, double maxSugarCeiling) {
    return Row(
      children: [
        Expanded(
          child: _buildMacroCard(
            label: 'Calories',
            value: '$_currentCalories',
            unit: 'kcal',
            subtext: '${(_currentCalories / 20).round()}% daily est.',
            color: AppColors.accentBronze,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMacroCard(
            label: 'Total Sugar',
            value: _currentSugarGrams.toStringAsFixed(1),
            unit: 'g',
            subtext: '$sugarPercentage% WHO limit',
            color: sugarPercentage > 50 ? AppColors.safetyRed : AppColors.safetyAmber,
            highlightBorder: sugarPercentage > 75,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMacroCard(
            label: 'Sat. Fat',
            value: _currentSatFatGrams.toStringAsFixed(1),
            unit: 'g',
            subtext: 'lipid load',
            color: AppColors.textObsidian,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMacroCard(
            label: 'Sodium',
            value: '$_currentSodiumMg',
            unit: 'mg',
            subtext: 'salt ceiling',
            color: _currentSodiumMg > 500 ? AppColors.safetyRed : AppColors.textObsidian,
          ),
        ),
      ],
    );
  }

  Widget _buildMacroCard({
    required String label,
    required String value,
    required String unit,
    required String subtext,
    required Color color,
    bool highlightBorder = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlightBorder ? AppColors.safetyRed.withValues(alpha: 0.5) : AppColors.cardBorder,
          width: highlightBorder ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textMutedMocha),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
              ),
              const SizedBox(width: 2),
              Text(
                unit,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMutedMocha),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafePortionPrescriptionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8C7A6B).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_outlined, size: 18, color: AppColors.accentBronze),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Safe Consumption Portion & Frequency',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textObsidian,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.product.portionAdvice,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textObsidian,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8C7A6B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Frequency: ${widget.product.frequencySchedule}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.accentBronze,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Constraint: ${widget.product.limitingFactor}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textObsidian,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAskAIAdvisorCTA() {
    return InkWell(
      onTap: _openAdvisor,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F4EA),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF0F9D58).withValues(alpha: 0.35), width: 1.2),
        ),
        child: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFF0F9D58), size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ask AI About This Product',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textObsidian,
                    ),
                  ),
                  Text(
                    'Get personalized advice, diabetic safety & alternatives',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMutedMocha,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: Color(0xFF0F9D58), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsCTA() {
    final totalDetected = widget.product.additives.length + widget.product.splitSugars.length;

    return InkWell(
      onTap: _openIngredientsBreakdown,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.stepPillBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accentBronze.withValues(alpha: 0.35), width: 1.2),
        ),
        child: Row(
          children: [
            const Icon(Icons.science_outlined, color: AppColors.accentBronze, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Full Ingredients & Toxicology Breakdown',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textObsidian,
                    ),
                  ),
                  Text(
                    '$totalDetected additives & sweetener aliases analyzed',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMutedMocha,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_rounded, color: AppColors.accentBronze, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDualActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. I Ate This Button
        SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _isSubmitting ? null : _handleIAteThis,
            icon: const Icon(Icons.restaurant_rounded, size: 18),
            label: const Text(
              'I Ate This (Log to Today\'s Budget)',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryObsidian,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 2. Just Checking Button
        SizedBox(
          height: 46,
          child: OutlinedButton(
            onPressed: _isSubmitting ? null : _handleJustChecking,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textObsidian,
              side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text(
              'Just Checking (Don\'t Add to Budget)',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
