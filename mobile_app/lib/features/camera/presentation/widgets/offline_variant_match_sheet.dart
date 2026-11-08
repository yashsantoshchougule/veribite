import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Intelligent bottom sheet presented when an offline barcode scan does not have
/// an exact 13-digit match, but matches the GS1 manufacturer prefix / brand siblings
/// in the local offline database.
class OfflineVariantMatchSheet extends StatelessWidget {
  final String barcode;
  final String brandName;
  final List<Map<String, dynamic>> siblingProducts;
  final void Function(Map<String, dynamic> product) onSelectProduct;
  final VoidCallback onScanOcr;
  final VoidCallback onManualEntry;

  const OfflineVariantMatchSheet({
    super.key,
    required this.barcode,
    required this.brandName,
    required this.siblingProducts,
    required this.onSelectProduct,
    required this.onScanOcr,
    required this.onManualEntry,
  });

  Color _getScoreColor(int score) {
    if (score >= 70) return AppColors.safetyGreen;
    if (score >= 40) return AppColors.safetyAmber;
    return AppColors.safetyRed;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: AppColors.cardBorder, width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.scanBracketGold.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.scanBracketGold.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.hub_rounded, color: AppColors.scanBracketGold, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.scanBracketGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'GS1 PREFIX MATCH: $brandName',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: AppColors.textObsidian,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Offline Pack-Size Variant Match',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textObsidian,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          Text(
            'Exact barcode "$barcode" is a new pack-size or variant. Per-100g nutrition & additives are typically identical across sizes for this brand. Select your matching product below to evaluate offline:',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMutedMocha,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          // Sibling products list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: siblingProducts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final product = siblingProducts[index];
                final name = product['product_name']?.toString() ?? 'Packaged Food';
                final category = product['category']?.toString() ?? 'Food';
                final packWeight = (product['pack_weight_g'] as num?)?.toDouble() ?? 100.0;
                final score = (product['health_score'] as num?)?.toInt() ?? 50;
                final scoreColor = _getScoreColor(score);
                final nova = (product['nova_grade'] as num?)?.toInt() ?? 3;

                return InkWell(
                  onTap: () => onSelectProduct(product),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.cardBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Health score circle
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scoreColor.withValues(alpha: 0.12),
                            border: Border.all(color: scoreColor.withValues(alpha: 0.4), width: 1.5),
                          ),
                          child: Text(
                            '$score',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: scoreColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Title and info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textObsidian,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Text(
                                    category,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMutedMocha,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 3,
                                    height: 3,
                                    decoration: const BoxDecoration(
                                      color: Colors.black26,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${packWeight.toInt()}g',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMutedMocha,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.stepPillBg,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'NOVA $nova',
                                      style: const TextStyle(
                                        fontSize: 9.5,
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
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMutedMocha),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Secondary actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onScanOcr,
                  icon: const Icon(Icons.document_scanner_rounded, size: 16),
                  label: const Text(
                    'Scan Label (OCR)',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textObsidian,
                    side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onManualEntry,
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: const Text(
                    'Enter Macros',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textObsidian,
                    side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
