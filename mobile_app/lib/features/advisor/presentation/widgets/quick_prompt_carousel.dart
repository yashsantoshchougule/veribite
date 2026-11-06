import 'package:flutter/material.dart';
import '../../domain/advisor_chat_model.dart';

/// Horizontally scrollable list of 1-tap starter prompts
/// designed to help users ask critical toxicology and dietary questions quickly.
class QuickPromptCarousel extends StatelessWidget {
  final ValueChanged<String> onPromptSelected;
  final ProductAdvisorContext? productContext;

  const QuickPromptCarousel({
    super.key,
    required this.onPromptSelected,
    this.productContext,
  });

  @override
  Widget build(BuildContext context) {
    final prompts = _buildContextualPrompts();

    return SizedBox(
      height: 38,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: prompts.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final prompt = prompts[index];
          return ActionChip(
            label: Text(
              prompt,
              style: const TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            avatar: const Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: Color(0xFF0F9D58),
            ),
            backgroundColor: const Color(0xFF1E293B),
            side: const BorderSide(color: Color(0xFF334155)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            onPressed: () => onPromptSelected(prompt),
          );
        },
      ),
    );
  }

  List<String> _buildContextualPrompts() {
    if (productContext != null) {
      final hasRedTier = productContext!.additives.any((a) => a['risk_tier'] == 'Red');
      final sugars = (productContext!.nutrition['sugars_100g'] as num?)?.toDouble() ?? 0.0;

      return [
        if (hasRedTier) 'Why are additives in this item flagged?',
        if (sugars > 15) 'Is this safe for my diabetic mother?',
        'What is the exact safe portion for my weight?',
        'Can kids eat this without hyperactivity risks?',
        'Explain all INS chemical codes',
        'Are there any hidden split sweeteners?',
      ];
    }

    return [
      'Is maltodextrin safe for daily consumption?',
      'How does WHO calculate free sugar limits?',
      'Why are synthetic food colors banned in Europe?',
      'What are split sugars in packaged biscuits?',
      'Safe additive guidelines for children under 10',
    ];
  }
}

