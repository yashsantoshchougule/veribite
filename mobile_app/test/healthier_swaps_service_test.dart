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

    test('getSwapsForCategory returns fallback swaps when category is unmapped', () {
      final swaps = service.getSwapsForCategory('Exotic Gourmet Dip');

      expect(swaps.isNotEmpty, isTrue);
      expect(swaps.any((s) => s.brandName == 'The Whole Truth' || s.brandName == 'Open Secret'), isTrue);
    });
  });
}

