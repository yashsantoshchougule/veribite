import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../camera/application/product_scanner_service.dart';

/// Type of catalog item: Food product or Chemical additive
enum CatalogItemType {
  food,
  additive,
}

/// Unified model for items displayed in the VeriBite Search Catalog.
/// Seamlessly represents both packaged food products (from Open Food Facts / SQLite Cache)
/// and chemical additives (from SQLite FTS5 database).
class SearchCatalogItem {
  final String id;
  final CatalogItemType type;
  final String title;
  final String subtitle;
  final String code; // Barcode or INS code
  final int? healthScore;
  final String? riskTier; // 'SAFE', 'CAUTION', 'RED'
  final String verdictTag;
  final Color color;
  final String? imageUrl;
  final double? jecfaAdi;
  final String? functionalClass;
  final String? bannedJurisdictions;
  final bool childHyperactivityFlag;
  final bool isOffline;
  final ScannedProductResult? evaluatedProduct;
  final Map<String, dynamic>? rawProductData;

  const SearchCatalogItem({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.code,
    this.healthScore,
    this.riskTier,
    required this.verdictTag,
    required this.color,
    this.imageUrl,
    this.jecfaAdi,
    this.functionalClass,
    this.bannedJurisdictions,
    this.childHyperactivityFlag = false,
    this.isOffline = false,
    this.evaluatedProduct,
    this.rawProductData,
  });

  bool get isFood => type == CatalogItemType.food;
  bool get isAdditive => type == CatalogItemType.additive;

  /// Creates a food item from Open Food Facts or local database
  factory SearchCatalogItem.food({
    required String barcode,
    required String productName,
    required String brandName,
    String? category,
    int? score,
    int? novaGroup,
    String? imageUrl,
    bool isOffline = false,
    ScannedProductResult? evaluatedProduct,
    Map<String, dynamic>? rawProductData,
  }) {
    final effectiveScore = evaluatedProduct?.healthScore ?? score ?? 82;
    final Color color;
    final String verdictTag;

    if (evaluatedProduct != null) {
      verdictTag = evaluatedProduct.verdictTag;
      if (effectiveScore < 40 || evaluatedProduct.redCapTriggered) {
        color = AppColors.safetyRed;
      } else if (effectiveScore < 70) {
        color = AppColors.safetyAmber;
      } else {
        color = AppColors.safetyGreen;
      }
    } else {
      if (effectiveScore < 40) {
        color = AppColors.safetyRed;
        verdictTag = 'Toxic / Capped 🔴';
      } else if (effectiveScore < 70) {
        color = AppColors.safetyAmber;
        verdictTag = 'Caution 🟠';
      } else {
        color = AppColors.safetyGreen;
        verdictTag = 'Nutri Safe 🟢';
      }
    }

    final catText = category != null && category.isNotEmpty ? ' • $category' : '';

    return SearchCatalogItem(
      id: barcode,
      type: CatalogItemType.food,
      title: productName,
      subtitle: '$brandName$catText',
      code: barcode,
      healthScore: effectiveScore,
      verdictTag: verdictTag,
      color: color,
      imageUrl: imageUrl,
      isOffline: isOffline,
      evaluatedProduct: evaluatedProduct,
      rawProductData: rawProductData,
    );
  }

  /// Creates an additive chemical item from SQLite FTS5 database
  factory SearchCatalogItem.additive({
    required String insCode,
    String? eCode,
    required String primaryName,
    String? functionalClass,
    required String riskTier,
    bool triggersRedCap = false,
    double? jecfaAdi,
    String? bannedJurisdictions,
    bool childHyperactivityFlag = false,
  }) {
    final cleanRisk = riskTier.toUpperCase();
    final Color color;
    final String verdictTag;

    if (cleanRisk == 'RED' || triggersRedCap) {
      color = AppColors.safetyRed;
      verdictTag = 'Red Flag 🔴';
    } else if (cleanRisk == 'CAUTION') {
      color = AppColors.safetyAmber;
      verdictTag = 'Caution 🟠';
    } else {
      color = AppColors.safetyGreen;
      verdictTag = 'Safe 🟢';
    }

    final eStr = eCode != null && eCode.isNotEmpty ? ' / $eCode' : '';
    final codeDisplay = 'INS $insCode$eStr';
    final funcDisplay = functionalClass != null && functionalClass.isNotEmpty
        ? functionalClass
        : 'Food Additive';

    return SearchCatalogItem(
      id: insCode,
      type: CatalogItemType.additive,
      title: primaryName,
      subtitle: '$codeDisplay • $funcDisplay',
      code: insCode,
      riskTier: cleanRisk,
      verdictTag: verdictTag,
      color: color,
      jecfaAdi: jecfaAdi,
      functionalClass: functionalClass,
      bannedJurisdictions: bannedJurisdictions,
      childHyperactivityFlag: childHyperactivityFlag,
      isOffline: true,
    );
  }
}

