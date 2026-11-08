/// Barcode & QR Code validation, normalization, and GS1 Digital Link resolver for Dart/Flutter.
library;

import 'dart:convert';

/// Represents the detected type of QR code or barcode payload
enum QrScanType {
  barcode,
  productJson,
  unknown,
}

/// Structured parse result from a scanned QR code or barcode
class QrScanResult {
  final QrScanType type;
  final String? barcode;
  final Map<String, dynamic>? jsonData;
  final String rawInput;

  const QrScanResult({
    required this.type,
    this.barcode,
    this.jsonData,
    required this.rawInput,
  });

  bool get isValid => type != QrScanType.unknown;

  @override
  String toString() => 'QrScanResult(type: $type, barcode: $barcode, hasJson: ${jsonData != null})';
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

/// Parses a scanned QR code or barcode string into a structured QrScanResult.
/// Seamlessly handles:
/// 1. Embedded JSON product payloads inside QR codes.
/// 2. GS1 Digital Link URIs (e.g. https://id.gs1.org/01/08901030383786).
/// 3. Open Food Facts product URLs (e.g. https://world.openfoodfacts.org/product/3017620422003).
/// 4. SmartLabel / Brand QR URLs with query parameters (?upc=, ?gtin=, ?barcode=).
/// 5. URL path segments containing product barcode digits.
/// 6. Standard 1D barcode numbers (EAN-13, EAN-8, UPC-A).
QrScanResult parseQrOrBarcode(String? rawInput) {
  if (rawInput == null || rawInput.trim().isEmpty) {
    return const QrScanResult(type: QrScanType.unknown, rawInput: '');
  }

  final trimmed = rawInput.trim();

  // Tier 1: Check for embedded JSON payload in QR code
  if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        // If it's a JSON containing product data
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
    } catch (_) {
      // Not valid JSON, continue with URI/barcode checks
    }
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

  // Tier 4: Check for URL with query parameters (e.g. ?upc=... or ?barcode=...)
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

  // Tier 5: Check URL path segments for barcode digits
  if (uri != null && uri.pathSegments.isNotEmpty) {
    for (final seg in uri.pathSegments) {
      final digits = seg.replaceAll(RegExp(r'\D'), '');
      if (digits.length >= 8 && digits.length <= 14) {
        final normalized = validateAndNormalizeBarcode(digits);
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

  // Tier 6: Check standard 1D barcode digits
  final normalized = validateAndNormalizeBarcode(trimmed);
  if (normalized != null) {
    return QrScanResult(
      type: QrScanType.barcode,
      barcode: normalized,
      rawInput: trimmed,
    );
  }

  // Tier 7: If contains a clean run of 8-14 digits anywhere in text
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
