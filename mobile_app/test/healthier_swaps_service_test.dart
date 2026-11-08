import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/camera/application/product_scanner_service.dart';
import 'package:mobile_app/features/swaps/application/healthier_swaps_service.dart';
import 'package:mobile_app/features/swaps/domain/swap_alternative_model.dart';

void main() {
  group('HealthierSwapsService Tests', () {
    late HealthierSwapsService service;

    setUp(() {
      service = HealthierSwapsService();
    });

    test('getSwapsForProduct matches Instant Noodles category and calculates positive score delta', () {
      const maggiProduct = ScannedProductResult(
        barcode: '8901058852339',
        productName: '2-Minute Masala Noodles',
        brandName: 'Maggi',
        category: 'Instant Noodles',
        servingSizeG: 70.0,
        sugarGPer100g: 3.2,
        sugarGPerServing: 2.2,
        caloriesPerServing: 295.0,
        healthScore: 32, // Toxic / Capped
        verdictTag: 'Toxic / Capped 🔴',
        novaGrade: 4,
        redCapTriggered: true,
        safePortionGrams: 25,
        limitingFactor: 'Sodium',
        frequencySchedule: 'Strict 1–2x/Week',
        additives: [],
        splitSugars: [],
        portionAdvice: 'Safe portion 25g',
        isExceededBudget: false,
      );

      final swaps = service.getSwapsForProduct(maggiProduct);

      expect(swaps.isNotEmpty, isTrue);
      expect(swaps.first.brandName, 'Slurrp Farm');
      expect(swaps.first.healthScore, 78);
      // 78 - 32 = +46 score delta
      expect(swaps.first.scoreDelta, 46);
      expect(swaps.first.keyAdvantages, contains('Zero Red INS Additives'));
      expect(swaps.first.keyAdvantages, contains('No Refined Palm Oil'));
    });

    test('getSwapsForProduct matches Biscuits & Cookies category', () {
      const cookieProduct = ScannedProductResult(
        barcode: '8901063012117',
        productName: 'Good Day Butter Cookies',
        brandName: 'Britannia',
        category: 'Biscuits & Cookies',
        servingSizeG: 25.0,
        sugarGPer100g: 24.5,
        sugarGPerServing: 6.1,
        caloriesPerServing: 125.0,
        healthScore: 48,
        verdictTag: 'Caution 🟠',
        novaGrade: 4,
        redCapTriggered: false,
        safePortionGrams: 25,
        limitingFactor: 'Sugar',
        frequencySchedule: 'Moderate',
        additives: [],
        splitSugars: [],
        portionAdvice: 'Safe portion 25g',
        isExceededBudget: false,
      );

      final swaps = service.getSwapsForProduct(cookieProduct);

      expect(swaps.length, 2);
      expect(swaps.any((s) => s.brandName == 'True Elements'), isTrue);
      expect(swaps.any((s) => s.brandName == 'Early Foods'), isTrue);
      expect(swaps.first.scoreDelta, greaterThan(0));
    });

    test('getSwapsForProduct matches Milky Mist Cheese to Cheese & Dairy, returns only clean dairy and never peanuts', () {
      const milkyMistCheese = ScannedProductResult(
        barcode: '8904083300123',
        productName: 'Milky Mist Processed Cheese Slices',
        brandName: 'Milky Mist',
        category: 'Dairy • Cheese',
        servingSizeG: 20.0,
        sugarGPer100g: 1.5,
        sugarGPerServing: 0.3,
        caloriesPerServing: 62.0,
        healthScore: 46,
        verdictTag: 'Caution 🟠',
        novaGrade: 4,
        redCapTriggered: false,
        safePortionGrams: 20,
        limitingFactor: 'Sodium',
        frequencySchedule: 'Moderate',
        additives: [
          {'ins_code': '331', 'primary_name': 'Sodium Citrates', 'risk_tier': 'YELLOW'},
          {'ins_code': '452', 'primary_name': 'Polyphosphates', 'risk_tier': 'YELLOW'},
        ],
        splitSugars: [],
        portionAdvice: 'Safe portion 20g',
        isExceededBudget: false,
      );

      final swaps = service.getSwapsForProduct(milkyMistCheese);

      expect(swaps.isNotEmpty, isTrue);
      // Must be pure dairy / cheese
      for (final swap in swaps) {
        expect(swap.category, 'Cheese & Dairy');
        expect(swap.productName.toLowerCase(), isNot(contains('peanut')));
        expect(swap.productName.toLowerCase(), isNot(contains('munch')));
        expect(swap.productName.toLowerCase(), isNot(contains('noodle')));
        // Must be equal or better brand tier than Milky Mist (Tier 2)
        expect(swap.brandTier, greaterThanOrEqualTo(2));
        // Health score must improve
        expect(swap.healthScore, greaterThan(milkyMistCheese.healthScore));
      }

      // Check specific top clean brands
      expect(swaps.any((s) => s.brandName == 'Akshayakalpa'), isTrue);
      expect(swaps.any((s) => s.brandName == "D'lecta" || s.brandName == 'Country Delight'), isTrue);
    });

    test('brand tier hierarchy correctly classifies brand tiers', () {
      expect(HealthierSwapsService.getScannedBrandTier('Milky Mist'), 2);
      expect(HealthierSwapsService.getScannedBrandTier('Akshayakalpa'), 3);
      expect(HealthierSwapsService.getScannedBrandTier('The Whole Truth'), 3);
      expect(HealthierSwapsService.getScannedBrandTier('Amul'), 2);
      expect(HealthierSwapsService.getScannedBrandTier('Nestle'), 1);
      expect(HealthierSwapsService.getScannedBrandTier('Maggi'), 1);
    });

    test('getQuickCommerceUrl correctly constructs search URLs for all 4 platforms', () {
      const query = 'Slurrp Farm Millet Noodles';
      const encoded = 'Slurrp%20Farm%20Millet%20Noodles';

      final blinkitUrl = service.getQuickCommerceUrl(QuickCommercePlatform.blinkit, query);
      final zeptoUrl = service.getQuickCommerceUrl(QuickCommercePlatform.zepto, query);
      final instamartUrl = service.getQuickCommerceUrl(QuickCommercePlatform.instamart, query);
      final bigbasketUrl = service.getQuickCommerceUrl(QuickCommercePlatform.bigbasket, query);

      expect(blinkitUrl, 'https://blinkit.com/s/?q=$encoded');
      expect(zeptoUrl, 'https://www.zeptonow.com/search?q=$encoded');
      expect(instamartUrl, 'https://www.swiggy.com/instamart/search?query=$encoded');
      expect(bigbasketUrl, 'https://www.bigbasket.com/ps/?q=$encoded');
    });

    test('getSwapsForCategory returns clean alternatives for cheese and dairy category', () {
      final swaps = service.getSwapsForCategory('Cheese & Dairy');

      expect(swaps.isNotEmpty, isTrue);
      expect(swaps.first.category, 'Cheese & Dairy');
      expect(swaps.any((s) => s.brandName == 'Akshayakalpa'), isTrue);
    });

    test('getSwapsForCategory returns empty list when category has no catalogued clean swaps', () {
      final swaps = service.getSwapsForCategory('Exotic Japanese Seaweed Extract');

      expect(swaps.isEmpty, isTrue);
    });
  });
}
