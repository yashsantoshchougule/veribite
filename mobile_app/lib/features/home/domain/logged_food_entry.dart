import 'dart:convert';
import '../../camera/application/product_scanner_service.dart';

/// Represents a single food item logged into the user's daily consumption budget.
/// Stores full product serialization to enable instant navigation to VerdictReportScreen.
class LoggedFoodEntry {
  final String productName;
  final String barcode;
  final double portionGrams;
  final double sugarGrams;
  final int redTierAdditivesCount;
  final DateTime timestamp;
  final Map<String, dynamic>? productJson;
  final Product? product;

  const LoggedFoodEntry({
    required this.productName,
    required this.barcode,
    required this.portionGrams,
    required this.sugarGrams,
    required this.redTierAdditivesCount,
    required this.timestamp,
    this.productJson,
    this.product,
  });

  Map<String, dynamic> toJson() {
    return {
      'product_name': productName,
      'barcode': barcode,
      'portion_grams': portionGrams,
      'sugar_grams': sugarGrams,
      'red_tier_additives_count': redTierAdditivesCount,
      'timestamp': timestamp.toIso8601String(),
      if (productJson != null || product != null)
        'product_json': productJson ?? product?.toJson(),
    };
  }

  factory LoggedFoodEntry.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic>? parsedProductJson;
    if (json['product_json'] is Map) {
      parsedProductJson = Map<String, dynamic>.from(json['product_json'] as Map);
    } else if (json['product_json'] is String) {
      try {
        final decoded = jsonDecode(json['product_json'] as String);
        if (decoded is Map) {
          parsedProductJson = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }

    Product? parsedProduct;
    if (parsedProductJson != null) {
      try {
        parsedProduct = Product.fromJson(parsedProductJson);
      } catch (_) {}
    }

    return LoggedFoodEntry(
      productName: (json['product_name'] ?? 'Packaged Food').toString(),
      barcode: (json['barcode'] ?? '').toString(),
      portionGrams: (json['portion_grams'] as num?)?.toDouble() ?? 100.0,
      sugarGrams: (json['sugar_grams'] as num?)?.toDouble() ?? 0.0,
      redTierAdditivesCount: (json['red_tier_additives_count'] as num?)?.toInt() ?? 0,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      productJson: parsedProductJson,
      product: parsedProduct,
    );
  }

  static String encodeList(List<LoggedFoodEntry> list) {
    return jsonEncode(list.map((e) => e.toJson()).toList());
  }

  static List<LoggedFoodEntry> decodeList(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        return decoded
            .whereType<Map<String, dynamic>>()
            .map((e) => LoggedFoodEntry.fromJson(e))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
