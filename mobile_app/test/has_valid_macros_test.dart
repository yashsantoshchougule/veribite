import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/intelligence/web_health_intelligence_enricher.dart';
import 'package:mobile_app/features/camera/application/product_scanner_service.dart';

void main() {
  group('ScannedProductResult.hasValidMacros & ProductScannerService.hasValidNutrimentsMap', () {
    test('hasValidMacros returns false when calories and all core macros are 0', () {
      const product = ScannedProductResult(
        barcode: 'test_barcode',
        productName: 'Schezwan Chutney',
        brandName: 'Chings Secret',
        category: 'Sauces & Condiments',
        servingSizeG: 30.0,
        sugarGPer100g: 0.0,
        sugarGPerServing: 0.0,
        caloriesPerServing: 0.0,
        caloriesPer100g: 0.0,
        proteinGPer100g: 0.0,
        carbsGPer100g: 0.0,
        totalFatGPer100g: 0.0,
        healthScore: 70,
        verdictTag: 'Nutri Safe 🟢',
        novaGrade: 3,
        redCapTriggered: false,
        safePortionGrams: 30,
        limitingFactor: 'None',
        frequencySchedule: 'Daily',
        additives: [],
        splitSugars: [],
        portionAdvice: 'Normal portion',
        isExceededBudget: false,
      );

      expect(product.hasValidMacros, isFalse);
    });

    test('hasValidMacros returns true when energy and at least one macro are non-zero', () {
      const product = ScannedProductResult(
        barcode: 'test_barcode',
        productName: 'Schezwan Chutney',
        brandName: 'Chings Secret',
        category: 'Sauces & Condiments',
        servingSizeG: 30.0,
        sugarGPer100g: 14.5,
        sugarGPerServing: 4.35,
        caloriesPerServing: 45.0,
        caloriesPer100g: 150.0,
        carbsGPer100g: 22.0,
        proteinGPer100g: 1.2,
        totalFatGPer100g: 6.0,
        healthScore: 55,
        verdictTag: 'Caution 🟠',
        novaGrade: 4,
        redCapTriggered: false,
        safePortionGrams: 20,
        limitingFactor: 'Sugar',
        frequencySchedule: '2x per week',
        additives: [],
        splitSugars: [],
        portionAdvice: 'Moderate portion',
        isExceededBudget: false,
      );

      expect(product.hasValidMacros, isTrue);
    });

    test('hasValidMacros returns true for zero-calorie exempt items (water, black coffee, green tea)', () {
      const water = ScannedProductResult(
        barcode: 'water_1',
        productName: 'Himalayan Natural Mineral Water',
        brandName: 'Himalayan',
        category: 'Packaged Drinking Water',
        servingSizeG: 250.0,
        sugarGPer100g: 0.0,
        sugarGPerServing: 0.0,
        caloriesPerServing: 0.0,
        caloriesPer100g: 0.0,
        healthScore: 100,
        verdictTag: 'Nutri Safe 🟢',
        novaGrade: 1,
        redCapTriggered: false,
        safePortionGrams: 500,
        limitingFactor: 'None',
        frequencySchedule: 'Unlimited',
        additives: [],
        splitSugars: [],
        portionAdvice: 'Hydrate well',
        isExceededBudget: false,
      );

      expect(water.hasValidMacros, isTrue);
    });

    test('hasValidNutrimentsMap rejects stub with only nova-group or empty macros', () {
      final stubNutriments = {
        'nova-group': 3,
        'nutrition-score-fr': 12,
      };

      expect(
        ProductScannerService.hasValidNutrimentsMap(
          stubNutriments,
          productName: 'Schezwan Chutney',
        ),
        isFalse,
      );
    });

    test('hasValidNutrimentsMap rejects map with only sodium == 0 and no energy', () {
      final stubNutriments = {
        'sodium_100g': 0.0,
        'nova-group': 4,
      };

      expect(
        ProductScannerService.hasValidNutrimentsMap(
          stubNutriments,
          productName: 'Chilli Sauce',
        ),
        isFalse,
      );
    });

    test('hasValidNutrimentsMap accepts map with valid energy and carbs/fats/protein', () {
      final completeNutriments = {
        'energy-kcal_100g': 180.0,
        'carbohydrates_100g': 25.0,
        'sugars_100g': 12.0,
        'fat_100g': 8.0,
        'proteins_100g': 2.0,
        'sodium_100g': 0.8,
      };

      expect(
        ProductScannerService.hasValidNutrimentsMap(
          completeNutriments,
          productName: 'Schezwan Chutney',
        ),
        isTrue,
      );
    });

    test('cleanDomainToBrand extracts clean brand names dynamically without hardcoding', () {
      expect(ProductScannerService.cleanDomainToBrand('www.chingssecret.com'), equals('Chings Secret'));
      expect(ProductScannerService.cleanDomainToBrand('https://everestspices.com/recipes'), equals('Everest Spices'));
      expect(ProductScannerService.cleanDomainToBrand('urbanplatter.in'), equals('Urban Platter'));
      expect(ProductScannerService.cleanDomainToBrand('subdomain.maggi.co.in'), equals('Maggi'));
    });

    test('resolveOfflineKnowledge returns Pending Nutrition Data when macros are missing or 0', () {
      final hiZero = WebHealthIntelligenceEnricher.resolveOfflineKnowledge(
        productName: 'Schezwan Chutney',
        brandName: 'Chings Secret',
        sugarsG: 0.0,
        carbsG: 0.0,
        calories: 0.0,
      );

      expect(hiZero.extendedNutrients.glycemicLoadEstimate, equals('Pending Nutrition Data'));
    });

    test('resolveOfflineKnowledge computes accurate glycemic impact when macros are present', () {
      final hiHigh = WebHealthIntelligenceEnricher.resolveOfflineKnowledge(
        productName: 'Schezwan Chutney',
        brandName: 'Chings Secret',
        sugarsG: 22.0,
        carbsG: 35.0,
        calories: 180.0,
      );

      expect(hiHigh.extendedNutrients.glycemicLoadEstimate, contains('High'));
    });
  });
}
