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

    test('Atwater Calorie Sanity Check accurately verifies and corrects glare drift', () {
      // Kreamy Magic values: Protein = 7.25g, Carbs = 60.53g, Total Fat = 10.80g
      // Expected Atwater kcal = 7.25*4 + 60.53*4 + 10.80*9 = 29.0 + 242.12 + 97.2 = 368.3 kcal
      final correctedGlare = OnDeviceNutritionParser.verifyAndCorrectWithAtwater(
        rawKcal: 380.0, // Read as 380 due to plastic glare
        proteinG: 7.25,
        carbsG: 60.53,
        totalFatG: 10.80,
      );
      expect(correctedGlare, 368.0);

      final correctedDecimal = OnDeviceNutritionParser.verifyAndCorrectWithAtwater(
        rawKcal: 36800.0, // Missing decimal point
        proteinG: 7.25,
        carbsG: 60.53,
        totalFatG: 10.80,
      );
      expect(correctedDecimal, 368.0);

      // Value within 10 kcal tolerance is preserved
      final normalPreserved = OnDeviceNutritionParser.verifyAndCorrectWithAtwater(
        rawKcal: 368.0,
        proteinG: 7.25,
        carbsG: 60.53,
        totalFatG: 10.80,
      );
      expect(normalPreserved, 368.0);
    });

    test('Parses 2-column Indian nutrition table and extracts secondary nutrients', () {
      const kreamyMagicText = '''
Kreamy Magic Kwality Cream Pav
Nutritional Values Per 100 g
APPROX VALUE 100g % RDA per 100g % RDA per Serve
Energy (Kcal) 368.00 18.40 14.72
Total Fat (g) 10.80 16.10 12.80
Saturated Fat (g) 5.99 27.20 21.76
Carbohydrate (g) 60.53
Total Sugar (g) 26.28
Added Sugar (g) 15.41 30.80 24.64
Protein (g) 7.25
Cholesterol (mg) 1.00
Sodium (mg) 250.80 12.50 10.00
Dietary Fibre (g) 5.20
INGREDIENTS: Wheat Flour, Sugar, Edible Vegetable Fat, Milk Solids, Yeast, Salt, INS 282, INS 110.
''';

      final result = OnDeviceNutritionParser.parseFromText(kreamyMagicText);
      expect(result, isNotNull);

      final nut = jsonDecode(result!['nutrition_json'] as String) as Map<String, dynamic>;
      expect(nut['calories'], 368.0);
      expect(nut['sugar_g_per_100g'], 26.28);
      expect(nut['added_sugar_g_per_100g'], 15.41);
      expect(nut['sat_fat_g_per_100g'], 5.99);
      expect(nut['total_fat_g_per_100g'], 10.80);
      expect(nut['carbohydrates_g_per_100g'], 60.53);
      expect(nut['protein_g'], 7.25);
      expect(nut['sodium_mg_per_100g'], 250.80);
      expect(nut['cholesterol_mg_per_100g'], 1.00);
      expect(nut['fiber_g'], 5.20);
    });

    test('Parses table gridlines (| / ! I) and filters out SINCE 1936 header noise', () {
      const pickleJarOcrText = '''
SINCE 1936
Siddhivinayak Mango Pickle
NUTRITIONAL INFORMATION
33 Servings per pack 1 Serving Size:15g (1tbsp)
Nutritional Parameters | Per 100g provides approx. | Per Serve provides approx. | Per Serve % RDA*
Energy(kcal) | 153.11 | 22.97 | 1.15
Protein(g) | 3.25 | 0.49 | *
Carbohydrate(g) | 17.23 | 2.58 | *
Total Sugar(g) | 2.57 | 0.39 | -
Total Fat(g) | 7.91 | 1.19 | 1.77
Saturated Fat(g) | 2.44 | 0.37 | 1.66
Trans Fat(g) | 0 | 0.00 | 0.00
*MUFA(g) | 1.85 | 0.28 | *
*PUFA(g) | 3.6 | 0.54 | *
Cholesterol(mg) | 0 | 0.00 | -
Sodium(mg) 3580 | 537.00 | 26.85
Ingredients : Mango Pieces (72%), Salt, Ground Spices, Cotton Seed Oil, Acidity Regulator - (INS 260), Preservative - (INS 211).
''';

      final result = OnDeviceNutritionParser.parseFromText(pickleJarOcrText);
      expect(result, isNotNull);
      // Ensures product name did not pick 'SINCE 1936'
      expect(result!['product_name'], contains('Mango Pickle'));

      final nut = jsonDecode(result['nutrition_json'] as String) as Map<String, dynamic>;
      expect(nut['calories'], 153.11);
      expect(nut['protein_g'], 3.25);
      expect(nut['carbohydrates_g_per_100g'], 17.23);
      expect(nut['sugar_g_per_100g'], 2.57);
      expect(nut['total_fat_g_per_100g'], 7.91);
      expect(nut['sat_fat_g_per_100g'], 2.44);
      expect(nut['sodium_mg_per_100g'], 3580.0);
    });

    test('Infers product name from ingredients when brand is Devanagari and header has serving noise', () {
      const devanagariJarText = '''
NCE 1836
33 Servings per pack 1 Serving Size:15g (1tbsp)
NUTRITIONAL INFORMATION
Nutritional Parameters | Per 100g provides approx.
Energy(kcal) | 153.11
Protein(g) | 3.25
Carbohydrate(g) | 17.23
Total Sugar(g) | 2.57
Total Fat(g) | 7.91
Saturated Fat(g) | 2.44
Sodium(mg) | 3580
Ingredients : Mango Pieces (72%), Salt, Ground Spices, Cotton Seed Oil, Acidity Regulator - (INS 260).
''';

      final result = OnDeviceNutritionParser.parseFromText(devanagariJarText);
      expect(result, isNotNull);
      // Ensures product name does not take 'NCE 1836' or '33 Servings per pack'
      expect(result!['product_name'], 'Mango Pickle');
      expect(result['health_score'], isNotNull);
    });

    test('Handles column-split OCR output where keys and values are grouped in separate blocks', () {
      const columnSplitText = '''
NUTRITIONAL INFORMATION
Energy (kcal)
Protein (g)
Carbohydrate (g)
Total Sugar (g)
Total Fat (g)
Saturated Fat (g)
Sodium (mg)

Per 100g Values
153.11
3.25
17.23
2.57
7.91
2.44
3580

Ingredients: Mango Pieces, Edible Vegetable Oil, Salt, Red Chilli Powder, Mustard, Acidity Regulator INS 260.
''';

      final result = OnDeviceNutritionParser.parseFromText(columnSplitText);
      expect(result, isNotNull);

      final nut = jsonDecode(result!['nutrition_json'] as String) as Map<String, dynamic>;
      expect(nut['calories'], 153.11);
      expect(nut['protein_g'], 3.25);
      expect(nut['carbohydrates_g_per_100g'], 17.23);
      expect(nut['sugar_g_per_100g'], 2.57);
      expect(nut['total_fat_g_per_100g'], 7.91);
      expect(nut['sat_fat_g_per_100g'], 2.44);
      expect(nut['sodium_mg_per_100g'], 3580.0);
    });

    test('Parses Siddhivinayak Mango Pickle jar with NCE 1836 noise, 33 servings, and multi-macro table', () {
      const pickleJarFullOcr = '''
NCE 1836.
33 Servings per pack 1 Serving Size:15g (1tbsp)
NUTRITIONAL INFORMATION
Nutritional Parameters | Per 100g provides approx. | Per Serve provides approx. | Per Serve % RDA*
Energy(kcal) | 153.11 | 22.97 | 1.15
Protein(g) | 3.25 | 0.49 | *
Carbohydrate(g) | 17.23 | 2.58 | *
Total Sugar(g) | 2.57 | 0.39 | *
Total Fat(g) | 7.91 | 1.19 | 1.77
Saturated Fat(g) | 2.44 | 0.37 | 1.66
Trans Fat(g) | 0 | 0.00 | 0.00
*MUFA(g) | 1.85 | 0.28 | *
*PUFA(g) | 3.6 | 0.54 | *
Cholesterol(mg) | 0 | 0.00 | *
Sodium(mg) | 3580 | 537.00 | 26.85
*The Recommended Dietary Allowance (RDA) is calculated on the basis of 2000 calories requirement for an average adult per day.
Ingredients : Mango Pieces (72%), Salt, Ground Spices (Red Chilli, Mustard, Turmeric, Fenugreek, Asafoetida), Cotton Seed Oil, Acidity Regulator - (INS 260), Preservative - (INS 211)
CONTAINS PERMITTED CLASS II PRESERVATIVE
''';

      final result = OnDeviceNutritionParser.parseFromText(pickleJarFullOcr);
      expect(result, isNotNull);

      // Ensures NCE 1836. or table terms were filtered and product identity inferred
      expect(result!['product_name'], 'Mango Pickle');
      expect(result['serving_size_g'], 15.0);
      expect(result['pack_weight_g'], 495.0); // 33 * 15g = 495g

      final nut = jsonDecode(result['nutrition_json'] as String) as Map<String, dynamic>;
      expect(nut['calories'], 153.11);
      expect(nut['protein_g'], 3.25);
      expect(nut['carbohydrates_g_per_100g'], 17.23);
      expect(nut['sugar_g_per_100g'], 2.57);
      expect(nut['total_fat_g_per_100g'], 7.91);
      expect(nut['sat_fat_g_per_100g'], 2.44);
      expect(nut['trans_fat_g_per_100g'], 0.0);
      expect(nut['mufa_g_per_100g'], 1.85);
      expect(nut['pufa_g_per_100g'], 3.6);
      expect(nut['cholesterol_mg_per_100g'], 0.0);
      expect(nut['sodium_mg_per_100g'], 3580.0);

      final additives = jsonDecode(result['additives_json'] as String) as List;
      expect(additives.any((a) => a['ins_code'].toString().contains('260')), isTrue);
      expect(additives.any((a) => a['ins_code'].toString().contains('211')), isTrue);
    });
  });
}
