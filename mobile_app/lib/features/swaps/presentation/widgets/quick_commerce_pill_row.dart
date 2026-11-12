import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../application/healthier_swaps_service.dart';
import '../../domain/swap_alternative_model.dart';

/// Row of 1-tap quick-commerce delivery buttons (Blinkit, Zepto, Instamart, BigBasket)
class QuickCommercePillRow extends StatelessWidget {
  final String searchQuery;
  final HealthierSwapsService? swapsService;

  const QuickCommercePillRow({
    super.key,
    required this.searchQuery,
    this.swapsService,
  });

  @override
  Widget build(BuildContext context) {
    final service = swapsService ?? HealthierSwapsService();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.bolt_rounded, size: 14, color: AppColors.accentBronze),
            SizedBox(width: 4),
            Text(
              '1-Tap Quick Delivery:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMutedMocha,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _buildStorePill(
              context: context,
              label: 'Blinkit',
              bgColor: const Color(0xFFFFF9E6),
              borderColor: const Color(0xFFF7D154),
              textColor: const Color(0xFF8A6D00),
              icon: Icons.electric_bolt_rounded,
              onTap: () async {
                await HapticFeedback.lightImpact();
                final ok = await service.launchStore(QuickCommercePlatform.blinkit, searchQuery);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open Blinkit. Please check your browser or network connection.')),
                  );
                }
              },
            ),
            _buildStorePill(
              context: context,
              label: 'Zepto',
              bgColor: const Color(0xFFF3EBFF),
              borderColor: const Color(0xFFD3B0FF),
              textColor: const Color(0xFF6723B8),
              icon: Icons.flash_on_rounded,
              onTap: () async {
                await HapticFeedback.lightImpact();
                final ok = await service.launchStore(QuickCommercePlatform.zepto, searchQuery);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open Zepto. Please check your browser or network connection.')),
                  );
                }
              },
            ),
            _buildStorePill(
              context: context,
              label: 'Instamart',
              bgColor: const Color(0xFFFFF0E6),
              borderColor: const Color(0xFFFFB380),
              textColor: const Color(0xFFCC4400),
              icon: Icons.delivery_dining_rounded,
              onTap: () async {
                await HapticFeedback.lightImpact();
                final ok = await service.launchStore(QuickCommercePlatform.instamart, searchQuery);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open Swiggy Instamart. Please check your browser or network connection.')),
                  );
                }
              },
            ),
            _buildStorePill(
              context: context,
              label: 'BigBasket',
              bgColor: const Color(0xFFEDF7ED),
              borderColor: const Color(0xFFA5D6A7),
              textColor: const Color(0xFF1B5E20),
              icon: Icons.shopping_basket_rounded,
              onTap: () async {
                await HapticFeedback.lightImpact();
                final ok = await service.launchStore(QuickCommercePlatform.bigbasket, searchQuery);
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open BigBasket. Please check your browser or network connection.')),
                  );
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStorePill({
    required BuildContext context,
    required String label,
    required Color bgColor,
    required Color borderColor,
    required Color textColor,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: textColor),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_outward_rounded, size: 10, color: textColor.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}
