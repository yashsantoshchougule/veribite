import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../camera/application/product_scanner_service.dart';
import '../../onboarding/presentation/widgets/watermark_painter.dart';
import '../../profile/domain/user_profile_model.dart';
import '../application/healthier_swaps_service.dart';
import '../domain/swap_alternative_model.dart';
import 'widgets/swap_alternative_card.dart';

/// Page 8: Smart Healthier Swaps & Quick-Commerce Integration
/// Recommends verified cleaner Indian alternatives for packaged foods with
/// positive score improvement banners and 1-tap quick delivery deep links.
class HealthierSwapsScreen extends StatefulWidget {
  final ScannedProductResult? currentProduct;
  final String? category;
  final UserProfileModel? userProfile;
  final HealthierSwapsService? swapsService;

  const HealthierSwapsScreen({
    super.key,
    this.currentProduct,
    this.category,
    this.userProfile,
    this.swapsService,
  });

  @override
  State<HealthierSwapsScreen> createState() => _HealthierSwapsScreenState();
}

class _HealthierSwapsScreenState extends State<HealthierSwapsScreen> {
  late final HealthierSwapsService _service;
  late final List<SwapAlternativeModel> _alternatives;

  @override
  void initState() {
    super.initState();
    _service = widget.swapsService ?? HealthierSwapsService();

    if (widget.currentProduct != null) {
      _alternatives = _service.getSwapsForProduct(widget.currentProduct!);
    } else {
      _alternatives = _service.getSwapsForCategory(widget.category ?? 'Snacks');
    }
  }

  void _showComparisonSheet(SwapAlternativeModel alternative) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.inactiveDot,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.compare_arrows_rounded, color: AppColors.accentBronze, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Side-by-Side Health Comparison',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textObsidian,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (widget.currentProduct != null) ...[
                _buildComparisonRow(
                  label: 'Health Score',
                  scannedVal: '${widget.currentProduct!.healthScore}/100',
                  swapVal: '${alternative.healthScore}/100 (+${alternative.scoreDelta})',
                  isBetter: true,
                ),
                _buildComparisonRow(
                  label: 'Sugar / Serving',
                  scannedVal: '${widget.currentProduct!.sugarGPerServing}g',
                  swapVal: '${alternative.sugarGPerServing}g',
                  isBetter: alternative.sugarGPerServing < widget.currentProduct!.sugarGPerServing,
                ),
                _buildComparisonRow(
                  label: 'Sodium / Serving',
                  scannedVal: '${widget.currentProduct!.sodiumMgPerServing.round()}mg',
                  swapVal: '${alternative.sodiumMgPerServing.round()}mg',
                  isBetter: alternative.sodiumMgPerServing < widget.currentProduct!.sodiumMgPerServing,
                ),
                _buildComparisonRow(
                  label: 'Chemical Additives',
                  scannedVal: '${widget.currentProduct!.additives.length} detected',
                  swapVal: '0 Red-tier toxins',
                  isBetter: true,
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Back to Swaps'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryObsidian,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComparisonRow({
    required String label,
    required String scannedVal,
    required String swapVal,
    required bool isBetter,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textMutedMocha),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              scannedVal,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.safetyRed),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              swapVal,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: isBetter ? AppColors.safetyMint : AppColors.textObsidian,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catName = widget.currentProduct?.category ?? widget.category ?? 'Healthy Foods';

    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      body: CustomPaint(
        painter: const WatermarkPainter(),
        child: SafeArea(
          child: Column(
            children: [
              _buildTopBar(catName),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      children: [
                        if (widget.currentProduct != null) _buildCurrentProductBanner(),
                        const SizedBox(height: 16),
                        _buildSectionHeader(),
                        const SizedBox(height: 12),
                        if (_alternatives.isEmpty)
                          _buildEmptySwaps()
                        else
                          ..._alternatives.map((alt) {
                            return SwapAlternativeCard(
                              alternative: alt,
                              onTap: () => _showComparisonSheet(alt),
                            );
                          }),
                      ],
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

  Widget _buildTopBar(String category) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder, width: 1.0)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textObsidian),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Smart Healthier Swaps',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textObsidian,
                  ),
                ),
                Text(
                  '$category • Verified Alternatives',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMutedMocha,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.safetyMintBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.safetyMintBorder),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.eco_rounded, size: 14, color: AppColors.safetyMint),
                SizedBox(width: 4),
                Text(
                  'Clean Label',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.safetyMint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentProductBanner() {
    final prod = widget.currentProduct!;
    final isRed = prod.healthScore < 40 || prod.redCapTriggered;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isRed ? const Color(0xFFFDF2F2) : const Color(0xFFFFF9F0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isRed ? const Color(0xFFF5B8B8) : const Color(0xFFF5D6B8),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRed ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                color: isRed ? AppColors.safetyRed : const Color(0xFFC05621),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Currently Scanned: ${prod.productName}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textObsidian,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isRed ? AppColors.safetyRed : const Color(0xFFC05621),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Score: ${prod.healthScore}/100',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isRed
                ? 'High risk profile detected due to ${prod.limitingFactor.toLowerCase()} constraints and industrial additives. Swap with verified whole-grain alternatives below for immediate health point gains.'
                : 'Consider upgrading to cleaner, less refined alternatives with higher nutrient density and zero chemical leavening agents.',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textMutedMocha,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Top Cleaner Alternatives (${_alternatives.length})',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textObsidian,
            ),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Tap card to compare',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.accentBronze,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptySwaps() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Center(
        child: Text(
          'No specific alternatives found for this food item.\nAlways look for zero added sugar and whole grain options.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMutedMocha, fontSize: 13),
        ),
      ),
    );
  }
}
