import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/swap_alternative_model.dart';
import 'quick_commerce_pill_row.dart';

/// Card presenting a healthier Indian alternative with score improvement delta and clean advantages
class SwapAlternativeCard extends StatelessWidget {
  final SwapAlternativeModel alternative;
  final VoidCallback? onTap;

  const SwapAlternativeCard({
    super.key,
    required this.alternative,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8C7A6B).withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Score Badge + Title + Score Diff Banner
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Health score circular gauge badge
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.safetyMintBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.safetyMintBorder, width: 1.2),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${alternative.healthScore}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: AppColors.safetyMint,
                              height: 1.0,
                            ),
                          ),
                          const Text(
                            '/100',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: AppColors.safetyMint,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alternative.productName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textObsidian,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            runSpacing: 2,
                            children: [
                              Text(
                                '${alternative.brandName} • ${alternative.category}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMutedMocha,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: alternative.brandTier == 3
                                      ? const Color(0xFFE6F4EA)
                                      : const Color(0xFFE8F0FE),
                                  borderRadius: BorderRadius.circular(5),
                                  border: Border.all(
                                    color: alternative.brandTier == 3
                                        ? const Color(0xFF34A853)
                                        : const Color(0xFF4285F4),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  alternative.brandTier == 3 ? 'Clean Certified' : 'High Grade',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: alternative.brandTier == 3
                                        ? const Color(0xFF137333)
                                        : const Color(0xFF1967D2),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Improvement Score Delta Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F4EA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFF34A853), width: 1.0),
                      ),
                      child: Text(
                        '+${alternative.scoreDelta} PTS',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF137333),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Key Clean Advantage Badges
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: alternative.keyAdvantages.map((adv) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: AppColors.stepPillBg,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: AppColors.stepPillBorder),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 12, color: AppColors.safetyMint),
                          const SizedBox(width: 4),
                          Text(
                            adv,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textObsidian,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),

                // Macro summary bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppColors.canvasCream,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMacroStat('Sugar', '${alternative.sugarGPerServing}g'),
                      _buildVerticalDivider(),
                      _buildMacroStat('Sat. Fat', '${alternative.satFatGPerServing}g'),
                      _buildVerticalDivider(),
                      _buildMacroStat('Sodium', '${alternative.sodiumMgPerServing.round()}mg'),
                      _buildVerticalDivider(),
                      _buildMacroStat('Serving', '${alternative.servingSizeG.round()}g'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 1-Tap Quick-Commerce Delivery Action
                QuickCommercePillRow(searchQuery: alternative.quickCommerceQuery),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMacroStat(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textMutedMocha),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppColors.textObsidian),
        ),
      ],
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 18,
      color: AppColors.cardBorder,
    );
  }
}

