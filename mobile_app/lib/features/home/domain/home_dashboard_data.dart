import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../camera/application/product_scanner_service.dart';
import '../../profile/domain/user_profile_model.dart';

/// Single product item rendered in the Home Page carousel.
class DashboardProductItem {
  final String barcode;
  final String productName;
  final String brandName;
  final int healthScore;
  final String verdictTag;
  final String safePortion;
  final Color color;
  final ScannedProductResult? evaluatedProduct;

  const DashboardProductItem({
    required this.barcode,
    required this.productName,
    required this.brandName,
    required this.healthScore,
    required this.verdictTag,
    required this.safePortion,
    required this.color,
    this.evaluatedProduct,
  });

  factory DashboardProductItem.fromDatabaseRow(Map<String, dynamic> row) {
    final barcode = (row['barcode'] ?? '').toString();
    final productName = (row['product_name'] ?? 'Unknown Product').toString();
    final brandName = (row['brand_name'] ?? '').toString();
    final healthScore = (row['health_score'] is int)
        ? row['health_score'] as int
        : int.tryParse(row['health_score']?.toString() ?? '50') ?? 50;

    final redCap = row['red_cap_triggered'] == 1 || row['red_cap_triggered'] == true;
    final servingG = (row['serving_size_g'] is num)
        ? (row['serving_size_g'] as num).toDouble()
        : double.tryParse(row['serving_size_g']?.toString() ?? '30') ?? 30.0;

    // Determine Tag and Color based on Health Score & Red Cap
    Color color;
    String tag;
    if (redCap || healthScore < 30) {
      color = AppColors.safetyRed;
      tag = 'Capped 🔴';
    } else if (healthScore < 60) {
      color = AppColors.safetyAmber;
      tag = 'Caution 🟠';
    } else {
      color = AppColors.safetyGreen;
      tag = 'Nutri Safe 🟢';
    }

    // Determine Safe Portion text
    String portion;
    if (servingG > 0) {
      if (servingG >= 100) {
        portion = '${servingG.toStringAsFixed(0)} ml';
      } else {
        portion = '${servingG.toStringAsFixed(0)}g';
      }
    } else {
      portion = '1 Serving';
    }

    return DashboardProductItem(
      barcode: barcode,
      productName: productName,
      brandName: brandName,
      healthScore: healthScore,
      verdictTag: tag,
      safePortion: portion,
      color: color,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'barcode': barcode,
      'product_name': productName,
      'brand_name': brandName,
      'health_score': healthScore,
      'verdict_tag': verdictTag,
      'safe_portion': safePortion,
      'color_value': color.toARGB32(),
      if (evaluatedProduct != null) 'evaluated_product': evaluatedProduct!.toJson(),
    };
  }

  factory DashboardProductItem.fromCacheMap(Map<String, dynamic> map) {
    ScannedProductResult? evaluated;
    if (map['evaluated_product'] is Map<String, dynamic>) {
      try {
        evaluated = ScannedProductResult.fromJson(map['evaluated_product'] as Map<String, dynamic>);
      } catch (_) {}
    }

    return DashboardProductItem(
      barcode: map['barcode']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? 'Product',
      brandName: map['brand_name']?.toString() ?? '',
      healthScore: (map['health_score'] as num?)?.toInt() ?? 50,
      verdictTag: map['verdict_tag']?.toString() ?? 'Safe',
      safePortion: map['safe_portion']?.toString() ?? '1 Serving',
      color: Color(map['color_value'] is int ? map['color_value'] as int : 0xFF137333),
      evaluatedProduct: evaluated,
    );
  }
}

/// Aggregated live data snapshot for the Home Dashboard.
class HomeDashboardData {
  final double consumedSugarGrams;
  final double maxSugarGrams;
  final int redAdditivesToday;
  final List<DashboardProductItem> recentProducts;
  final bool isUserHistory;
  final int totalAdditivesCount;

  const HomeDashboardData({
    required this.consumedSugarGrams,
    required this.maxSugarGrams,
    required this.redAdditivesToday,
    required this.recentProducts,
    required this.isUserHistory,
    this.totalAdditivesCount = 6450,
  });

  double get percentSugarUsed {
    if (maxSugarGrams <= 0) return 0.0;
    final pct = consumedSugarGrams / maxSugarGrams;
    return pct.clamp(0.0, 1.5);
  }

  /// Curated default featured products backing the Home Dashboard carousel with real macro profiles
  static List<DashboardProductItem> get defaultFeaturedProducts {
    // 1. Orange Cream Biscuits (Score: 22, Capped 🔴, Portion: 20g, NOVA 4)
    const orangeCreamProduct = ScannedProductResult(
      barcode: '8901030383786',
      productName: 'Orange Cream Biscuits',
      brandName: 'Britannia Treat',
      category: 'Biscuits & Cookies',
      servingSizeG: 20.0,
      packWeightG: 100.0,
      caloriesPerServing: 97.0,
      caloriesPer100g: 485.0,
      sugarGPerServing: 6.4,
      sugarGPer100g: 32.0,
      carbsGPer100g: 68.0,
      totalFatGPer100g: 20.0,
      satFatGPer100g: 10.0,
      proteinGPer100g: 5.0,
      fiberGPer100g: 1.5,
      sodiumMgPer100g: 220.0,
      addedSugarGPer100g: 28.0,
      transFatGPer100g: 0.0,
      cholesterolMgPer100g: 0.0,
      healthScore: 22,
      novaGrade: 4,
      redCapTriggered: true,
      additives: [
        {
          'ins_code': '110',
          'primary_name': 'Sunset Yellow FCF',
          'risk_tier': 'RED',
          'hazard_tier': 'RED',
          'is_hazardous': true,
          'jecfa_adi_mg_kg': 4.0,
          'child_hyperactivity_flag': 1,
        },
        {
          'ins_code': '500(ii)',
          'primary_name': 'Sodium Carbonates',
          'risk_tier': 'GREEN',
        },
        {
          'ins_code': '503(ii)',
          'primary_name': 'Ammonium Carbonates',
          'risk_tier': 'GREEN',
        },
        {
          'ins_code': '322',
          'primary_name': 'Lecithins',
          'risk_tier': 'GREEN',
        },
      ],
      splitSugars: ['Sugar', 'Invert Sugar Syrup'],
      safePortionGrams: 20,
      limitingFactor: 'Sugar & Synthetic Azo Dye INS 110',
      verdictTag: 'Capped 🔴',
      frequencySchedule: 'Once a Month / Rare Treat',
      portionAdvice: 'High free sugar (32g/100g) and synthetic dye INS 110. Restrict to 1 biscuit (20g).',
      isExceededBudget: false,
    );

    // 2. 100% Wholegrain Rolled Oats (Score: 88, Nutri Safe 🟢, Portion: 40g, NOVA 1)
    const wholegrainOatsProduct = ScannedProductResult(
      barcode: '8901234567890',
      productName: '100% Wholegrain Rolled Oats',
      brandName: 'Quaker',
      category: 'Breakfast Cereals',
      servingSizeG: 40.0,
      packWeightG: 400.0,
      caloriesPerServing: 155.6,
      caloriesPer100g: 389.0,
      sugarGPerServing: 0.4,
      sugarGPer100g: 1.0,
      carbsGPer100g: 66.0,
      totalFatGPer100g: 6.9,
      satFatGPer100g: 1.2,
      proteinGPer100g: 13.5,
      fiberGPer100g: 10.6,
      sodiumMgPer100g: 6.0,
      addedSugarGPer100g: 0.0,
      transFatGPer100g: 0.0,
      cholesterolMgPer100g: 0.0,
      healthScore: 88,
      novaGrade: 1,
      redCapTriggered: false,
      additives: [],
      splitSugars: [],
      safePortionGrams: 40,
      limitingFactor: 'None - Clean Whole Food',
      verdictTag: 'Nutri Safe 🟢',
      frequencySchedule: 'Daily Safe Choice',
      portionAdvice: 'High in natural beta-glucan soluble fibre. Heart and diabetic safe daily baseline.',
      isExceededBudget: false,
    );

    // 3. Classic Salted Potato Chips (Score: 18, Capped 🔴, Portion: 30g, NOVA 4)
    const potatoChipsProduct = ScannedProductResult(
      barcode: '8901491101831',
      productName: 'Classic Salted Potato Chips',
      brandName: "Lay's",
      category: 'Chips & Crisps',
      servingSizeG: 30.0,
      packWeightG: 52.0,
      caloriesPerServing: 160.8,
      caloriesPer100g: 536.0,
      sugarGPerServing: 0.45,
      sugarGPer100g: 1.5,
      carbsGPer100g: 53.0,
      totalFatGPer100g: 34.0,
      satFatGPer100g: 14.0,
      proteinGPer100g: 6.5,
      fiberGPer100g: 4.0,
      sodiumMgPer100g: 680.0,
      addedSugarGPer100g: 0.0,
      transFatGPer100g: 0.1,
      cholesterolMgPer100g: 0.0,
      healthScore: 18,
      novaGrade: 4,
      redCapTriggered: true,
      additives: [],
      splitSugars: [],
      safePortionGrams: 30,
      limitingFactor: 'Saturated Fat & High Sodium',
      verdictTag: 'Capped 🔴',
      frequencySchedule: 'Once Every 2 Weeks',
      portionAdvice: 'Ultra-high saturated fat (14g/100g) and sodium (680mg/100g). Restrict to 1 small bowl.',
      isExceededBudget: false,
    );

    return const [
      DashboardProductItem(
        barcode: '8901030383786',
        productName: 'Orange Cream Biscuits',
        brandName: 'Britannia Treat',
        healthScore: 22,
        verdictTag: 'Capped 🔴',
        safePortion: '20g',
        color: AppColors.safetyRed,
        evaluatedProduct: orangeCreamProduct,
      ),
      DashboardProductItem(
        barcode: '8901234567890',
        productName: '100% Wholegrain Rolled Oats',
        brandName: 'Quaker',
        healthScore: 88,
        verdictTag: 'Nutri Safe 🟢',
        safePortion: '40g',
        color: AppColors.safetyGreen,
        evaluatedProduct: wholegrainOatsProduct,
      ),
      DashboardProductItem(
        barcode: '8901491101831',
        productName: 'Classic Salted Potato Chips',
        brandName: "Lay's",
        healthScore: 18,
        verdictTag: 'Capped 🔴',
        safePortion: '30g',
        color: AppColors.safetyRed,
        evaluatedProduct: potatoChipsProduct,
      ),
    ];
  }

  /// Default baseline when database is initializing or empty
  factory HomeDashboardData.defaults(UserProfileModel? profile) {
    final maxSugar = profile?.isDiabetic == true
        ? 10.0
        : (profile?.isChild == true ? 15.0 : 25.0);

    return HomeDashboardData(
      consumedSugarGrams: 0.0,
      maxSugarGrams: maxSugar,
      redAdditivesToday: 0,
      recentProducts: defaultFeaturedProducts,
      isUserHistory: false,
    );
  }
}

