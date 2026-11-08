/// Model representing a healthier alternative packaged food item for clean swaps
class SwapAlternativeModel {
  final String barcode;
  final String productName;
  final String brandName;
  final String category;
  final int healthScore;
  final int scoreDelta; // e.g. +46 over baseline product
  final int brandTier; // 1 = Commercial, 2 = Established National, 3 = Certified Clean / Organic / Artisanal
  final List<String> keyAdvantages;
  final double servingSizeG;
  final double sugarGPerServing;
  final double satFatGPerServing;
  final double sodiumMgPerServing;
  final String quickCommerceQuery;

  const SwapAlternativeModel({
    required this.barcode,
    required this.productName,
    required this.brandName,
    required this.category,
    required this.healthScore,
    required this.scoreDelta,
    this.brandTier = 3,
    required this.keyAdvantages,
    required this.servingSizeG,
    required this.sugarGPerServing,
    required this.satFatGPerServing,
    required this.sodiumMgPerServing,
    required this.quickCommerceQuery,
  });

  String get brandTierLabel {
    switch (brandTier) {
      case 3:
        return 'Tier 3 • Certified Clean / Organic';
      case 2:
        return 'Tier 2 • Established High Grade';
      default:
        return 'Tier 1 • Commercial';
    }
  }
}

enum QuickCommercePlatform {
  blinkit,
  zepto,
  instamart,
  bigbasket,
}

