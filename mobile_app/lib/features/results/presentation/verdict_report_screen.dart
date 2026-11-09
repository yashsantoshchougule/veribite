import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../services/product_health_scorer.dart';
import '../../advisor/application/tts_voice_service.dart';
import '../../advisor/domain/advisor_chat_model.dart';
import '../../advisor/presentation/advisor_chat_screen.dart';
import '../../camera/application/product_scanner_service.dart';
import '../../home/application/home_dashboard_service.dart';
import '../../onboarding/presentation/widgets/watermark_painter.dart';
import '../../profile/domain/user_profile_model.dart';
import '../../swaps/presentation/healthier_swaps_screen.dart';
import '../application/medical_report_pdf_service.dart';
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
  final MedicalReportPdfService? pdfService;
  final TtsVoiceService? ttsService;

  const VerdictReportScreen({
    super.key,
    required this.product,
    required this.userProfile,
    this.dashboardService,
    this.pdfService,
    this.ttsService,
  });

  @override
  State<VerdictReportScreen> createState() => _VerdictReportScreenState();
}

enum PortionMode { per100g, perServing, wholePack }

class _VerdictReportScreenState extends State<VerdictReportScreen> {
  late final HomeDashboardService _dashboardService;
  late final TtsVoiceService _ttsService;
  late ScannedProductResult _product;
  bool _ownsTtsService = false;
  PortionMode _portionMode = PortionMode.per100g;
  bool _isSubmitting = false;
  bool _isExportingPdf = false;

  String get _speakingMessageId => 'verdict_${_product.barcode}';

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    _dashboardService = widget.dashboardService ?? HomeDashboardService();
    if (widget.ttsService != null) {
      _ttsService = widget.ttsService!;
    } else {
      _ttsService = TtsVoiceService();
      _ownsTtsService = true;
    }
  }

  @override
  void didUpdateWidget(VerdictReportScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product != widget.product) {
      _product = widget.product;
    }
  }

  @override
  void dispose() {
    _ttsService.stop();
    if (_ownsTtsService) {
      _ttsService.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleListenVerdict() async {
    unawaited(HapticFeedback.lightImpact());
    final summary = TtsVoiceService.buildVerdictSpeechSummary(
      product: _product,
      userProfile: widget.userProfile,
    );
    await _ttsService.toggleSpeak(summary, messageId: _speakingMessageId);
  }

  double get _packWeight => _product.packWeightG > 0
      ? _product.packWeightG
      : (_product.servingSizeG > 0 ? _product.servingSizeG * 3.0 : 100.0);

  double get _currentServingGrams {
    switch (_portionMode) {
      case PortionMode.per100g:
        return 100.0;
      case PortionMode.perServing:
        return _product.servingSizeG > 0 ? _product.servingSizeG : 30.0;
      case PortionMode.wholePack:
        return _packWeight;
    }
  }

  double get _portionRatio => _currentServingGrams / 100.0;

  int get _currentCalories {
    switch (_portionMode) {
      case PortionMode.per100g:
        return _product.effectiveCaloriesPer100g.round();
      case PortionMode.perServing:
        return _product.caloriesPerServing.round();
      case PortionMode.wholePack:
        final packRatio = _packWeight / (_product.servingSizeG > 0 ? _product.servingSizeG : 100.0);
        return (_product.caloriesPerServing > 0
            ? (_product.caloriesPerServing * packRatio)
            : (_product.effectiveCaloriesPer100g * (_packWeight / 100.0))).round();
    }
  }

  double get _currentSugarGrams {
    switch (_portionMode) {
      case PortionMode.per100g:
        return _product.sugarGPer100g;
      case PortionMode.perServing:
        return _product.sugarGPerServing > 0 ? _product.sugarGPerServing : (_product.sugarGPer100g * (_product.servingSizeG / 100.0));
      case PortionMode.wholePack:
        final packRatio = _packWeight / (_product.servingSizeG > 0 ? _product.servingSizeG : 100.0);
        return double.parse(((_product.sugarGPerServing > 0 ? _product.sugarGPerServing : (_product.sugarGPer100g * (_product.servingSizeG / 100.0))) * packRatio).toStringAsFixed(1));
    }
  }

  // Real saturated fat & sodium per portion
  double get _currentSatFatGrams {
    switch (_portionMode) {
      case PortionMode.per100g:
        return _product.satFatGPer100g;
      case PortionMode.perServing:
        return _product.satFatGPerServing > 0 ? _product.satFatGPerServing : double.parse((_product.satFatGPer100g * (_product.servingSizeG / 100.0)).toStringAsFixed(1));
      case PortionMode.wholePack:
        final packRatio = _packWeight / (_product.servingSizeG > 0 ? _product.servingSizeG : 100.0);
        return double.parse(((_product.satFatGPerServing > 0 ? _product.satFatGPerServing : (_product.satFatGPer100g * (_product.servingSizeG / 100.0))) * packRatio).toStringAsFixed(1));
    }
  }

  int get _currentSodiumMg {
    switch (_portionMode) {
      case PortionMode.per100g:
        return _product.sodiumMgPer100g.round();
      case PortionMode.perServing:
        return _product.sodiumMgPerServing > 0 ? _product.sodiumMgPerServing.round() : (_product.sodiumMgPer100g * (_product.servingSizeG / 100.0)).round();
      case PortionMode.wholePack:
        final packRatio = _packWeight / (_product.servingSizeG > 0 ? _product.servingSizeG : 100.0);
        return ((_product.sodiumMgPerServing > 0 ? _product.sodiumMgPerServing : (_product.sodiumMgPer100g * (_product.servingSizeG / 100.0))) * packRatio).round();
    }
  }

  // Secondary nutrients scaled with portion
  double get _currentProteinGrams => double.parse((_product.proteinGPer100g * _portionRatio).toStringAsFixed(1));
  double get _currentCarbsGrams => double.parse((_product.carbsGPer100g * _portionRatio).toStringAsFixed(1));
  double get _currentFiberGrams => double.parse((_product.fiberGPer100g * _portionRatio).toStringAsFixed(1));
  double get _currentAddedSugarGrams => double.parse((_product.addedSugarGPer100g * _portionRatio).toStringAsFixed(1));
  double get _currentTransFatGrams => double.parse((_product.transFatGPer100g * _portionRatio).toStringAsFixed(1));
  double get _currentCholesterolMg => double.parse((_product.cholesterolMgPer100g * _portionRatio).toStringAsFixed(0));

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
              'sat_fat_100g': widget.product.satFatGPer100g,
              'sat_fat_per_serving_g': widget.product.satFatGPerServing > 0
                  ? widget.product.satFatGPerServing
                  : _currentSatFatGrams,
              'sodium_100g': widget.product.sodiumMgPer100g,
              'sodium_per_serving_mg': widget.product.sodiumMgPerServing > 0
                  ? widget.product.sodiumMgPerServing
                  : _currentSodiumMg.toDouble(),
            },
          ),
        ),
      ),
    );
  }

  void _openHealthierSwaps() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => HealthierSwapsScreen(
          currentProduct: widget.product,
          userProfile: widget.userProfile,
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

                          // 3. Nutrition Section Header with Edit Button & 3-Tab Segmented Portion Control
                          _buildNutritionSectionHeader(),
                          const SizedBox(height: 8),
                          _buildServingMultiplierToggle(),

                          const SizedBox(height: 14),

                          // 4. Dynamic Macro Nutritional Cards Grid
                          _buildMacroNutritionalGrid(sugarPercentage, maxSugarCeiling),

                          const SizedBox(height: 12),

                          // Secondary Extracted Nutrients Grid
                          _buildSecondaryNutrientsGrid(),

                          const SizedBox(height: 16),

                          // 5. Prescribed Safe Consumption Portion Card
                          _buildSafePortionPrescriptionCard(),

                          const SizedBox(height: 12),

                          // 6. Navigation CTA: Smart Healthier Clean Swaps
                          _buildHealthierSwapsCTA(),

                          const SizedBox(height: 12),

                          // 7. Navigation CTA: Ask AI About This Product
                          _buildAskAIAdvisorCTA(),

                          const SizedBox(height: 14),

                          // 8. Navigation CTA: View Full Ingredients Breakdown
                          _buildIngredientsCTA(),

                          const SizedBox(height: 14),

                          // 9. 1-Tap Medical / Dietitian Health Report (PDF)
                          _buildMedicalPdfExportCard(),

                          const SizedBox(height: 18),

                          // 10. Dual Action Buttons: "I Ate This" vs "Just Checking"
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
          const SizedBox(width: 8),
          // Listen to Verdict Spoken Audio Button
          ValueListenableBuilder<String?>(
            valueListenable: _ttsService.currentlySpeakingIdNotifier,
            builder: (context, speakingId, _) {
              final isSpeaking = speakingId == _speakingMessageId;
              return CircleAvatar(
                backgroundColor: isSpeaking ? AppColors.sugarPeachBg : AppColors.cardSurface,
                child: IconButton(
                  icon: Icon(
                    isSpeaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                    color: isSpeaking ? AppColors.safetyRed : AppColors.accentBronze,
                    size: 20,
                  ),
                  onPressed: _toggleListenVerdict,
                  tooltip: isSpeaking ? 'Stop Audio Summary' : 'Listen to Spoken Verdict',
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            backgroundColor: AppColors.cardSurface,
            child: IconButton(
              icon: _isExportingPdf
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentBronze),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded, color: AppColors.accentBronze, size: 20),
              onPressed: _isExportingPdf ? null : _exportMedicalReportPdf,
              tooltip: 'Export Medical PDF Report',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreGaugeCard() {
    final score = widget.product.healthScore;
    final String scoreAdvice;
    if (score == null) {
      scoreAdvice = 'Insufficient nutrition facts & ingredients to calculate score. Please capture physical packaging.';
    } else if (widget.product.isIngredientOnlyScore) {
      scoreAdvice = 'Score calculated from verified ingredients & additives (Nutrition table not detected).';
    } else if (score >= 70 && !widget.product.redCapTriggered) {
      scoreAdvice = 'Nutrient-dense formulation with minimal industrial additives.';
    } else if (score >= 40 && !widget.product.redCapTriggered) {
      scoreAdvice = 'Moderate nutritional quality. Consume in controlled moderation.';
    } else {
      scoreAdvice = 'Ultra-processed food formulation with high sugar or hazardous additives.';
    }

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
            scoreAdvice,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMutedMocha,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.product.scoreBreakdown != null && widget.product.scoreBreakdown!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildScoreBreakdownCard(),
          ],
          const SizedBox(height: 14),
          ValueListenableBuilder<String?>(
            valueListenable: _ttsService.currentlySpeakingIdNotifier,
            builder: (context, speakingId, _) {
              final isSpeaking = speakingId == _speakingMessageId;
              return _buildListenVerdictPill(isSpeaking);
            },
          ),
          if (widget.product.analysisSource != null) ...[
            const SizedBox(height: 10),
            _buildAnalysisSourceBadge(widget.product.analysisSource!),
          ],
        ],
      ),
    );
  }

  Widget _buildScoreBreakdownCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.canvasCream,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, size: 14, color: AppColors.textMutedMocha),
              const SizedBox(width: 6),
              const Text(
                'SCIENTIFIC SCORE BREAKDOWN',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMutedMocha,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (widget.product.isIngredientOnlyScore)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.sugarPeachBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'Ingredient-Based',
                    style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: AppColors.sugarPeachText),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: widget.product.scoreBreakdown!
                .split(RegExp(r'\s*\|\s*|\s*=\s*(?=Score:|Final Score:)'))
                .map((t) => t.trim())
                .where((t) => t.isNotEmpty)
                .map((token) {
                  final isBase = token.startsWith('Base');
                  final isScore = token.startsWith('Score:') || token.startsWith('Final Score:');
                  final isNegative = !isScore && (token.contains(':-') || token.contains('Capped') || token.contains('NOVA 4') || token.contains('NOVA 3'));
                  final isPositive = !isScore && token.contains(':+');

                  Color bg = Colors.white;
                  Color text = AppColors.textObsidian;
                  Color border = AppColors.cardBorder;

                  if (isBase) {
                    bg = const Color(0xFFF0EFEB);
                    text = AppColors.textObsidian;
                  } else if (isScore) {
                    bg = AppColors.primaryObsidian;
                    text = Colors.white;
                    border = AppColors.primaryObsidian;
                  } else if (isNegative) {
                    bg = AppColors.safetyRedBg;
                    text = AppColors.safetyRed;
                    border = AppColors.safetyRedBorder;
                  } else if (isPositive) {
                    bg = const Color(0xFFE6F4EA);
                    text = AppColors.safetyGreen;
                    border = const Color(0xFF34A853).withValues(alpha: 0.35);
                  }

                  final cleanToken = token.startsWith('Score:') ? 'Final $token' : token;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: border, width: 1.0),
                    ),
                    child: Text(
                      cleanToken,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: text,
                      ),
                    ),
                  );
                })
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisSourceBadge(String source) {
    final String label;
    final IconData icon;
    final Color color;

    switch (source) {
      case 'on_device_vision':
        label = 'Analyzed via On-Device Vision Engine';
        icon = Icons.bolt_rounded;
        color = AppColors.accentBronze;
        break;
      case 'backend_proxy':
        label = 'Analyzed via Cloud Vision Proxy';
        icon = Icons.cloud_done_rounded;
        color = AppColors.safetyGreen;
        break;
      case 'gemini_vision':
      default:
        label = 'Analyzed via Multimodal Vision AI';
        icon = Icons.auto_awesome_rounded;
        color = const Color(0xFF4285F4);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 1.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListenVerdictPill(bool isSpeaking) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleListenVerdict,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: isSpeaking
                ? AppColors.safetyRed.withValues(alpha: 0.12)
                : AppColors.accentBronze.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSpeaking
                  ? AppColors.safetyRed.withValues(alpha: 0.4)
                  : AppColors.accentBronze.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSpeaking ? Icons.stop_circle_rounded : Icons.volume_up_rounded,
                color: isSpeaking ? AppColors.safetyRed : AppColors.accentBronze,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                isSpeaking ? 'Stop Audio' : 'Listen to Verdict',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: isSpeaking ? AppColors.safetyRed : AppColors.accentBronze,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
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

  Widget _buildNutritionSectionHeader() {
    return Row(
      children: [
        const Icon(Icons.table_chart_outlined, size: 16, color: AppColors.textMutedMocha),
        const SizedBox(width: 6),
        const Text(
          'NUTRITION INFORMATION',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.textMutedMocha,
            letterSpacing: 0.5,
          ),
        ),
        const Spacer(),
        InkWell(
          onTap: _showEditNutritionSheet,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.cardBorder, width: 1.0),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_note_rounded, size: 15, color: AppColors.primaryObsidian),
                SizedBox(width: 4),
                Text(
                  'Edit / Verify',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryObsidian,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
            child: _buildPortionTab(
              mode: PortionMode.per100g,
              label: 'Per 100g (Label)',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildPortionTab(
              mode: PortionMode.perServing,
              label: '1 Serving (${_product.servingSizeG.toStringAsFixed(0)}g)',
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildPortionTab(
              mode: PortionMode.wholePack,
              label: 'Whole Pack (${_packWeight.toStringAsFixed(0)}g)',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortionTab({required PortionMode mode, required String label}) {
    final isSelected = _portionMode == mode;
    return GestureDetector(
      onTap: () {
        if (_portionMode != mode) setState(() => _portionMode = mode);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryObsidian : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : AppColors.textMutedMocha,
          ),
        ),
      ),
    );
  }

  Widget _buildSecondaryNutrientsGrid() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Secondary Extracted Nutrients',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMutedMocha,
                ),
              ),
              const Spacer(),
              Text(
                _portionMode == PortionMode.per100g
                    ? 'Per 100g'
                    : (_portionMode == PortionMode.perServing ? 'Per Serve (${_product.servingSizeG.toStringAsFixed(0)}g)' : 'Whole Pack (${_packWeight.toStringAsFixed(0)}g)'),
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentBronze,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildSecondaryNutrientTile('Added Sugar', '${_currentAddedSugarGrams.toStringAsFixed(1)} g')),
              const SizedBox(width: 8),
              Expanded(child: _buildSecondaryNutrientTile('Carbohydrates', '${_currentCarbsGrams.toStringAsFixed(1)} g')),
              const SizedBox(width: 8),
              Expanded(child: _buildSecondaryNutrientTile('Protein', '${_currentProteinGrams.toStringAsFixed(1)} g')),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _buildSecondaryNutrientTile('Dietary Fibre', '${_currentFiberGrams.toStringAsFixed(1)} g')),
              const SizedBox(width: 8),
              Expanded(child: _buildSecondaryNutrientTile('Trans Fat', '${_currentTransFatGrams.toStringAsFixed(1)} g')),
              const SizedBox(width: 8),
              Expanded(child: _buildSecondaryNutrientTile('Cholesterol', '${_currentCholesterolMg.toStringAsFixed(0)} mg')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryNutrientTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.textMutedMocha),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textObsidian),
          ),
        ],
      ),
    );
  }

  void _showEditNutritionSheet() {
    final calCtrl = TextEditingController(text: _product.effectiveCaloriesPer100g.toStringAsFixed(0));
    final sugarCtrl = TextEditingController(text: _product.sugarGPer100g.toStringAsFixed(1));
    final satFatCtrl = TextEditingController(text: _product.satFatGPer100g.toStringAsFixed(1));
    final sodiumCtrl = TextEditingController(text: _product.sodiumMgPer100g.toStringAsFixed(0));
    final proteinCtrl = TextEditingController(text: _product.proteinGPer100g.toStringAsFixed(1));
    final carbsCtrl = TextEditingController(text: _product.carbsGPer100g.toStringAsFixed(1));
    final fiberCtrl = TextEditingController(text: _product.fiberGPer100g.toStringAsFixed(1));
    final servingCtrl = TextEditingController(text: _product.servingSizeG.toStringAsFixed(0));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Verify & Edit Scanned Values',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.textObsidian),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Text(
                  'Values per 100g from physical package. Changing values recalculates Health Score live.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMutedMocha),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildEditField('Calories (kcal)', calCtrl)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildEditField('Total Sugar (g)', sugarCtrl)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildEditField('Sat. Fat (g)', satFatCtrl)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildEditField('Sodium (mg)', sodiumCtrl)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildEditField('Protein (g)', proteinCtrl)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildEditField('Carbs (g)', carbsCtrl)),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildEditField('Dietary Fibre (g)', fiberCtrl)),
                    const SizedBox(width: 10),
                    Expanded(child: _buildEditField('Serving Size (g)', servingCtrl)),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryObsidian,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      final newCal = double.tryParse(calCtrl.text) ?? _product.effectiveCaloriesPer100g;
                      final newSugar = double.tryParse(sugarCtrl.text) ?? _product.sugarGPer100g;
                      final newSatFat = double.tryParse(satFatCtrl.text) ?? _product.satFatGPer100g;
                      final newSodium = double.tryParse(sodiumCtrl.text) ?? _product.sodiumMgPer100g;
                      final newProtein = double.tryParse(proteinCtrl.text) ?? _product.proteinGPer100g;
                      final newCarbs = double.tryParse(carbsCtrl.text) ?? _product.carbsGPer100g;
                      final newFiber = double.tryParse(fiberCtrl.text) ?? _product.fiberGPer100g;
                      final newServing = double.tryParse(servingCtrl.text) ?? _product.servingSizeG;

                      final scoreRes = ProductHealthScorer.calculate(
                        nutrition: {
                          'energy_kcal': newCal,
                          'sugar_g_per_100g': newSugar,
                          'sat_fat_g_per_100g': newSatFat,
                          'sodium_mg_per_100g': newSodium,
                          'protein_g': newProtein,
                          'fiber_g': newFiber,
                          'carbohydrates_g_per_100g': newCarbs,
                        },
                        additives: _product.additives,
                        ingredients: _product.splitSugars,
                        novaGrade: _product.novaGrade,
                        redCapTriggered: _product.redCapTriggered,
                      );

                      setState(() {
                        _product = _product.copyWith(
                          caloriesPer100g: newCal,
                          caloriesPerServing: (newCal * (newServing / 100.0)).roundToDouble(),
                          sugarGPer100g: newSugar,
                          sugarGPerServing: double.parse((newSugar * (newServing / 100.0)).toStringAsFixed(1)),
                          satFatGPer100g: newSatFat,
                          satFatGPerServing: double.parse((newSatFat * (newServing / 100.0)).toStringAsFixed(1)),
                          sodiumMgPer100g: newSodium,
                          sodiumMgPerServing: (newSodium * (newServing / 100.0)).roundToDouble(),
                          proteinGPer100g: newProtein,
                          carbsGPer100g: newCarbs,
                          fiberGPer100g: newFiber,
                          servingSizeG: newServing,
                          healthScore: scoreRes.score,
                          verdictTag: scoreRes.verdictTag,
                          scoreBreakdown: scoreRes.scoreBreakdownSummary,
                        );
                      });
                      Navigator.pop(ctx);
                    },
                    child: const Text('Recalculate & Apply Values', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEditField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textMutedMocha)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.cardBorder)),
          ),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
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

  Widget _buildHealthierSwapsCTA() {
    return InkWell(
      onTap: _openHealthierSwaps,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFBF4E8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE89A3E).withValues(alpha: 0.45), width: 1.2),
        ),
        child: const Row(
          children: [
            Icon(Icons.swap_horiz_rounded, color: Color(0xFFC05621), size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Smart Healthier Clean Swaps',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textObsidian,
                    ),
                  ),
                  Text(
                    'Up to +48 higher health score • 1-tap quick delivery',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMutedMocha,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_rounded, color: Color(0xFFC05621), size: 20),
          ],
        ),
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

  Widget _buildMedicalPdfExportCard() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _isExportingPdf ? null : _exportMedicalReportPdf,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.accentBronze.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8C7A6B).withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.sugarPeachBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.accentBronze.withValues(alpha: 0.3)),
              ),
              child: _isExportingPdf
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentBronze),
                    )
                  : const Icon(Icons.picture_as_pdf_rounded, color: AppColors.accentBronze, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Doctor & Dietitian Health Report (PDF)',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textObsidian,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '1-Tap printable dossier with complete toxicology & safe limits',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMutedMocha,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryObsidian,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Export',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportMedicalReportPdf() async {
    unawaited(HapticFeedback.lightImpact());

    final pdfService = widget.pdfService ?? MedicalReportPdfService();

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.canvasCream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Icon(Icons.health_and_safety_rounded, color: AppColors.accentBronze, size: 24),
                SizedBox(width: 10),
                Text(
                  'Clinical Health Report (PDF)',
                  style: TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textObsidian,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Share or print this evidence-based clinical report with your consulting physician, endocrinologist, or registered dietitian.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textMutedMocha, height: 1.4),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      setState(() => _isExportingPdf = true);
                      try {
                        await pdfService.shareReport(
                          context: context,
                          product: widget.product,
                          userProfile: widget.userProfile,
                          currentServingGrams: _currentServingGrams,
                          currentSugarGrams: _currentSugarGrams,
                          currentCalories: _currentCalories,
                          currentSatFatGrams: _currentSatFatGrams,
                          currentSodiumMg: _currentSodiumMg,
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not share PDF: $e'),
                              backgroundColor: AppColors.safetyRed,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isExportingPdf = false);
                      }
                    },
                    icon: const Icon(Icons.share_rounded, size: 18),
                    label: const Text('Share PDF'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textObsidian,
                      side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      setState(() => _isExportingPdf = true);
                      try {
                        await pdfService.printReport(
                          context: context,
                          product: widget.product,
                          userProfile: widget.userProfile,
                          currentServingGrams: _currentServingGrams,
                          currentSugarGrams: _currentSugarGrams,
                          currentCalories: _currentCalories,
                          currentSatFatGrams: _currentSatFatGrams,
                          currentSodiumMg: _currentSodiumMg,
                        );
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Could not print PDF: $e'),
                              backgroundColor: AppColors.safetyRed,
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isExportingPdf = false);
                      }
                    },
                    icon: const Icon(Icons.print_rounded, size: 18),
                    label: const Text('Print / Save'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryObsidian,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
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
