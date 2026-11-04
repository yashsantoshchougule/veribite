import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
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

  const DashboardProductItem({
    required this.barcode,
    required this.productName,
    required this.brandName,
    required this.healthScore,
    required this.verdictTag,
    required this.safePortion,
    required this.color,
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
    };
  }

  factory DashboardProductItem.fromCacheMap(Map<String, dynamic> map) {
    return DashboardProductItem(
      barcode: map['barcode']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? 'Product',
      brandName: map['brand_name']?.toString() ?? '',
      healthScore: (map['health_score'] as num?)?.toInt() ?? 50,
      verdictTag: map['verdict_tag']?.toString() ?? 'Safe',
      safePortion: map['safe_portion']?.toString() ?? '1 Serving',
      color: Color(map['color_value'] is int ? map['color_value'] as int : 0xFF137333),
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

  /// Default baseline when database is initializing or empty
  factory HomeDashboardData.defaults(UserProfileModel? profile) {
    final maxSugar = profile?.isDiabetic == true
        ? 10.0
        : (profile?.isChild == true ? 15.0 : 25.0);

    return HomeDashboardData(
      consumedSugarGrams: 0.0,
      maxSugarGrams: maxSugar,
      redAdditivesToday: 0,
      recentProducts: const [],
      isUserHistory: false,
    );
  }
}

