/// Barcode validation, normalization, and GS1 Digital Link resolver for Dart/Flutter.

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
