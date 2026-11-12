import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/product_health_scorer.dart';
import 'package:mobile_app/features/health_intelligence/domain/health_intelligence_model.dart';

void main() {
  group('ProductHealthScorer Real-Time Scientific Engine Tests', () {
    test('Profile 1: Plain Whole Grain Oats / Milk evaluates to High Nutri Safe (>= 88) with zero default to 65', () {
      final nutrition = {
        'energy_kcal': 380.0,
        'sugars_100g': 1.1,
        'saturated-fat_100g': 1.2,
        'sodium_mg': 10.0,
        'proteins_100g': 13.0,
        'fiber_100g': 10.5,
      };

      final result = ProductHealthScorer.calculate(
        nutrition: nutrition,
        additives: [],
        ingredients: ['100% Whole Grain Rolled Oats'],
        novaGrade: 1,
      );

      expect(result.score, isNotNull);
      expect(result.score, isNot(65));
      expect(result.score!, greaterThanOrEqualTo(88));
      expect(result.verdictTag, 'Nutri Safe 🟢');
      expect(result.isRedCapped, isFalse);
      expect(result.hasSufficientData, isTrue);
      expect(result.scoreBreakdownSummary, contains('Base 100'));
      expect(result.scoreBreakdownSummary, contains('Protein:'));
      expect(result.scoreBreakdownSummary, contains('Fiber:'));
      expect(result.scoreBreakdownSummary, contains('NOVA 1: +5'));
    });

    test('Profile 2: Masala / Sweet Biscuits evaluates to Moderate Caution (40 - 55) with zero default to 65', () {
      final nutrition = {
        'energy_kcal': 490.0,
        'sugars_100g': 24.5,
        'saturated-fat_100g': 11.2,
        'sodium_mg': 280.0,
        'proteins_100g': 6.5,
        'fiber_100g': 1.8,
      };
      final additives = [
        {'ins_code': '500(ii)', 'primary_name': 'Sodium Bicarbonate', 'risk_tier': 'GREEN'},
        {'ins_code': '503(ii)', 'primary_name': 'Ammonium Bicarbonate', 'risk_tier': 'GREEN'},
        {'ins_code': '322', 'primary_name': 'Lecithin', 'risk_tier': 'GREEN'},
      ];

      final result = ProductHealthScorer.calculate(
        nutrition: nutrition,
        additives: additives,
        ingredients: ['Wheat Flour', 'Sugar', 'Palm Oil', 'Invert Syrup'],
        novaGrade: 4,
      );

      expect(result.score, isNotNull);
      expect(result.score, isNot(65));
      expect(result.score!, inInclusiveRange(38, 55));
      expect(result.verdictTag, 'Caution 🟠');
      expect(result.isRedCapped, isFalse);
      expect(result.scoreBreakdownSummary, contains('Sugar: -20'));
      expect(result.scoreBreakdownSummary, contains('Sat Fat: -12'));
    });

    test('Profile 3: Ultra-Processed Instant Noodles with Red Additive triggers strict Red-Cap (<= 39)', () {
      final nutrition = {
        'energy_kcal': 415.0,
        'sugars_100g': 3.2,
        'saturated-fat_100g': 6.8,
        'sodium_mg': 860.0,
        'proteins_100g': 8.0,
        'fiber_100g': 3.5,
      };
      final additives = [
        {'ins_code': '635', 'primary_name': 'Disodium 5-Ribonucleotides', 'risk_tier': 'RED', 'triggers_red_cap': 1},
        {'ins_code': '451(i)', 'primary_name': 'Pentasodium Triphosphate', 'risk_tier': 'CAUTION'},
      ];

      final result = ProductHealthScorer.calculate(
        nutrition: nutrition,
        additives: additives,
        ingredients: ['Wheat Flour', 'Palm Oil', 'Salt', 'Spices'],
        novaGrade: 4,
      );

      expect(result.score, isNotNull);
      expect(result.score, isNot(65));
      expect(result.score!, lessThanOrEqualTo(39));
      expect(result.isRedCapped, isTrue);
      expect(result.verdictTag, 'Toxic / Capped 🔴');
      expect(result.scoreBreakdownSummary, contains('Red-Cap: Capped to 39'));
    });

    test('Profile 4: Missing nutrition table but ingredients/additives present derives Ingredient-Based Score', () {
      final result = ProductHealthScorer.calculate(
        nutrition: {},
        additives: [
          {'ins_code': '330', 'primary_name': 'Citric Acid', 'risk_tier': 'GREEN'},
        ],
        ingredients: ['Tomatoes', 'Water', 'Sugar', 'Vinegar', 'Spices'],
        novaGrade: 3,
      );

      expect(result.score, isNotNull);
      expect(result.isIngredientOnlyScore, isTrue);
      expect(result.hasSufficientData, isTrue);
      expect(result.scoreBreakdownSummary, contains('Ingredient-Based'));
    });

    test('Profile 5: Completely empty data sets score to null with Insufficient Data', () {
      final result = ProductHealthScorer.calculate(
        nutrition: {},
        additives: [],
        ingredients: [],
      );

      expect(result.score, isNull);
      expect(result.hasSufficientData, isFalse);
      expect(result.isDataIncomplete, isTrue);
      expect(result.verdictTag, 'Insufficient Data');
      expect(result.scoreBreakdownSummary, contains('Insufficient Data'));
    });

    test('All-zero nutrients (0 kcal, 0g fat, 0g sugar, 0g protein, 0mg sodium) with NO ingredients returns insufficientData and NEVER 95', () {
      final allZeroNutrition = {
        'energy_kcal': 0.0,
        'sugars_100g': 0.0,
        'saturated-fat_100g': 0.0,
        'total_fat_g': 0.0,
        'sodium_mg': 0.0,
        'proteins_100g': 0.0,
        'fiber_100g': 0.0,
      };

      final result = ProductHealthScorer.calculate(
        nutrition: allZeroNutrition,
        additives: [],
        ingredients: [],
        novaGrade: 3,
        productName: 'Chess',
      );

      // Must NEVER return 95 or Nutri Safe!
      expect(result.score, isNull);
      expect(result.hasSufficientData, isFalse);
      expect(result.isDataIncomplete, isTrue);
      expect(result.verdictTag, 'Insufficient Data');
    });

    test('All-zero nutrients with ingredients is strictly capped at 70 and labeled as ingredient-only', () {
      final allZeroNutrition = {
        'energy_kcal': 0.0,
        'sugars_100g': 0.0,
        'saturated-fat_100g': 0.0,
        'total_fat_g': 0.0,
        'sodium_mg': 0.0,
        'proteins_100g': 0.0,
      };

      final result = ProductHealthScorer.calculate(
        nutrition: allZeroNutrition,
        additives: [],
        ingredients: ['Milk Solids', 'Salt', 'Active Cultures'],
        novaGrade: 3,
        productName: 'Cheese Product',
      );

      // Must be capped at <= 70 and labeled appropriately
      expect(result.isIngredientOnlyScore, isTrue);
      expect(result.score, isNotNull);
      expect(result.score!, lessThanOrEqualTo(70));
      expect(result.scoreBreakdownSummary, contains('Scored from ingredients only — nutrition table not reported'));
    });

    test('Zero calorie drink (Water / Green Tea) is allowed with 0 macros', () {
      final zeroCalNutrition = {
        'energy_kcal': 0.0,
        'sugars_100g': 0.0,
        'saturated-fat_100g': 0.0,
        'sodium_mg': 5.0,
        'proteins_100g': 0.0,
      };

      final result = ProductHealthScorer.calculate(
        nutrition: zeroCalNutrition,
        additives: [],
        ingredients: ['Purified Water'],
        novaGrade: 1,
        productName: 'Natural Spring Water',
        category: 'Mineral Water',
      );

      expect(result.score, isNotNull);
      expect(result.score!, greaterThanOrEqualTo(90));
      expect(result.isIngredientOnlyScore, isFalse);
    });

    test('Key normalizer converts salt to sodium correctly (1.5g salt -> 600mg sodium)', () {
      final norm = ProductHealthScorer.normalizeNutrients({'salt_100g': 1.5});
      expect(norm.sodiumMg, 600.0);
    });

    test('Key normalizer converts grams of sodium (<= 15.0) to mg (0.35g -> 350mg)', () {
      final norm = ProductHealthScorer.normalizeNutrients({'sodium_100g': 0.35});
      expect(norm.sodiumMg, 350.0);
    });

    test('Key normalizer converts kJ to kcal when kcal key missing (1674 kJ -> ~400 kcal)', () {
      final norm = ProductHealthScorer.normalizeNutrients({'energy_kj': 1673.6});
      expect(norm.energyKcal, closeTo(400.0, 0.5));
    });

    test('Score breakdown formats Final Score as separate token avoiding NOVA concatenation bug', () {
      final result = ProductHealthScorer.calculate(
        nutrition: {
          'energy_kcal': 368.0,
          'sugars_100g': 26.28,
          'saturated-fat_100g': 5.99,
          'sodium_mg': 250.80,
          'proteins_100g': 7.25,
          'fiber_100g': 5.20,
        },
        additives: [
          {'ins_code': '102', 'primary_name': 'Tartrazine', 'risk_tier': 'RED'},
        ],
        ingredients: ['Wheat Flour', 'Sugar', 'Palm Oil'],
        novaGrade: 4,
      );

      expect(result.scoreBreakdownSummary, contains(' | Final Score: '));
      final tokens = result.scoreBreakdownSummary.split(' | ');
      expect(tokens.any((t) => t.contains('NOVA 4')), isTrue);
      expect(tokens.any((t) => t.startsWith('Final Score:')), isTrue);
      // Ensure NOVA and Final Score are distinct elements
      expect(tokens.any((t) => t.contains('NOVA 4') && t.contains('Score:')), isFalse);
    });

    test('Bioactive Senna/stimulant in HealthIntelligence enforces Chronic Caution cap (<= 39)', () {
      const safiIntelligence = HealthIntelligence(
        domain: ProductCategoryDomain.ayurvedicHerbalTonic,
        bioactiveCompounds: [
          BioactiveCompound(
            name: 'Senna (Cassia angustifolia / Sennosides)',
            functionCategory: 'Stimulant Laxative',
            riskLevel: 'caution_chronic_use',
            physiologicalEffect: 'Induces bowel contractions; chronic daily use causes laxative dependence.',
            triggersChronicUseWarning: true,
          ),
        ],
      );

      // Even with zero fat, zero sodium, and low calories:
      final result = ProductHealthScorer.calculate(
        nutrition: {
          'energy_kcal': 120.0,
          'sugars_100g': 5.0,
          'saturated-fat_100g': 0.0,
          'sodium_mg': 20.0,
          'proteins_100g': 0.5,
        },
        additives: [],
        ingredients: ['Senna Extract', 'Water', 'Sugar'],
        novaGrade: 2,
        healthIntelligence: safiIntelligence,
      );

      expect(result.isRedCapped, isTrue);
      expect(result.score, lessThanOrEqualTo(39));
      expect(result.scoreBreakdownSummary, contains('Bioactive Risk: -25'));
      expect(result.scoreBreakdownSummary, contains('Chronic Caution: Capped to 39'));
      expect(result.redCapReason, contains('Clinical Caution: Senna'));
    });

    test('Defensively defends against NaN and Infinity values without crashing', () {
      final badNutrition = {
        'energy_kcal': double.nan,
        'sugars_100g': double.infinity,
        'saturated-fat_100g': -5.0,
        'sodium_mg': 100.0,
        'proteins_100g': 2.0,
      };

      final result = ProductHealthScorer.calculate(
        nutrition: badNutrition,
        additives: [],
        ingredients: ['Wheat'],
        novaGrade: 1,
      );

      // Should safely evaluate with valid numbers without throwing UnsupportedError: NaN
      expect(result.hasSufficientData, isTrue);
      expect(result.score, isNotNull);
      expect(result.score!.isNaN, isFalse);
    });
  });
}
