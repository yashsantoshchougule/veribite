import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/product_scanner_service.dart';

/// Modal bottom sheet presenting resolved product toxicology, safe portion limits,
/// and dual actions ("Log as Eaten" vs. "Just Checking").
class ScanResultSheet extends StatelessWidget {
  final ScannedProductResult product;
  final VoidCallback onLogConsumed;
  final VoidCallback onDismissWithoutLog;

  const ScanResultSheet({
    super.key,
    required this.product,
    required this.onLogConsumed,
    required this.onDismissWithoutLog,
  });

  @override
  Widget build(BuildContext context) {
    Color gradeColor;
    Color gradeBg;
    if (product.healthScore >= 70 && !product.redCapTriggered) {
      gradeColor = AppColors.safetyGreen;
      gradeBg = const Color(0xFFE6F4EA);
    } else if (product.healthScore >= 40 && !product.redCapTriggered) {
      gradeColor = AppColors.safetyAmber;
      gradeBg = const Color(0xFFFEF7E0);
    } else {
      gradeColor = AppColors.safetyRed;
      gradeBg = const Color(0xFFFCE8E6);
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.canvasCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  width: 40,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Product Title, Brand & Barcode
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.productName,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textObsidian,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${product.brandName} • ${product.category}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMutedMocha,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Health Score & Grade Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: gradeBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: gradeColor.withValues(alpha: 0.3), width: 1.2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '${product.healthScore}',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: gradeColor,
                            height: 1.1,
                          ),
                        ),
                        Text(
                          product.verdictTag.split(' ').first,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            color: gradeColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Safe Portion Prescription Card
              Container(
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
                            'Safe Portion Prescription',
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
                      product.portionAdvice,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: AppColors.textObsidian,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8C7A6B).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Frequency: ${product.frequencySchedule}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.accentBronze,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'NOVA ${product.novaGrade}',
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
              ),

              if (product.isExceededBudget) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE8E6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.safetyRed.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.safetyRed),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '1 serving contains ${product.sugarGPerServing}g free sugar, which exceeds your safe daily ceiling!',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.safetyRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Nutrition Highlights Grid (4 Pills)
              Row(
                children: [
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Sugar / Serving',
                      value: '${product.sugarGPerServing}g',
                      subtext: '${product.sugarGPer100g}g / 100g',
                      highlight: product.sugarGPerServing > 5.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildMetricTile(
                      label: 'Calories',
                      value: '${product.caloriesPerServing} kcal',
                      subtext: 'Serving: ${product.servingSizeG.toStringAsFixed(0)}g',
                    ),
                  ),
                ],
              ),

              if (product.splitSugars.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E6),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFFD591)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.bubble_chart_outlined, size: 16, color: Color(0xFFD46B08)),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Hidden Split Sugar Aliases Detected',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFD46B08),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.splitSugars.join(', '),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF873800),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (product.additives.isNotEmpty) ...[
                const SizedBox(height: 14),
                const Text(
                  'Declared Chemical Additives (INS / E-numbers)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textObsidian,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: product.additives.map((add) {
                    final code = add['ins_code']?.toString() ?? '';
                    final name = add['primary_name']?.toString() ?? 'Additive';
                    final tier = add['risk_tier']?.toString().toUpperCase() ?? 'GREEN';
                    final isRed = tier == 'RED';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isRed ? const Color(0xFFFCE8E6) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isRed ? AppColors.safetyRed : AppColors.cardBorder,
                          width: 1.1,
                        ),
                      ),
                      child: Text(
                        'INS $code: $name',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isRed ? AppColors.safetyRed : AppColors.textObsidian,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 22),

              // Dual Action Decision Buttons: "I Ate This" vs. "Just Checking"
              SizedBox(
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: onLogConsumed,
                  icon: const Icon(Icons.restaurant_rounded, size: 18, color: Colors.white),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'I Ate This (Add to Today\'s Sugar Budget)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryObsidian,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    elevation: 0,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: onDismissWithoutLog,
                  icon: const Icon(Icons.visibility_outlined, size: 17, color: AppColors.textObsidian),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Just Checking (Don\'t Add to Budget)',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textObsidian,
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subtext,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlight ? AppColors.safetyAmber : AppColors.cardBorder,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMutedMocha,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: highlight ? AppColors.safetyAmber : AppColors.textObsidian,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              subtext,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w500,
                color: AppColors.textMutedMocha,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
