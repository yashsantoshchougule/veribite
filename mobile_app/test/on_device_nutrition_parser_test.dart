import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/vision/on_device_nutrition_parser.dart';

void main() {
  group('OnDeviceNutritionParser Tests', () {
    test('extracts nutrition facts, macros, and serving sizes from raw OCR label text', () {
      const sampleOcrText = '''
BRITANNIA BOURBON BISCUITS
NUTRITION INFORMATION (Approximate values per 100g)
Energy : 492 kcal
Carbohydrates : 72 g
Total Sugars : 38.5 g
Added Sugars : 36 g
Total Fat : 20.0 g
Saturated Fat : 9.5 g
Trans Fat : 0 g
Sodium : 280 mg
Protein : 6.0 g
Dietary Fibre : 2.5 g
Serving Size : 20 g
Net Weight : 150 g
INGREDIENTS: Refined Wheat Flour (Maida), Sugar, Refined Palm Oil, Cocoa Solids (2.3%), Invert Sugar Syrup, Raising Agents (INS 500(ii), INS 503(ii)), Emulsifier (INS 322(i)), Nature Identical Flavouring Substances.
Allergen Information: Contains Wheat and Soy.
Manufactured by Britannia Industries Ltd.
''';

      final result = OnDeviceNutritionParser.parseFromText(sampleOcrText);

      expect(result, isNotNull);
      expect(result!['source'], 'on_device_vision');
      expect(result['brand_name'], 'Britannia');
      expect(result['serving_size_g'], 20.0);
      expect(result['pack_weight_g'], 150.0);

      final nutrition = jsonDecode(result['nutrition_json'] as String) as Map<String, dynamic>;
      expect(nutrition['calories'], 492.0);
      expect(nutrition['energy_kj'], closeTo(492.0 * 4.184, 0.1));
      expect(nutrition['sugar_g_per_100g'], 38.5);
      expect(nutrition['sat_fat_g_per_100g'], 9.5);
      expect(nutrition['sodium_mg_per_100g'], 280.0);
      expect(nutrition['protein_g'], 6.0);
      expect(nutrition['fiber_g'], 2.5);

      final ingredients = jsonDecode(result['ingredients_json'] as String) as List;
      expect(ingredients.any((ing) => ing.toString().contains('Refined Wheat Flour')), isTrue);
      expect(ingredients.any((ing) => ing.toString().contains('Cocoa Solids')), isTrue);

      final additives = jsonDecode(result['additives_json'] as String) as List;
      expect(additives.any((a) => a['ins_code'].toString().contains('322')), isTrue);
      expect(result['nova_grade'], 4);
    });

    test('detects Southampton red dyes (INS 102) and triggers strict red cap locally', () {
      const redDyePackText = '''
Kissan Fruit Squash
Energy: 120 kcal
Total Sugars: 28.0 g
Saturated Fat: 0.0 g
Sodium: 50 mg
Ingredients: Water, Sugar, Fruit Pulp (25%), Acidity Regulator (INS 330), Preservative (INS 211), Synthetic Food Colour (INS 102).
''';

      final result = OnDeviceNutritionParser.parseFromText(redDyePackText);

      expect(result, isNotNull);
      expect(result!['red_cap_triggered'], 1);
      expect(result['health_score'], lessThanOrEqualTo(39));

      final additives = jsonDecode(result['additives_json'] as String) as List;
      final ins102 = additives.firstWhere((a) => a['ins_code'].toString().contains('102'));
      expect(ins102['risk_tier'], 'RED');
      expect(ins102['triggers_red_cap'], 1);
      expect(ins102['child_hyperactivity_flag'], 1);
    });

    test('returns null for unreadable or trivial text', () {
      const trivialText = 'Photo Blur';
      final result = OnDeviceNutritionParser.parseFromText(trivialText);
      expect(result, isNull);
    });
  });
}
