import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/vision/barcode_scanner_service.dart';

void main() {
  group('QR Code & Barcode Parser Tests', () {
    test('extracts barcode from GS1 Digital Link QR URI', () {
      const gs1Uri = 'https://id.gs1.org/01/08901030383786?10=BATCH123&21=SER456';
      final result = parseQrOrBarcode(gs1Uri);

      expect(result.isValid, isTrue);
      expect(result.type, QrScanType.barcode);
      expect(result.barcode, '8901030383786');
    });

    test('extracts barcode from Open Food Facts QR URL', () {
      const offUrl = 'https://world.openfoodfacts.org/product/3017620422003/nutella-ferrero';
      final result = parseQrOrBarcode(offUrl);

      expect(result.isValid, isTrue);
      expect(result.type, QrScanType.barcode);
      expect(result.barcode, '3017620422003');
    });

    test('extracts barcode from SmartLabel URL with query parameter', () {
      // UPC-A 12-digits converts to 13 digits with leading 0
      const smartLabelUrl = 'https://smartlabel.labelinsight.com/product/lookup?upc=012345678905';
      final result = parseQrOrBarcode(smartLabelUrl);

      expect(result.isValid, isTrue);
      expect(result.type, QrScanType.barcode);
      expect(result.barcode, '0012345678905');
    });

    test('parses direct JSON embedded product QR payload', () {
      const jsonQr = '''
{
  "product_name": "Organic Almond Milk",
  "brand_name": "Silk",
  "barcode": "8901063012117",
  "category": "Plant Milk",
  "serving_size_g": 240.0,
  "nutrition": {
    "energy_kj": 250.0,
    "sugar_g_per_100g": 3.0,
    "sat_fat_g_per_100g": 0.5,
    "sodium_mg_per_100g": 70.0
  },
  "additives": [
    {"ins_code": "412", "primary_name": "Guar Gum", "risk_tier": "GREEN"}
  ],
  "ingredients": ["Almond Base", "Cane Sugar", "Guar Gum"]
}
''';
      final result = parseQrOrBarcode(jsonQr);

      expect(result.isValid, isTrue);
      expect(result.type, QrScanType.productJson);
      expect(result.jsonData!['product_name'], 'Organic Almond Milk');
      expect(result.barcode, '8901063012117');
    });

    test('parses standard 1D EAN-13 barcode', () {
      const ean13 = '8901063012117'; // Britannia Good Day
      final result = parseQrOrBarcode(ean13);

      expect(result.isValid, isTrue);
      expect(result.type, QrScanType.barcode);
      expect(result.barcode, '8901063012117');
    });

    test('returns unknown for empty or invalid random text', () {
      expect(parseQrOrBarcode(null).isValid, isFalse);
      expect(parseQrOrBarcode('').isValid, isFalse);
      expect(parseQrOrBarcode('   ').isValid, isFalse);
      expect(parseQrOrBarcode('hello world without any digits').isValid, isFalse);
    });
  });
}
