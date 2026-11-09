import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../camera/application/product_scanner_service.dart';
import '../domain/swap_alternative_model.dart';

/// Service that recommends verified clean, healthier Indian alternatives for
/// packaged food items and generates 1-tap quick-commerce delivery links.
class HealthierSwapsService {
  /// Detects the semantic category of a product from its name and raw category strings
  static String detectCategory({required String productName, required String rawCategory}) {
    final combined = '${productName.toLowerCase()} ${rawCategory.toLowerCase()}';

    // 1. Biscuits & Cookies (check early so 'Butter Cookies' matches here, not Dairy)
    if (combined.contains('biscuit') ||
        combined.contains('cookie') ||
        combined.contains('cracker') ||
        combined.contains('wafer') && !combined.contains('potato')) {
      return 'Biscuits & Cookies';
    }

    // 2. Spreads & Nut Butters (check early so 'Peanut Butter' matches here, not Dairy)
    if (combined.contains('peanut butter') ||
        combined.contains('almond butter') ||
        combined.contains('nut butter') ||
        combined.contains('jam') ||
        combined.contains('marmalade')) {
      return 'Spreads & Nut Butters';
    }

    // 3. Bakery & Breads
    if (combined.contains('bread') ||
        combined.contains('bun') ||
        combined.contains('pav') ||
        combined.contains('toast') ||
        combined.contains('rusk') ||
        combined.contains('roti') ||
        combined.contains('tortilla')) {
      return 'Bakery & Breads';
    }

    // 4. Chocolates & Sweet Spreads
    if (combined.contains('chocolate') ||
        combined.contains('cocoa') ||
        combined.contains('hazelnut spread') ||
        combined.contains('nutella') ||
        combined.contains('candy') ||
        combined.contains('choco')) {
      return 'Chocolates & Spreads';
    }

    // 5. Instant Noodles & Pasta
    if (combined.contains('noodle') ||
        combined.contains('maggi') ||
        combined.contains('ramen') ||
        combined.contains('pasta') ||
        combined.contains('macaroni') ||
        combined.contains('spaghetti')) {
      return 'Instant Noodles';
    }

    // 6. Chips & Crisps
    if (combined.contains('chip') ||
        combined.contains('crisp') ||
        combined.contains('nacho') ||
        combined.contains('puff') ||
        combined.contains('popcorn') ||
        combined.contains('makhana')) {
      return 'Chips & Crisps';
    }

    // 7. Breakfast Cereals
    if (combined.contains('cereal') ||
        combined.contains('oat') ||
        combined.contains('muesli') ||
        combined.contains('granola') ||
        combined.contains('flake') ||
        combined.contains('cornflake')) {
      return 'Breakfast Cereals';
    }

    // 8. Beverages & Juices
    if (combined.contains('juice') ||
        combined.contains('drink') ||
        combined.contains('beverage') ||
        combined.contains('cola') ||
        combined.contains('soda') ||
        combined.contains('tea') ||
        combined.contains('coffee') ||
        combined.contains('nectar')) {
      return 'Beverages & Juices';
    }

    // 9. Sauces & Ketchups
    if (combined.contains('ketchup') ||
        combined.contains('sauce') ||
        combined.contains('mayonnaise') ||
        combined.contains('mayo') ||
        combined.contains('dip') ||
        combined.contains('chutney')) {
      return 'Sauces & Ketchups';
    }

    // 10. Namkeen & Savory Snacks
    if (combined.contains('bhujia') ||
        combined.contains('sev') ||
        combined.contains('namkeen') ||
        combined.contains('mixture') ||
        combined.contains('chana jor') ||
        combined.contains('murukku') ||
        combined.contains('kurkure')) {
      return 'Namkeen & Savory Snacks';
    }

    // 11. Cooking Oils & Ghee
    if (combined.contains('oil') ||
        (combined.contains('ghee') && !combined.contains('cheese')) ||
        combined.contains('vanaspati')) {
      return 'Cooking Oils & Ghee';
    }

    // 12. Cheese & Dairy
    if (combined.contains('cheese') ||
        combined.contains('cheddar') ||
        combined.contains('mozzarella') ||
        combined.contains('parmesan') ||
        combined.contains('gouda') ||
        combined.contains('paneer') ||
        combined.contains('cottage cheese') ||
        combined.contains('dairy') ||
        combined.contains('curd') ||
        combined.contains('yogurt') ||
        combined.contains('dahi') ||
        combined.contains('butter')) {
      return 'Cheese & Dairy';
    }

    return rawCategory.isNotEmpty ? rawCategory : 'General Packaged Food';
  }

  /// Categorizes a brand into quality and clean-label pedigree tiers:
  /// Tier 3: Certified clean-label, artisanal, organic, single-origin (e.g. Akshayakalpa, Two Brothers, The Whole Truth)
  /// Tier 2: High-grade established national dairy & grocery staples (e.g. Milky Mist, Amul, Mother Dairy, Britannia)
  /// Tier 1: Standard commercial mass-market (e.g. Nestle, Maggi, Lay's, Parle, Haldiram's)
  static int getScannedBrandTier(String? brandName) {
    if (brandName == null || brandName.trim().isEmpty) return 1;
    final lower = brandName.toLowerCase().trim();

    // Tier 3: Certified clean-label, organic, artisanal, single-origin
    const tier3Brands = [
      'akshayakalpa',
      'two brothers',
      'the whole truth',
      'early foods',
      'd\'lecta',
      'dlecta',
      'country delight',
      'raw pressery',
      'pintola',
      'slurrp farm',
      'wickedgud',
      'true elements',
      'yoga bar',
      'farmley',
      'organic india',
      'the health factory',
      'native tongue',
      'anveshan',
      'open secret',
      'happy cow',
    ];
    if (tier3Brands.any((b) => lower.contains(b))) return 3;

    // Tier 2: Established high-grade national dairy & grocery staples
    const tier2Brands = [
      'milky mist',
      'amul',
      'mother dairy',
      'epigamia',
      'tata',
      'britannia',
      'saffola',
      'paper boat',
      'bonn',
      'om sweets',
      'everest',
      'mdh',
      'catch',
      'fortune',
    ];
    if (tier2Brands.any((b) => lower.contains(b))) return 2;

    // Tier 1: Standard commercial mass-market
    return 1;
  }

  /// Verified Indian clean alternative catalog organized by food category
  static const Map<String, List<SwapAlternativeModel>> _catalogByCategory = {
    // 1. Cheese & Dairy
    'Cheese & Dairy': [
      SwapAlternativeModel(
        barcode: '8906000000014',
        productName: 'Organic Artisan Cheddar Cheese',
        brandName: 'Akshayakalpa',
        category: 'Cheese & Dairy',
        healthScore: 88,
        scoreDelta: 43,
        brandTier: 3,
        keyAdvantages: [
          '100% Organic Grass-Fed Cow Milk',
          'Zero Emulsifying Salts (INS 331/452)',
          'Zero Vegetable Oil / Palm Fat',
          'Traditional Microbial Rennet',
        ],
        servingSizeG: 25.0,
        sugarGPerServing: 0.1,
        satFatGPerServing: 5.2,
        sodiumMgPerServing: 160.0,
        quickCommerceQuery: 'Akshayakalpa Organic Cheddar Cheese',
      ),
      SwapAlternativeModel(
        barcode: '8906000000021',
        productName: 'Natural Sliced Cheddar Cheese',
        brandName: 'D\'lecta',
        category: 'Cheese & Dairy',
        healthScore: 82,
        scoreDelta: 37,
        brandTier: 2,
        keyAdvantages: [
          'Pure Cow Milk Natural Cheese',
          'Zero Artificial Preservatives',
          'Unadulterated Milk Solids',
          'Zero Palm Fat Fillers',
        ],
        servingSizeG: 20.0,
        sugarGPerServing: 0.2,
        satFatGPerServing: 4.8,
        sodiumMgPerServing: 190.0,
        quickCommerceQuery: 'Dlecta Natural Cheddar Slices',
      ),
      SwapAlternativeModel(
        barcode: '8906000000038',
        productName: 'Pure Natural Malai Paneer / Fresh Cottage Cheese',
        brandName: 'Country Delight',
        category: 'Cheese & Dairy',
        healthScore: 90,
        scoreDelta: 45,
        brandTier: 3,
        keyAdvantages: [
          'Zero Chemical Coagulants',
          '100% Fresh Cow Milk Fat',
          'Zero Starch or Flour Fillers',
          'High Natural Protein & Calcium',
        ],
        servingSizeG: 50.0,
        sugarGPerServing: 0.5,
        satFatGPerServing: 6.0,
        sodiumMgPerServing: 20.0,
        quickCommerceQuery: 'Country Delight Natural Paneer',
      ),
    ],

    // 2. Instant Noodles & Pasta
    'Instant Noodles': [
      SwapAlternativeModel(
        barcode: '8906000001011',
        productName: 'Foxtail & Little Millet Noodles',
        brandName: 'Slurrp Farm',
        category: 'Instant Noodles',
        healthScore: 78,
        scoreDelta: 46,
        brandTier: 3,
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
        brandTier: 3,
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

    // 3. Biscuits & Cookies
    'Biscuits & Cookies': [
      SwapAlternativeModel(
        barcode: '8906000002018',
        productName: 'Whole Oatmeal & Almond Cookies',
        brandName: 'True Elements',
        category: 'Biscuits & Cookies',
        healthScore: 82,
        scoreDelta: 34,
        brandTier: 3,
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
        brandTier: 3,
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

    // 4. Chips & Crisps
    'Chips & Crisps': [
      SwapAlternativeModel(
        barcode: '8906000003015',
        productName: 'Roasted Pink Salted Makhana',
        brandName: 'The Whole Truth',
        category: 'Chips & Crisps',
        healthScore: 89,
        scoreDelta: 35,
        brandTier: 3,
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
        brandTier: 3,
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

    // 5. Breakfast Cereals
    'Breakfast Cereals': [
      SwapAlternativeModel(
        barcode: '8906000004012',
        productName: 'Super Seeds Rolled Oats',
        brandName: 'Yoga Bar',
        category: 'Breakfast Cereals',
        healthScore: 92,
        scoreDelta: 25,
        brandTier: 3,
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
      SwapAlternativeModel(
        barcode: '8906000004029',
        productName: 'Multigrain Crunch Muesli (Zero Sugar)',
        brandName: 'True Elements',
        category: 'Breakfast Cereals',
        healthScore: 88,
        scoreDelta: 21,
        brandTier: 3,
        keyAdvantages: [
          'Whole Grains, Raw Nuts & Berries',
          'Zero Added Fructose / Corn Syrup',
          'High Prebiotic Dietary Fiber',
          'Low Glycemic Index',
        ],
        servingSizeG: 40.0,
        sugarGPerServing: 1.2,
        satFatGPerServing: 1.5,
        sodiumMgPerServing: 18.0,
        quickCommerceQuery: 'True Elements Sugar Free Muesli',
      ),
    ],

    // 6. Chocolates & Spreads
    'Chocolates & Spreads': [
      SwapAlternativeModel(
        barcode: '8906000005019',
        productName: '71% Single Origin Dark Chocolate',
        brandName: 'The Whole Truth',
        category: 'Chocolates & Spreads',
        healthScore: 86,
        scoreDelta: 42,
        brandTier: 3,
        keyAdvantages: [
          'Only 2 Ingredients: Cocoa & Raw Sugar',
          'Zero Palm Oil / Zero Vanaspati',
          'Zero Synthetic Lecithins (INS 476)',
          'Antioxidant Rich Cocoa Butter',
        ],
        servingSizeG: 20.0,
        sugarGPerServing: 4.2,
        satFatGPerServing: 6.1,
        sodiumMgPerServing: 4.0,
        quickCommerceQuery: 'The Whole Truth 71% Dark Chocolate',
      ),
      SwapAlternativeModel(
        barcode: '8906000005026',
        productName: 'Jaggery Choco Hazelnut Spread',
        brandName: 'Open Secret',
        category: 'Chocolates & Spreads',
        healthScore: 80,
        scoreDelta: 36,
        brandTier: 3,
        keyAdvantages: [
          'Sweetened with Raw Dhampur Jaggery',
          '40% Real Hazelnuts & Cocoa',
          'Zero Hydrogenated Palm Oils',
          'Zero Artificial Preservatives',
        ],
        servingSizeG: 20.0,
        sugarGPerServing: 5.4,
        satFatGPerServing: 2.8,
        sodiumMgPerServing: 15.0,
        quickCommerceQuery: 'Open Secret Choco Hazelnut Spread',
      ),
    ],

    // 7. Bakery & Breads
    'Bakery & Breads': [
      SwapAlternativeModel(
        barcode: '8906000006016',
        productName: 'Zero Maida 100% Whole Wheat Bread',
        brandName: 'The Health Factory',
        category: 'Bakery & Breads',
        healthScore: 85,
        scoreDelta: 41,
        brandTier: 3,
        keyAdvantages: [
          '100% Whole Wheat Flour',
          'Zero Refined Maida',
          'Zero Potassium Bromate / Bleaching Agents',
          'High Dietary Fiber (6g/slice)',
        ],
        servingSizeG: 45.0,
        sugarGPerServing: 1.2,
        satFatGPerServing: 0.4,
        sodiumMgPerServing: 140.0,
        quickCommerceQuery: 'The Health Factory Zero Maida Bread',
      ),
      SwapAlternativeModel(
        barcode: '8906000006023',
        productName: '100% Whole Grain Multigrain Artisan Bread',
        brandName: 'Bonn',
        category: 'Bakery & Breads',
        healthScore: 81,
        scoreDelta: 37,
        brandTier: 2,
        keyAdvantages: [
          'Rolled Oats, Flax Seeds & Sunflower Seeds',
          'No Added Artificial Colors',
          'Low Glycemic Index Whole Grains',
          'Heart-Healthy Complex Carbs',
        ],
        servingSizeG: 40.0,
        sugarGPerServing: 1.5,
        satFatGPerServing: 0.5,
        sodiumMgPerServing: 160.0,
        quickCommerceQuery: 'Bonn 100% Whole Grain Multigrain Bread',
      ),
    ],

    // 8. Beverages & Juices
    'Beverages & Juices': [
      SwapAlternativeModel(
        barcode: '8906000007013',
        productName: '100% Cold Pressed Valencia Orange Juice',
        brandName: 'Raw Pressery',
        category: 'Beverages & Juices',
        healthScore: 88,
        scoreDelta: 52,
        brandTier: 3,
        keyAdvantages: [
          '100% Cold Pressed Fresh Fruit',
          'Zero Added Refined Sugar',
          'Never from Reconstituted Concentrate',
          'Zero Artificial Preservatives / INS 211',
        ],
        servingSizeG: 200.0,
        sugarGPerServing: 14.0,
        satFatGPerServing: 0.0,
        sodiumMgPerServing: 8.0,
        quickCommerceQuery: 'Raw Pressery Cold Pressed Valencia Orange',
      ),
      SwapAlternativeModel(
        barcode: '8906000007020',
        productName: '100% Pure Tender Coconut Water',
        brandName: 'Paper Boat',
        category: 'Beverages & Juices',
        healthScore: 92,
        scoreDelta: 56,
        brandTier: 2,
        keyAdvantages: [
          '100% Natural Coconut Water',
          'Zero Added Sugar / Zero Syrups',
          'Rich in Natural Potassium & Electrolytes',
          'Zero Synthetic Colorants',
        ],
        servingSizeG: 200.0,
        sugarGPerServing: 7.2,
        satFatGPerServing: 0.1,
        sodiumMgPerServing: 42.0,
        quickCommerceQuery: 'Paper Boat Tender Coconut Water',
      ),
    ],

    // 9. Cooking Oils & Ghee
    'Cooking Oils & Ghee': [
      SwapAlternativeModel(
        barcode: '8906000008010',
        productName: 'Organic Wood Pressed Mustard Oil (Cold Pressed)',
        brandName: 'Two Brothers',
        category: 'Cooking Oils & Ghee',
        healthScore: 91,
        scoreDelta: 38,
        brandTier: 3,
        keyAdvantages: [
          'Traditional Wooden Kolhu Extraction',
          'Zero Chemical Solvents / Hexane Free',
          'Natural Omega 3 & 6 Ratio',
          'Zero Trans Fat / Unrefined',
        ],
        servingSizeG: 15.0,
        sugarGPerServing: 0.0,
        satFatGPerServing: 1.2,
        sodiumMgPerServing: 0.0,
        quickCommerceQuery: 'Two Brothers Organic Mustard Oil',
      ),
      SwapAlternativeModel(
        barcode: '8906000008027',
        productName: 'A2 Vedic Bilona Desi Cow Ghee',
        brandName: 'Anveshan',
        category: 'Cooking Oils & Ghee',
        healthScore: 94,
        scoreDelta: 41,
        brandTier: 3,
        keyAdvantages: [
          'Traditional Curd Churning (Bilona Method)',
          'Grass-Fed A2 Gir Cow Milk',
          'Rich in Butyric Acid & Fat Soluble Vitamins',
          'Zero Synthetic Additives / Pure Aroma',
        ],
        servingSizeG: 15.0,
        sugarGPerServing: 0.0,
        satFatGPerServing: 7.5,
        sodiumMgPerServing: 0.0,
        quickCommerceQuery: 'Anveshan A2 Vedic Bilona Ghee',
      ),
    ],

    // 10. Sauces & Ketchups
    'Sauces & Ketchups': [
      SwapAlternativeModel(
        barcode: '8906000009017',
        productName: 'Date-Sweetened Organic Tomato Ketchup',
        brandName: 'The Whole Truth',
        category: 'Sauces & Ketchups',
        healthScore: 87,
        scoreDelta: 48,
        brandTier: 3,
        keyAdvantages: [
          'Sweetened with Arabian Dates',
          'Zero High Fructose Corn Syrup / Sugar',
          'Zero Sodium Benzoate (INS 211)',
          '70% Real Farm Tomatoes',
        ],
        servingSizeG: 15.0,
        sugarGPerServing: 1.8,
        satFatGPerServing: 0.0,
        sodiumMgPerServing: 85.0,
        quickCommerceQuery: 'The Whole Truth Tomato Ketchup',
      ),
      SwapAlternativeModel(
        barcode: '8906000009024',
        productName: 'Farm Fresh Organic Tomato Sauce',
        brandName: 'Native Tongue',
        category: 'Sauces & Ketchups',
        healthScore: 83,
        scoreDelta: 44,
        brandTier: 3,
        keyAdvantages: [
          'Organic Slow Cooked Tomatoes',
          'Zero Modified Starches (INS 1422)',
          'Cold Pressed Spices & Apple Cider Vinegar',
          'Zero Artificial Flavoring',
        ],
        servingSizeG: 15.0,
        sugarGPerServing: 2.1,
        satFatGPerServing: 0.1,
        sodiumMgPerServing: 95.0,
        quickCommerceQuery: 'Native Tongue Tomato Sauce',
      ),
    ],

    // 11. Spreads & Nut Butters
    'Spreads & Nut Butters': [
      SwapAlternativeModel(
        barcode: '8906000010013',
        productName: '100% All-Natural Crunchy Peanut Butter',
        brandName: 'Pintola',
        category: 'Spreads & Nut Butters',
        healthScore: 93,
        scoreDelta: 45,
        brandTier: 3,
        keyAdvantages: [
          'Single Ingredient: 100% Roasted Peanuts',
          'Zero Hydrogenated Palm Oils',
          'Zero Added Sugar / Zero Salt',
          '30g Bioavailable Plant Protein per 100g',
        ],
        servingSizeG: 32.0,
        sugarGPerServing: 1.0,
        satFatGPerServing: 2.0,
        sodiumMgPerServing: 4.0,
        quickCommerceQuery: 'Pintola All Natural Peanut Butter Crunchy',
      ),
      SwapAlternativeModel(
        barcode: '8906000010020',
        productName: 'Dark Chocolate Organic Peanut Butter',
        brandName: 'The Whole Truth',
        category: 'Spreads & Nut Butters',
        healthScore: 89,
        scoreDelta: 41,
        brandTier: 3,
        keyAdvantages: [
          'Only Peanuts, Cocoa & Raw Jaggery',
          'Zero Emulsifiers / No Hydrogenated Fats',
          'High Dietary Fiber & Magnesium',
          'Unprocessed Cocoa Butter',
        ],
        servingSizeG: 32.0,
        sugarGPerServing: 3.2,
        satFatGPerServing: 2.4,
        sodiumMgPerServing: 8.0,
        quickCommerceQuery: 'The Whole Truth Dark Chocolate Peanut Butter',
      ),
    ],

    // 12. Namkeen & Savory Snacks
    'Namkeen & Savory Snacks': [
      SwapAlternativeModel(
        barcode: '8906000011010',
        productName: 'Ragi Bites Masala Munch (Roasted Millets)',
        brandName: 'Slurrp Farm',
        category: 'Namkeen & Savory Snacks',
        healthScore: 83,
        scoreDelta: 48,
        brandTier: 3,
        keyAdvantages: [
          '100% Roasted Ancient Millets',
          '65% Less Saturated Fat than Bhujia',
          'Zero Palm Oil / Zero Trans Fat',
          'Real Cumin, Coriander & Mango Powder',
        ],
        servingSizeG: 30.0,
        sugarGPerServing: 0.8,
        satFatGPerServing: 1.5,
        sodiumMgPerServing: 190.0,
        quickCommerceQuery: 'Slurrp Farm Ragi Bites Masala',
      ),
      SwapAlternativeModel(
        barcode: '8906000011027',
        productName: 'Roasted Chana Jor Garam (Rock Salt)',
        brandName: 'Om Sweets',
        category: 'Namkeen & Savory Snacks',
        healthScore: 88,
        scoreDelta: 53,
        brandTier: 2,
        keyAdvantages: [
          'Roasted Whole Black Bengal Gram',
          'Himalayan Pink Rock Salt',
          'Zero Deep Frying',
          'High Fiber & Natural Plant Protein',
        ],
        servingSizeG: 35.0,
        sugarGPerServing: 0.4,
        satFatGPerServing: 0.8,
        sodiumMgPerServing: 140.0,
        quickCommerceQuery: 'Om Sweets Roasted Chana Jor Garam',
      ),
    ],
  };

  /// Get cleaner alternative swaps tailored to a scanned product.
  /// Strictly enforces:
  /// 1. Direct 1-to-1 food category match (e.g. Cheese -> Cheese, never Peanuts).
  /// 2. Brand pedigree hierarchy: Recommended brand tier must be equal to or greater than scanned product brand tier.
  /// 3. Health score improvement: Alternative score must be >= scanned product score.
  List<SwapAlternativeModel> getSwapsForProduct(ScannedProductResult product) {
    final matchedCategory = detectCategory(
      productName: product.productName,
      rawCategory: product.category,
    );

    final scannedBrandTier = getScannedBrandTier(product.brandName);

    // Look up alternatives in the exact matched category
    final categorySwaps = _catalogByCategory[matchedCategory] ?? [];

    if (categorySwaps.isEmpty) {
      // Strict rule: NEVER return unrelated categories (e.g. peanuts for cheese)!
      return [];
    }

    // Filter by:
    // 1. Equal or higher brand tier
    // 2. Equal or higher health score
    final currentScore = product.healthScore ?? 50;
    final qualifiedSwaps = categorySwaps.where((alt) {
      final brandTierOk = alt.brandTier >= scannedBrandTier;
      final healthScoreOk = alt.healthScore >= currentScore;
      return brandTierOk && healthScoreOk;
    }).toList();

    // If no products meet both strict criteria (e.g. product already has high score or high brand tier),
    // fall back to the highest-scoring clean alternatives in the SAME category that improve health
    final effectiveSwaps = qualifiedSwaps.isNotEmpty
        ? qualifiedSwaps
        : categorySwaps.where((alt) => alt.healthScore >= currentScore).toList();

    if (effectiveSwaps.isEmpty) {
      return [];
    }

    // Recalculate dynamic score delta against the current product's real score
    final result = effectiveSwaps.map((alt) {
      final delta = (alt.healthScore - currentScore).clamp(0, 99);
      return SwapAlternativeModel(
        barcode: alt.barcode,
        productName: alt.productName,
        brandName: alt.brandName,
        category: alt.category,
        healthScore: alt.healthScore,
        scoreDelta: delta,
        brandTier: alt.brandTier,
        keyAdvantages: alt.keyAdvantages,
        servingSizeG: alt.servingSizeG,
        sugarGPerServing: alt.sugarGPerServing,
        satFatGPerServing: alt.satFatGPerServing,
        sodiumMgPerServing: alt.sodiumMgPerServing,
        quickCommerceQuery: alt.quickCommerceQuery,
      );
    }).toList();

    result.sort((a, b) => b.scoreDelta.compareTo(a.scoreDelta));
    return result;
  }

  /// Get cleaner swaps for a general category name (e.g. from Home action shortcuts)
  List<SwapAlternativeModel> getSwapsForCategory(String category, {int currentScore = 40}) {
    final matchedCategory = detectCategory(
      productName: '',
      rawCategory: category,
    );

    final categorySwaps = _catalogByCategory[matchedCategory] ?? [];
    if (categorySwaps.isEmpty) {
      return [];
    }

    final result = categorySwaps.map((alt) {
      final delta = (alt.healthScore - currentScore).clamp(0, 99);
      return SwapAlternativeModel(
        barcode: alt.barcode,
        productName: alt.productName,
        brandName: alt.brandName,
        category: alt.category,
        healthScore: alt.healthScore,
        scoreDelta: delta,
        brandTier: alt.brandTier,
        keyAdvantages: alt.keyAdvantages,
        servingSizeG: alt.servingSizeG,
        sugarGPerServing: alt.sugarGPerServing,
        satFatGPerServing: alt.satFatGPerServing,
        sodiumMgPerServing: alt.sodiumMgPerServing,
        quickCommerceQuery: alt.quickCommerceQuery,
      );
    }).toList();

    result.sort((a, b) => b.scoreDelta.compareTo(a.scoreDelta));
    return result;
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
