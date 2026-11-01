import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/vision/barcode_scanner_service.dart';
import 'package:mobile_app/core/vision/ocr_parser.dart';
import 'package:mobile_app/core/vision/capture_pipeline.dart';

void main() {
  group('Dart Barcode Scanner Service', () {
    test('validates and normalizes EAN-13, EAN-8, and UPC-A', () {
      expect(validateAndNormalizeBarcode('8901030383786'), '8901030383786');
      expect(validateAndNormalizeBarcode('8901030383789'), isNull); // Bad check digit
      expect(validateAndNormalizeBarcode('96385074'), '96385074'); // EAN-8
      expect(validateAndNormalizeBarcode('012345678905'), '0012345678905'); // UPC-A -> EAN-13
    });

    test('extracts GTIN from GS1 Digital Link URL', () {
      const url = 'https://id.gs1.org/01/08901030383786';
      expect(validateAndNormalizeBarcode(url), '8901030383786');
    });
  });

  group('Dart OCR Parser & Glare Detection', () {
    test('extracts nutrition and INS codes from label text', () {
      const sampleOcr = '''
      NUTRITION INFORMATION (Per 100g):
      Energy: 450 kcal
      Total Sugars: 24.0 g
      Saturated Fat: 10.5 g
      Trans Fat: 0.1 g
      Sodium: 350 mg
      Dietary Fibre: 4.0 g
      Protein: 7.0 g
      INGREDIENTS: Refined Wheat Flour, Sugar, Palm Oil, Food Colour (INS 102), Raising Agent (INS 500ii).
      ''';

      final nutrition = parseOcrNutritionTable(sampleOcr);
      expect(nutrition['total_sugars_g'], 24.0);
      expect(nutrition['sat_fat_g'], 10.5);
      expect(nutrition['sodium_mg'], 350.0);

      final ingredients = parseOcrIngredientsAndIns(sampleOcr);
      expect(ingredients['ins_codes'], contains('102'));
    });

    test('detects foil glare when saturated pixels exceed 18%', () {
      final highGlare = List<int>.filled(30, 255) + List<int>.filled(70, 100);
      final res = detectSpecularGlare(highGlare);
      expect(res['is_glare'], isTrue);
      expect(res['badge'], contains('Foil Glare Detected'));
    });
  });

  group('Dart 3-Tier Capture Pipeline Coordinator', () {
    const coordinator = CapturePipelineCoordinator();

    test('routes to Tier 1 when valid barcode detected', () {
      final tier = coordinator.determineTier(rawBarcode: '8901030383786');
      expect(tier, CaptureTier.tier1Barcode);
    });

    test('routes to Tier 2 when OCR confidence is >= 65%', () {
      final tier = coordinator.determineTier(
        rawBarcode: null,
        elapsedScanning: const Duration(milliseconds: 2000),
        ocrConfidence: 0.85,
        isCurvedOrGlare: false,
      );
      expect(tier, CaptureTier.tier2Ocr);
    });

    test('escalates to Tier 3 when OCR confidence is low on online device', () {
      final tier = coordinator.determineTier(
        rawBarcode: null,
        elapsedScanning: const Duration(milliseconds: 2000),
        ocrConfidence: 0.45,
        hasNetwork: true,
      );
      expect(tier, CaptureTier.tier3CloudVision);
    });

    test('falls back to manual slider when offline with poor OCR', () {
      final tier = coordinator.determineTier(
        rawBarcode: null,
        elapsedScanning: const Duration(milliseconds: 2000),
        ocrConfidence: 0.45,
        hasNetwork: false,
      );
      expect(tier, CaptureTier.manualFallback);
    });
  });
}
