/// Barcode & QR Code validation, normalization, and GS1 Digital Link resolver for Dart/Flutter.
library;

import 'dart:convert';

/// Represents the detected type of QR code or barcode payload
enum QrScanType {
  barcode,
  productJson,
  foodWebUrl,
  nonFood,
  unknown,
}

/// Structured parse result from a scanned QR code or barcode
class QrScanResult {
  final QrScanType type;
  final String? barcode;
  final Map<String, dynamic>? jsonData;
  final String? nonFoodReason;
  final String rawInput;

  const QrScanResult({
    required this.type,
    this.barcode,
    this.jsonData,
    this.nonFoodReason,
    required this.rawInput,
  });

  bool get isValid =>
      type == QrScanType.barcode ||
      type == QrScanType.productJson ||
      type == QrScanType.foodWebUrl;
  bool get isNonFood => type == QrScanType.nonFood;
  bool get isFoodWebUrl => type == QrScanType.foodWebUrl;

  @override
  String toString() => 'QrScanResult(type: $type, barcode: $barcode, nonFoodReason: $nonFoodReason)';
}

int calculateEan13CheckDigit(String digits12) {
  int s = 0;
  for (int idx = 0; idx < digits12.length; idx++) {
    final weight = (idx % 2 == 0) ? 1 : 3;
    s += int.parse(digits12[idx]) * weight;
  }
  return (10 - (s % 10)) % 10;
}

int calculateEan8CheckDigit(String digits7) {
  int s = 0;
  for (int idx = 0; idx < digits7.length; idx++) {
    final weight = (idx % 2 == 0) ? 3 : 1;
    s += int.parse(digits7[idx]) * weight;
  }
  return (10 - (s % 10)) % 10;
}

/// Detects if a scanned string or URL belongs to non-food domains (laptops, tech support, payments, socials)
bool isKnownNonFood(String input) {
  final lower = input.toLowerCase().trim();

  // Non-food URL schemes
  if (lower.startsWith('tel:') ||
      lower.startsWith('mailto:') ||
      lower.startsWith('smsto:') ||
      lower.startsWith('wifi:') ||
      lower.startsWith('upi:') ||
      lower.startsWith('begin:vcard')) {
    return true;
  }

  // Non-food hardware, tech support, social, or communication domains
  const nonFoodDomains = [
    'wa.me',
    'whatsapp.com',
    'hp.com',
    'support.hp.com',
    'dell.com',
    'lenovo.com',
    'apple.com',
    'microsoft.com',
    'asus.com',
    'samsung.com',
    'intel.com',
    'amd.com',
    'nvidia.com',
    'instagram.com',
    'facebook.com',
    'twitter.com',
    'x.com',
    'linkedin.com',
    'youtube.com',
    't.me',
    'telegram.me',
    'paytm',
    'phonepe',
    'gpay',
  ];

  for (final domain in nonFoodDomains) {
    if (lower.contains(domain)) return true;
  }

  // Check tech support or electronic device keywords in URL
  if (lower.startsWith('http://') || lower.startsWith('https://')) {
    const techKeywords = [
      'support', 'warranty', 'feedback', 'service', 'driver',
      'firmware', 'hardware', 'laptop', 'desktop', 'printer',
      'electronics', 'device', 'manual', 'serial', 'troubleshoot'
    ];
    if (techKeywords.any((kw) => lower.contains(kw))) {
      return true;
    }
  }

  return false;
}

String getNonFoodReason(String input) {
  final lower = input.toLowerCase();
  if (lower.contains('hp.com') || lower.contains('dell') || lower.contains('laptop') || lower.contains('hardware')) {
    return 'Electronics / Laptop Support QR Code';
  }
  if (lower.contains('wa.me') || lower.contains('whatsapp')) {
    return 'WhatsApp Support Link';
  }
  if (lower.startsWith('upi:') || lower.contains('paytm') || lower.contains('phonepe')) {
    return 'Payment / UPI QR Code';
  }
  if (lower.startsWith('wifi:')) {
    return 'Wi-Fi Network QR Code';
  }
  return 'Non-Food Link / Service';
}

/// Detects if a scanned string or URL belongs to food e-commerce, quick-commerce, or brand food websites
bool isFoodWebUrl(String input) {
  final lower = input.toLowerCase().trim();
  if (!lower.startsWith('http://') && !lower.startsWith('https://')) {
    return false;
  }

  // If already identified as non-food hardware/support/payments, reject
  if (isKnownNonFood(lower)) return false;

  // 1. Quick-commerce, grocery platforms, and food delivery marketplaces
  const foodCommerceDomains = [
    'blinkit.com',
    'zeptonow.com',
    'bigbasket.com',
    'instamart',
    'swiggy.com/instamart',
    'naturebasket.co.in',
    'milkbasket.com',
    'dmart.in',
    'jiomart.com',
    'countrydelight.in',
    'freshtohome.com',
    'licious.in',
  ];

  for (final domain in foodCommerceDomains) {
    if (lower.contains(domain)) return true;
  }

  // 2. Verified Indian & Global Food & Beverage Brand Portals
  const foodBrandDomains = [
    'milkymist.com',
    'amul.com',
    'tataconsumerproducts.com',
    'tatacommerce.com',
    'thewholetruthfoods.com',
    'yogabar.in',
    'slurrpfarm.com',
    'epigamia.com',
    'trueelements.com',
    'rawpressery.com',
    'paperboatdrinks.com',
    'motherdairy.com',
    'akshayakalpa.org',
    'dlecta.com',
    'britannia.co.in',
    'haldirams.com',
    'itcportal.com',
    'parleproducts.com',
    'nestle.in',
    'nestle.com',
    'cadbury.com',
    'mondelezinternational.com',
    'kelloggs.com',
    'unilever.com',
  ];

  for (final domain in foodBrandDomains) {
    if (lower.contains(domain)) return true;
  }

  // 3. Nutrition disclosure and label standards
  if (lower.contains('smartlabel.org') ||
      lower.contains('smartlabel.labelinsight.com') ||
      lower.contains('openfoodfacts.org')) {
    return true;
  }

  // 4. Amazon & Flipkart grocery product links
  if (lower.contains('amazon.') &&
      (lower.contains('/dp/') ||
          lower.contains('/gp/product/') ||
          lower.contains('grocery') ||
          lower.contains('pantry'))) {
    return true;
  }
  if (lower.contains('flipkart.com') &&
      (lower.contains('grocery') || lower.contains('food') || lower.contains('/p/'))) {
    return true;
  }

  // 5. Product path indicators in URLs that mention food keywords
  const foodKeywords = [
    'food', 'snack', 'nutrition', 'grocery', 'biscuit', 'cookie',
    'cheese', 'dairy', 'milk', 'paneer', 'butter', 'chocolate',
    'chips', 'cereal', 'beverage', 'drink', 'sauce', 'noodle', 'oil'
  ];

  final hasProductPath = lower.contains('/product/') ||
      lower.contains('/products/') ||
      lower.contains('/prn/') ||
      lower.contains('/pn/') ||
      lower.contains('/pd/') ||
      lower.contains('/item/') ||
      lower.contains('/goods/');

  if (hasProductPath && foodKeywords.any((kw) => lower.contains(kw))) {
    return true;
  }

  return false;
}

/// Parses a scanned QR code or barcode string into a structured QrScanResult.
QrScanResult parseQrOrBarcode(String? rawInput) {
  if (rawInput == null || rawInput.trim().isEmpty) {
    return const QrScanResult(type: QrScanType.unknown, rawInput: '');
  }

  final trimmed = rawInput.trim();

  // Tier 0: Check if it's a known non-food QR code (e.g. laptop WhatsApp support, Wi-Fi, payments)
  if (isKnownNonFood(trimmed)) {
    return QrScanResult(
      type: QrScanType.nonFood,
      rawInput: trimmed,
      nonFoodReason: getNonFoodReason(trimmed),
    );
  }

  // Tier 1: Check for embedded JSON payload in QR code
  if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final hasProductInfo = decoded.containsKey('product_name') ||
            decoded.containsKey('nutrition') ||
            decoded.containsKey('nutrition_json') ||
            decoded.containsKey('ingredients') ||
            decoded.containsKey('ingredients_json');

        final embeddedBarcode = decoded['barcode']?.toString();
        final normalizedBarcode = embeddedBarcode != null ? validateAndNormalizeBarcode(embeddedBarcode) : null;

        if (hasProductInfo) {
          return QrScanResult(
            type: QrScanType.productJson,
            barcode: normalizedBarcode ?? embeddedBarcode,
            jsonData: decoded,
            rawInput: trimmed,
          );
        } else if (normalizedBarcode != null) {
          return QrScanResult(
            type: QrScanType.barcode,
            barcode: normalizedBarcode,
            jsonData: decoded,
            rawInput: trimmed,
          );
        }
      }
    } catch (_) {}
  }

  // Tier 2: Check for GS1 Digital Link in URI (e.g. /01/08901030383786)
  final gs1Match = RegExp(r'/01/(\d{12,14})').firstMatch(trimmed);
  if (gs1Match != null) {
    var gtin = gs1Match.group(1)!;
    if (gtin.length == 14 && gtin.startsWith('0')) {
      gtin = gtin.substring(1);
    }
    final normalized = validateAndNormalizeBarcode(gtin) ?? gtin;
    return QrScanResult(
      type: QrScanType.barcode,
      barcode: normalized,
      rawInput: trimmed,
    );
  }

  // Tier 3: Check for Open Food Facts URL (e.g. /product/3017620422003)
  final offMatch = RegExp(r'/product/(\d{8,14})').firstMatch(trimmed);
  if (offMatch != null) {
    final code = offMatch.group(1)!;
    final normalized = validateAndNormalizeBarcode(code) ?? code;
    return QrScanResult(
      type: QrScanType.barcode,
      barcode: normalized,
      rawInput: trimmed,
    );
  }

  // Tier 4: Check for URL with food query parameters (e.g. ?upc=... or ?barcode=...)
  final uri = Uri.tryParse(trimmed);
  if (uri != null && uri.hasQuery) {
    final queryParams = uri.queryParameters;
    for (final key in ['barcode', 'upc', 'gtin', 'ean', 'code', 'id']) {
      if (queryParams.containsKey(key)) {
        final val = queryParams[key]!;
        final normalized = validateAndNormalizeBarcode(val);
        if (normalized != null) {
          return QrScanResult(
            type: QrScanType.barcode,
            barcode: normalized,
            rawInput: trimmed,
          );
        }
      }
    }
  }

  // Tier 4.5: Check for food e-commerce, quick-commerce, or brand food web URLs
  if (isFoodWebUrl(trimmed)) {
    return QrScanResult(
      type: QrScanType.foodWebUrl,
      rawInput: trimmed,
    );
  }

  // If it's a web URL (http/https) that didn't match any food patterns, mark as non-food!
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return QrScanResult(
      type: QrScanType.nonFood,
      rawInput: trimmed,
      nonFoodReason: 'General Web Link',
    );
  }

  // Tier 5: Check standard 1D barcode digits
  final normalized = validateAndNormalizeBarcode(trimmed);
  if (normalized != null) {
    return QrScanResult(
      type: QrScanType.barcode,
      barcode: normalized,
      rawInput: trimmed,
    );
  }

  // Tier 6: Clean numeric barcode string (8-14 digits)
  final rawDigitsMatch = RegExp(r'^\d{8,14}$').firstMatch(trimmed);
  if (rawDigitsMatch != null) {
    final candidate = rawDigitsMatch.group(0)!;
    final candidateNorm = validateAndNormalizeBarcode(candidate) ?? candidate;
    return QrScanResult(
      type: QrScanType.barcode,
      barcode: candidateNorm,
      rawInput: trimmed,
    );
  }

  return QrScanResult(type: QrScanType.unknown, rawInput: trimmed);
}

/// Validates and normalizes raw barcode string to standard EAN-13, EAN-8, or UPC-A.
String? validateAndNormalizeBarcode(String? rawInput) {
  if (rawInput == null || rawInput.trim().isEmpty) return null;

  var cleaned = rawInput.trim();

  // GS1 Digital Link extraction: e.g. https://id.gs1.org/01/08901030383786
  final gs1Match = RegExp(r'/01/(\d{12,14})').firstMatch(cleaned);
  if (gs1Match != null) {
    final gtin = gs1Match.group(1)!;
    if (gtin.length == 14 && gtin.startsWith('0')) {
      cleaned = gtin.substring(1);
    } else {
      cleaned = gtin;
    }
  }

  // Strip non-digits
  final digits = cleaned.replaceAll(RegExp(r'\D'), '');

  // 1. UPC-A (12 digits) -> convert to 13 digits with leading 0
  if (digits.length == 12) {
    final ean13 = '0$digits';
    if (int.parse(ean13[12]) == calculateEan13CheckDigit(ean13.substring(0, 12))) {
      return ean13;
    }
    return null;
  }

  // 2. EAN-13 (13 digits)
  if (digits.length == 13) {
    if (int.parse(digits[12]) == calculateEan13CheckDigit(digits.substring(0, 12))) {
      return digits;
    }
    return null;
  }

  // 3. EAN-8 (8 digits)
  if (digits.length == 8) {
    if (int.parse(digits[7]) == calculateEan8CheckDigit(digits.substring(0, 7))) {
      return digits;
    }
    return null;
  }

  return null;
}
