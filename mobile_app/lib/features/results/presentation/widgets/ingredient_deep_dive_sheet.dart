import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/ingredient_detail_model.dart';

/// Page 8: Ingredients Deep Dive Modal
/// Displays comprehensive toxicology, manufacturer rationale, weight-scaled ADI, and verified official citations.
class IngredientDeepDiveSheet extends StatelessWidget {
  final IngredientDetailModel ingredient;
  final double userWeightKg;

  const IngredientDeepDiveSheet({
    super.key,
    required this.ingredient,
    this.userWeightKg = 65.0,
  });

  static Future<void> show(
    BuildContext context, {
    required IngredientDetailModel ingredient,
    double userWeightKg = 65.0,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => IngredientDeepDiveSheet(
        ingredient: ingredient,
        userWeightKg: userWeightKg,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalAdiMg = ingredient.calculateTotalSafeAdiMg(userWeightKg);

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
              // Top drag pill
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

              // Title, INS Code & Risk Tier Pill
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ingredient.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textObsidian,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (ingredient.insCode != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            '${ingredient.insCode} • ${ingredient.category}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMutedMocha,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: ingredient.riskTier.backgroundColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: ingredient.riskTier.color.withValues(alpha: 0.3),
                        width: 1.2,
                      ),
                    ),
                    child: Text(
                      ingredient.riskTier.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: ingredient.riskTier.color,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 1. Why Manufacturers Add It
              _buildSectionCard(
                icon: Icons.factory_outlined,
                title: 'Why Manufacturers Add It',
                body: ingredient.purpose,
                accentColor: AppColors.accentBronze,
              ),

              const SizedBox(height: 14),

              // 2. Health Risks & Toxicology
              _buildSectionCard(
                icon: Icons.health_and_safety_outlined,
                title: 'Health Impacts & Toxicology',
                body: ingredient.healthConcerns,
                accentColor: ingredient.riskTier.color,
                highlightBorder: ingredient.riskTier == RiskTier.red,
              ),

              const SizedBox(height: 14),

              // 3. JECFA Acceptable Daily Intake (ADI)
              _buildSectionCard(
                icon: Icons.balance_outlined,
                title: 'Acceptable Daily Intake (ADI)',
                body: totalAdiMg != null
                    ? 'Official JECFA ADI is ${ingredient.safeAdiMgPerKg} mg/kg body weight.\n'
                        'Scaled for your ${userWeightKg.toStringAsFixed(0)} kg body weight: '
                        'Maximum safe daily intake is ${totalAdiMg.toStringAsFixed(0)} mg/day.'
                    : 'JECFA Evaluation: "ADI Not Specified" — Evaluated as safe without requiring a numeric daily intake threshold under Good Manufacturing Practice.',
                accentColor: AppColors.accentBronze,
              ),

              // 4. International Bans & Regulatory Alerts (if any)
              if (ingredient.internationalBans.isNotEmpty) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFCE8E6),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.safetyRed.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.gavel_rounded, size: 16, color: AppColors.safetyRed),
                          SizedBox(width: 8),
                          Text(
                            'International Bans & Restrictions',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.safetyRed,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      for (final ban in ingredient.internationalBans)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ', style: TextStyle(color: AppColors.safetyRed, fontWeight: FontWeight.bold)),
                              Expanded(
                                child: Text(
                                  ban,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textObsidian,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],

              // 5. Verified Regulatory Scientific Citation
              if (ingredient.citationSource != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.cardSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.cardBorder, width: 1.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.menu_book_rounded, size: 16, color: AppColors.accentBronze),
                          SizedBox(width: 8),
                          Text(
                            'Verified Official Citation',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textObsidian,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        ingredient.citationSource!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.accentBronze,
                        ),
                      ),
                      if (ingredient.citationQuote != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.canvasCream,
                            borderRadius: BorderRadius.circular(10),
                            border: const Border(
                              left: BorderSide(color: AppColors.accentBronze, width: 3),
                            ),
                          ),
                          child: Text(
                            ingredient.citationQuote!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textObsidian,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Close / Done CTA
              SizedBox(
                height: 48,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primaryObsidian,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text(
                    'Got It',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required String body,
    required Color accentColor,
    bool highlightBorder = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlightBorder ? accentColor.withValues(alpha: 0.4) : AppColors.cardBorder,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: accentColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textObsidian,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: AppColors.textObsidian,
            ),
          ),
        ],
      ),
    );
  }
}
