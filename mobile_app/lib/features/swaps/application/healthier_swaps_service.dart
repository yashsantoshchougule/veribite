import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../camera/application/product_scanner_service.dart';
import '../domain/swap_alternative_model.dart';

/// Service that recommends verified clean, healthier Indian alternatives for
/// packaged food items and generates 1-tap quick-commerce delivery links.
class HealthierSwapsService {
  /// Verified Indian clean alternative catalog organized by food category
  static const Map<String, List<SwapAlternativeModel>> _catalogByCategory = {
    'Instant Noodles': [
      SwapAlternativeModel(
        barcode: '8906000001011',
        productName: 'Foxtail & Little Millet Noodles',
        brandName: 'Slurrp Farm',
        category: 'Instant Noodles',
        healthScore: 78,
        scoreDelta: 46,
        keyAdvantages: [
          'Zero Red INS Additives',
          '100% Unfried Whole Grain',
          'No Refined Palm Oil',
          '54% Lower Sodium',
        ],
        servingSizeG: 55.0,
        sugarGPerServing: 1.1,
        satFatGPerServing: 1.2,
        sodiumMgPerServing: 340.0,
        quickCommerceQuery: 'Slurrp Farm Foxtail Millet Noodles',
      ),
      SwapAlternativeModel(
        barcode: '8906000001028',
        productName: 'Whole Wheat Hakka Noodles',
        brandName: 'WickedGud',
        category: 'Instant Noodles',
        healthScore: 74,
        scoreDelta: 42,
        keyAdvantages: [
          'Zero Artificial Flavors',
          'Whole Wheat & Lentil Flour',
          'Steamed Not Fried',
          'High Fiber & Protein',
        ],
        servingSizeG: 60.0,
        sugarGPerServing: 1.5,
        satFatGPerServing: 1.4,
        sodiumMgPerServing: 390.0,
        quickCommerceQuery: 'WickedGud Whole Wheat Hakka Noodles',
      ),
    ],
    'Biscuits & Cookies': [
      SwapAlternativeModel(
        barcode: '8906000002018',
        productName: 'Whole Oatmeal & Almond Cookies',
        brandName: 'True Elements',
        category: 'Biscuits & Cookies',
        healthScore: 82,
        scoreDelta: 34,
        keyAdvantages: [
          'Zero Invert Sugar Syrup',
          'No Refined Maida Flour',
          'Sweetened with Raw Jaggery',
          'Zero Preservatives',
        ],
        servingSizeG: 25.0,
        sugarGPerServing: 3.5,
        satFatGPerServing: 2.1,
        sodiumMgPerServing: 75.0,
        quickCommerceQuery: 'True Elements Oatmeal Cookies',
      ),
      SwapAlternativeModel(
        barcode: '8906000002025',
        productName: 'Organic Multi-Grain Jaggery Cookies',
        brandName: 'Early Foods',
        category: 'Biscuits & Cookies',
        healthScore: 86,
        scoreDelta: 38,
        keyAdvantages: [
          '100% Ragi & Whole Wheat',
          'Cold Pressed Butter (No Margarine)',
          'Zero Chemical INS Leavening',
          'Natural Iron & Calcium',
        ],
        servingSizeG: 20.0,
        sugarGPerServing: 2.8,
        satFatGPerServing: 2.5,
        sodiumMgPerServing: 45.0,
        quickCommerceQuery: 'Early Foods Jaggery Cookies',
      ),
    ],
    'Chips & Crisps': [
      SwapAlternativeModel(
        barcode: '8906000003015',
        productName: 'Roasted Pink Salted Makhana',
        brandName: 'The Whole Truth',
        category: 'Chips & Crisps',
        healthScore: 89,
        scoreDelta: 35,
        keyAdvantages: [
          'Roasted Not Fried',
          '70% Less Saturated Fat',
          'Himalayan Pink Rock Salt',
          'Zero Palm Oil / Zero Trans Fat',
        ],
        servingSizeG: 30.0,
        sugarGPerServing: 0.2,
        satFatGPerServing: 1.1,
        sodiumMgPerServing: 180.0,
        quickCommerceQuery: 'The Whole Truth Roasted Makhana',
      ),
      SwapAlternativeModel(
        barcode: '8906000003022',
        productName: 'Roasted Peri Peri Foxnuts',
        brandName: 'Farmley',
        category: 'Chips & Crisps',
        healthScore: 84,
        scoreDelta: 30,
        keyAdvantages: [
          'High Antioxidant Lotus Seeds',
          'Olive Oil Infused',
          'Natural Chili & Herbs',
          'Gluten Free Whole Snack',
        ],
        servingSizeG: 30.0,
        sugarGPerServing: 0.5,
        satFatGPerServing: 1.8,
        sodiumMgPerServing: 220.0,
        quickCommerceQuery: 'Farmley Roasted Makhana Peri Peri',
      ),
    ],
    'Breakfast Cereals': [
      SwapAlternativeModel(
        barcode: '8906000004012',
        productName: 'Super Seeds Rolled Oats',
        brandName: 'Yoga Bar',
        category: 'Breakfast Cereals',
        healthScore: 92,
        scoreDelta: 25,
        keyAdvantages: [
          '100% Whole Rolled Oats',
          'Chia, Pumpkin & Watermelon Seeds',
          'Zero Added Refined Sugar',
          'Beta-Glucan Heart Safe',
        ],
        servingSizeG: 40.0,
        sugarGPerServing: 0.8,
        satFatGPerServing: 1.2,
        sodiumMgPerServing: 12.0,
        quickCommerceQuery: 'Yoga Bar Rolled Oats Super Seeds',
      ),
    ],
  };

  /// Fallback clean alternatives when scanned category is general or uncatalogued
  static const List<SwapAlternativeModel> _generalFallbackSwaps = [
    SwapAlternativeModel(
      barcode: '8906000009019',
      productName: 'Roasted Nutty Clean Munch',
      brandName: 'Open Secret',
      category: 'Healthy Snacks',
      healthScore: 82,
      scoreDelta: 30,
      keyAdvantages: [
        '40–50% Almonds & Cashews',
        'Zero Added Preservatives',
        'Unrefined Jaggery',
        'Nutri Safe 🟢 Whole Food',
      ],
      servingSizeG: 30.0,
      sugarGPerServing: 3.2,
      satFatGPerServing: 2.0,
      sodiumMgPerServing: 90.0,
      quickCommerceQuery: 'Open Secret Nutty Cookies Snacks',
    ),
    SwapAlternativeModel(
      barcode: '8906000009026',
      productName: 'Roasted Pink Salted Makhana',
      brandName: 'The Whole Truth',
      category: 'Healthy Snacks',
      healthScore: 89,
      scoreDelta: 35,
      keyAdvantages: [
        'Roasted Not Fried',
        'Zero Palm Oil',
        '70% Less Saturated Fat',
        'Rock Salt Ceiling Safe',
      ],
      servingSizeG: 30.0,
      sugarGPerServing: 0.2,
      satFatGPerServing: 1.1,
      sodiumMgPerServing: 180.0,
      quickCommerceQuery: 'The Whole Truth Roasted Makhana',
    ),
  ];

  /// Get cleaner alternative swaps tailored to a scanned product
  List<SwapAlternativeModel> getSwapsForProduct(ScannedProductResult product) {
    List<SwapAlternativeModel> baseSwaps = [];

    // Match exact category
    for (final entry in _catalogByCategory.entries) {
      if (product.category.toLowerCase().contains(entry.key.toLowerCase()) ||
          product.productName.toLowerCase().contains(entry.key.toLowerCase())) {
        baseSwaps = entry.value;
        break;
      }
    }

    if (baseSwaps.isEmpty) {
      baseSwaps = _generalFallbackSwaps;
    }

    // Recalculate dynamic score delta against the current product's real score
    return baseSwaps.map((alt) {
      final delta = (alt.healthScore - product.healthScore).clamp(1, 99);
      return SwapAlternativeModel(
        barcode: alt.barcode,
        productName: alt.productName,
        brandName: alt.brandName,
        category: alt.category,
        healthScore: alt.healthScore,
        scoreDelta: delta,
        keyAdvantages: alt.keyAdvantages,
        servingSizeG: alt.servingSizeG,
        sugarGPerServing: alt.sugarGPerServing,
        satFatGPerServing: alt.satFatGPerServing,
        sodiumMgPerServing: alt.sodiumMgPerServing,
        quickCommerceQuery: alt.quickCommerceQuery,
      );
    }).toList();
  }

  /// Get cleaner swaps for a general category name (e.g. from Home action shortcuts)
  List<SwapAlternativeModel> getSwapsForCategory(String category, {int currentScore = 40}) {
    List<SwapAlternativeModel> baseSwaps = [];

    for (final entry in _catalogByCategory.entries) {
      if (category.toLowerCase().contains(entry.key.toLowerCase())) {
        baseSwaps = entry.value;
        break;
      }
    }

    if (baseSwaps.isEmpty) {
      baseSwaps = _generalFallbackSwaps;
    }

    return baseSwaps.map((alt) {
      final delta = (alt.healthScore - currentScore).clamp(1, 99);
      return SwapAlternativeModel(
        barcode: alt.barcode,
        productName: alt.productName,
        brandName: alt.brandName,
        category: alt.category,
        healthScore: alt.healthScore,
        scoreDelta: delta,
        keyAdvantages: alt.keyAdvantages,
        servingSizeG: alt.servingSizeG,
        sugarGPerServing: alt.sugarGPerServing,
        satFatGPerServing: alt.satFatGPerServing,
        sodiumMgPerServing: alt.sodiumMgPerServing,
        quickCommerceQuery: alt.quickCommerceQuery,
      );
    }).toList();
  }

  /// Generate quick-commerce search query URLs
  String getQuickCommerceUrl(QuickCommercePlatform platform, String query) {
    final encoded = Uri.encodeComponent(query);
    switch (platform) {
      case QuickCommercePlatform.blinkit:
        return 'https://blinkit.com/s/?q=$encoded';
      case QuickCommercePlatform.zepto:
        return 'https://www.zeptonow.com/search?q=$encoded';
      case QuickCommercePlatform.instamart:
        return 'https://www.swiggy.com/instamart/search?query=$encoded';
      case QuickCommercePlatform.bigbasket:
        return 'https://www.bigbasket.com/ps/?q=$encoded';
    }
  }

  /// Launch external quick-commerce app or browser search
  Future<bool> launchStore(QuickCommercePlatform platform, String query) async {
    final urlString = getQuickCommerceUrl(platform, query);
    final uri = Uri.parse(urlString);
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Failed to launch quick-commerce URL $urlString: $e');
      try {
        return await launchUrl(uri);
      } catch (_) {
        return false;
      }
    }
  }
}
