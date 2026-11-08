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

    test('detects HP laptop and WhatsApp support QR codes as non-food payloads', () {
      const hpWhatsApp = 'https://wa.me/912261014560?text=HP%20Victus%20Support';
      final res1 = parseQrOrBarcode(hpWhatsApp);
      expect(res1.isNonFood, isTrue);
      expect(res1.isValid, isFalse);
      expect(res1.nonFoodReason, contains('WhatsApp Support'));

      const hpWeb = 'https://support.hp.com/in-en';
      final res2 = parseQrOrBarcode(hpWeb);
      expect(res2.isNonFood, isTrue);
      expect(res2.isValid, isFalse);
      expect(res2.nonFoodReason, contains('Electronics / Laptop Support'));

      const upiQr = 'upi://pay?pa=merchant@upi&pn=RetailStore&am=100';
      final res3 = parseQrOrBarcode(upiQr);
      expect(res3.isNonFood, isTrue);
      expect(res3.isValid, isFalse);
    });

    test('classifies quick-commerce and brand food URLs as foodWebUrl', () {
      const blinkitUrl = 'https://blinkit.com/prn/milky-mist-paneer-fresh/prid/12345';
      final res1 = parseQrOrBarcode(blinkitUrl);
      expect(res1.type, QrScanType.foodWebUrl);
      expect(res1.isValid, isTrue);
      expect(res1.isFoodWebUrl, isTrue);
      expect(res1.isNonFood, isFalse);

      const zeptoUrl = 'https://zeptonow.com/pn/amul-salted-butter-100g/p/456';
      final res2 = parseQrOrBarcode(zeptoUrl);
      expect(res2.type, QrScanType.foodWebUrl);
      expect(res2.isValid, isTrue);

      const bigBasketUrl = 'https://www.bigbasket.com/pd/12345/milky-mist-cooking-butter-500-g/';
      final res3 = parseQrOrBarcode(bigBasketUrl);
      expect(res3.type, QrScanType.foodWebUrl);
      expect(res3.isValid, isTrue);

      const brandUrl = 'https://www.thewholetruthfoods.com/products/dark-chocolate-peanut-butter';
      final res4 = parseQrOrBarcode(brandUrl);
      expect(res4.type, QrScanType.foodWebUrl);
      expect(res4.isValid, isTrue);

      const smartLabelUrl = 'https://smartlabel.org/products/heinz-tomato-ketchup';
      final res5 = parseQrOrBarcode(smartLabelUrl);
      expect(res5.type, QrScanType.foodWebUrl);
      expect(res5.isValid, isTrue);

      // Everest Chole Masala QR codes
      const everestUrl1 = 'https://everestspices.com/product/chole-masala';
      final res6 = parseQrOrBarcode(everestUrl1);
      expect(res6.type, QrScanType.foodWebUrl);
      expect(res6.isNonFood, isFalse);
      expect(res6.isValid, isTrue);

      const everestUrl2 = 'https://www.everestspices.com/recipe/chole-masala';
      final res7 = parseQrOrBarcode(everestUrl2);
      expect(res7.type, QrScanType.foodWebUrl);
      expect(res7.isNonFood, isFalse);
      expect(res7.isValid, isTrue);

      const everestQr = 'https://qr.everestspices.com/p/everest-chole-masala';
      final res8 = parseQrOrBarcode(everestQr);
      expect(res8.type, QrScanType.foodWebUrl);
      expect(res8.isNonFood, isFalse);
      expect(res8.isValid, isTrue);

      // YouTube cooking & recipe video QR codes on Indian spice packaging
      const ytUrl1 = 'https://www.youtube.com/watch?v=recipe123';
      final resYt1 = parseQrOrBarcode(ytUrl1);
      expect(resYt1.type, QrScanType.foodWebUrl);
      expect(resYt1.isNonFood, isFalse);
      expect(resYt1.isValid, isTrue);

      const ytUrl2 = 'https://youtu.be/chole_masala_recipe';
      final resYt2 = parseQrOrBarcode(ytUrl2);
      expect(resYt2.type, QrScanType.foodWebUrl);
      expect(resYt2.isNonFood, isFalse);
      expect(resYt2.isValid, isTrue);
    });

    test('extractGtinFromUrl extracts and normalizes GTINs from various URL schemes', () {
      // 1. GS1 standard digital link with 14-digit GTIN starting with leading 0
      expect(extractGtinFromUrl('https://id.gs1.org/01/08901030383786?10=BATCH'), '8901030383786');

      // 2. Path-based /gtin/ pattern
      expect(extractGtinFromUrl('https://brand.com/gtin/8901234567890'), '8901234567890');

      // 3. Query parameter gtin= with leading 0
      expect(extractGtinFromUrl('https://qrs.ly/spice?gtin=08909876543210'), '8909876543210');

      // 4. Query parameter ean=
      expect(extractGtinFromUrl('https://qrs.ly/product?ean=8901112223334'), '8901112223334');

      // 5. Query parameter barcode=
      expect(extractGtinFromUrl('https://qrs.ly/lookup?barcode=8905556667778'), '8905556667778');

      // 6. Indian 890 embedded in path slug
      expect(extractGtinFromUrl('https://catchfoods.com/products/8901234567890/chana-masala'), '8901234567890');

      // 7. Non-barcode URL returns null
      expect(extractGtinFromUrl('https://everestspices.com/recipes/chole-gravy'), isNull);
    });
  });
}

