import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/scoring/scoring_engine.dart';
import 'package:mobile_app/core/scoring/dosage_engine.dart';

void main() {
  group('Dart Scoring Engine', () {
    test('computes solid food Nutri-Score matching 82 for whole grain oats', () {
      final nutrition = {
        'energy_kj': 1550.0,
        'total_sugars_g': 1.0,
        'sat_fat_g': 1.2,
        'sodium_mg': 5.0,
        'fiber_g': 10.0,
        'protein_g': 13.0,
        'fruit_veg_nut_pct': 0.0,
      };
      final score = computeBaseNutriscore(nutrition, isBeverage: false);
      expect(score, 82);
    });

    test('enforces strict 39/100 Hard Red Cap for Red azo dye', () {
      final nutrition = {
        'energy_kj': 1500.0,
        'total_sugars_g': 5.0,
        'sat_fat_g': 0.5,
        'sodium_mg': 100.0,
        'fiber_g': 8.0,
        'protein_g': 10.0,
        'fruit_veg_nut_pct': 50.0,
        'trans_fat_g': 0.0,
      };
      final additives = [
        {
          'ins_code': '102',
          'primary_name': 'Tartrazine',
          'risk_tier': 'RED',
          'triggers_red_cap': 1,
          'child_hyperactivity_flag': 1,
        }
      ];
      final verdict = evaluateProductVerdict(
        nutrition: nutrition,
        additives: additives,
        isBeverage: false,
      );
      expect(verdict['final_score'], lessThanOrEqualTo(39));
      expect(verdict['red_cap_triggered'], isTrue);
      expect(verdict['nova_grade'], 4);
      expect(verdict['red_cap_reason'], contains('Red-Tier Additive Detected'));
    });
  });

  group('Dart Safe Dosage Engine', () {
    test('verifies Orange Cream Biscuit worked example for adult and child', () {
      final nutrition = {
        'sugar_g_per_100g': 32.0,
        'sat_fat_g_per_100g': 14.0,
        'sodium_mg_per_100g': 220.0,
      };
      final additives = [
        {
          'ins_code': '110',
          'primary_name': 'Sunset Yellow FCF',
          'risk_tier': 'RED',
          'jecfa_adi_mg_kg': 4.0,
          'default_conc_mg_per_g': 0.1,
          'child_hyperactivity_flag': 1,
        }
      ];

      // 65 kg Adult
      final adult = calculatePrescribedDosage(
        nutrition: nutrition,
        additives: additives,
        userWeightKg: 65.0,
        isChild: false,
        unitPieceWeightG: 10.0,
      );
      expect(adult['safe_portion_grams'], 16);
      expect(adult['safe_pieces'], 1);
      expect(adult['limiting_factor'], 'Sugar');
      expect(adult['frequency_schedule'], 'Once a Month / Rare Treat');

      // 20 kg Child
      final child = calculatePrescribedDosage(
        nutrition: nutrition,
        additives: additives,
        userWeightKg: 20.0,
        isChild: true,
        unitPieceWeightG: 10.0,
      );
      expect(child['safe_portion_grams'], 5);
      expect(child['safe_pieces'], 0);
      expect(child['frequency_schedule'], 'Complete Avoidance Recommended for Children');
      expect(child['frequency_warning'], contains('Contains Synthetic Azo Dye INS 110'));
    });

    test('normalizes salt to sodium accurately (1.5g salt -> 600mg sodium)', () {
      final raw = {'salt_g': 1.5, 'sodium_mg': null};
      final norm = normalizeAndImputeNutrition(rawNutrition: raw);
      expect(norm['sodium_mg'], 600.0);
    });
  });
}
