import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../camera/application/product_scanner_service.dart';
import '../../onboarding/presentation/widgets/watermark_painter.dart';
import '../../profile/domain/user_profile_model.dart';
import '../domain/ingredient_detail_model.dart';
import 'widgets/ingredient_deep_dive_sheet.dart';

/// Page 7: Granular Ingredients & Additives Breakdown Screen
/// Displays split-sugar clusters, safety filter chips, and interactive toxicology cards.
class IngredientBreakdownScreen extends StatefulWidget {
  final ScannedProductResult product;
  final UserProfileModel userProfile;

  const IngredientBreakdownScreen({
    super.key,
    required this.product,
    required this.userProfile,
  });

  @override
  State<IngredientBreakdownScreen> createState() => _IngredientBreakdownScreenState();
}

class _IngredientBreakdownScreenState extends State<IngredientBreakdownScreen> {
  String _activeFilter = 'All';
  late final List<IngredientDetailModel> _allIngredients;

  @override
  void initState() {
    super.initState();
    _allIngredients = _buildIngredientList();
  }

  List<IngredientDetailModel> _buildIngredientList() {
    final list = <IngredientDetailModel>[];

    // 1. Process structured additives from scan result
    for (final raw in widget.product.additives) {
      list.add(IngredientDetailModel.fromRawMap(raw));
    }

    // 2. Add split sugars if not already in list
    for (final sugar in widget.product.splitSugars) {
      if (!list.any((item) => item.name.toLowerCase() == sugar.toLowerCase())) {
        list.add(
          IngredientDetailModel(
            name: sugar,
            riskTier: RiskTier.caution,
            category: 'Sweetener Alias',
            triggersRedCap: false,
            purpose: 'Industrial sweetener added to sweeten the product while avoiding a single high "Sugar" label position.',
            healthConcerns: 'Concentrated simple sugars spike blood glucose rapidly and contribute to insulin resistance and caloric surplus.',
            safeAdiMgPerKg: null,
            internationalBans: const [],
            citationSource: 'WHO Guideline: Sugars intake for adults and children (2015)',
            citationQuote: '"Free sugars include monosaccharides and disaccharides added to foods and beverages by the manufacturer."',
          ),
        );
      }
    }

    // Fallback if list is empty
    if (list.isEmpty) {
      list.add(
        const IngredientDetailModel(
          name: 'Whole Grain Ingredients',
          riskTier: RiskTier.safe,
          category: 'Natural Whole Food',
          purpose: 'Provides natural complex carbohydrates, dietary fiber, and essential micronutrients.',
          healthConcerns: 'Nutritious unrefined whole food ingredient with positive metabolic health index.',
        ),
      );
    }

    return list;
  }

  List<IngredientDetailModel> get _filteredIngredients {
    if (_activeFilter == 'Red Flags') {
      return _allIngredients.where((i) => i.riskTier == RiskTier.red).toList();
    } else if (_activeFilter == 'Caution') {
      return _allIngredients.where((i) => i.riskTier == RiskTier.caution).toList();
    } else if (_activeFilter == 'Safe') {
      return _allIngredients.where((i) => i.riskTier == RiskTier.safe).toList();
    }
    return _allIngredients;
  }

  @override
  Widget build(BuildContext context) {
    final redCount = _allIngredients.where((i) => i.riskTier == RiskTier.red).length;
    final cautionCount = _allIngredients.where((i) => i.riskTier == RiskTier.caution).length;
    final safeCount = _allIngredients.where((i) => i.riskTier == RiskTier.safe).length;

    return Scaffold(
      backgroundColor: AppColors.canvasCream,
      body: CustomPaint(
        painter: const WatermarkPainter(),
        child: SafeArea(
          child: Column(
            children: [
              // Top Navigation Bar
              _buildTopBar(),

              // Scrollable Content
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      children: [
                        // Summary Stats Bar
                        _buildSummaryStatsCard(redCount, cautionCount, safeCount),

                        const SizedBox(height: 14),

                        // Split-Sugar Warning Cluster Banner
                        if (widget.product.splitSugars.isNotEmpty) ...[
                          _buildSplitSugarBanner(),
                          const SizedBox(height: 14),
                        ],

                        // Filter Chips
                        _buildFilterChips(redCount, cautionCount, safeCount),

                        const SizedBox(height: 14),

                        // Ingredients List Cards
                        for (final ingredient in _filteredIngredients)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildIngredientCard(ingredient),
                          ),

                        const SizedBox(height: 24),
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

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
              tooltip: 'Back to Verdict',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ingredients & Toxicology',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textObsidian,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  '${widget.product.productName} • ${widget.product.brandName}',
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
        ],
      ),
    );
  }

  Widget _buildSummaryStatsCard(int redCount, int cautionCount, int safeCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cardBorder, width: 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatPill('Total Detected', _allIngredients.length.toString(), AppColors.textObsidian),
          Container(width: 1, height: 28, color: AppColors.cardBorder),
          _buildStatPill('Red Flags', redCount.toString(), AppColors.safetyRed),
          Container(width: 1, height: 28, color: AppColors.cardBorder),
          _buildStatPill('Caution', cautionCount.toString(), AppColors.safetyAmber),
          Container(width: 1, height: 28, color: AppColors.cardBorder),
          _buildStatPill('Clean', safeCount.toString(), AppColors.safetyGreen),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: color),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textMutedMocha),
        ),
      ],
    );
  }

  Widget _buildSplitSugarBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF7E0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.safetyAmber.withValues(alpha: 0.35), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.safetyAmber),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Anti-Splitting Sweetener Cluster Alert',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB06000),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'This product splits sugar across ${widget.product.splitSugars.length} distinct sweetener aliases: '
            '${widget.product.splitSugars.join(", ")}. '
            'By splitting aliases, manufacturers prevent "Sugar" from appearing as the #1 item on the ingredients list.',
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textObsidian,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(int redCount, int cautionCount, int safeCount) {
    final filters = [
      {'label': 'All', 'count': _allIngredients.length},
      {'label': 'Red Flags', 'count': redCount},
      {'label': 'Caution', 'count': cautionCount},
      {'label': 'Safe', 'count': safeCount},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final f in filters)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text('${f['label']} (${f['count']})'),
                selected: _activeFilter == f['label'],
                selectedColor: AppColors.stepPillBg,
                backgroundColor: AppColors.cardSurface,
                side: BorderSide(
                  color: _activeFilter == f['label'] ? AppColors.accentBronze : AppColors.cardBorder,
                  width: 1.0,
                ),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _activeFilter == f['label'] ? AppColors.textObsidian : AppColors.textMutedMocha,
                ),
                onSelected: (val) {
                  if (val) setState(() => _activeFilter = f['label'] as String);
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIngredientCard(IngredientDetailModel item) {
    return InkWell(
      onTap: () => IngredientDeepDiveSheet.show(
        context,
        ingredient: item,
        userWeightKg: widget.userProfile.weightKg,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: item.triggersRedCap ? AppColors.safetyRed.withValues(alpha: 0.4) : AppColors.cardBorder,
            width: item.triggersRedCap ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Left color-coded indicator pill
            Container(
              width: 5,
              height: 44,
              decoration: BoxDecoration(
                color: item.riskTier.color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            // Middle Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textObsidian,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: item.riskTier.backgroundColor,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          item.riskTier.displayName.split(' ').first,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: item.riskTier.color,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.insCode != null ? '${item.insCode} • ${item.category}' : item.category,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMutedMocha,
                    ),
                  ),
                  if (item.triggersRedCap) ...[
                    const SizedBox(height: 4),
                    const Text(
                      '🚨 Triggers 39/100 Toxic Red-Cap',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.safetyRed,
                      ),
                    ),
                  ],
                  if (item.internationalBans.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '⚠️ ${item.internationalBans.first}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.safetyRed,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textMutedMocha, size: 20),
          ],
        ),
      ),
    );
  }
}
