import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/camera/presentation/widgets/offline_variant_match_sheet.dart';

void main() {
  testWidgets('OfflineVariantMatchSheet renders brand info and sibling products', (tester) async {
    final siblingProducts = [
      {
        'barcode': '8901058852339',
        'product_name': 'Maggi 2-Minute Noodles Masala',
        'brand_name': 'Nestle',
        'category': 'Instant Noodles',
        'pack_weight_g': 70.0,
        'health_score': 39,
        'nova_grade': 4,
      },
      {
        'barcode': '8901058852360',
        'product_name': 'Maggi Nutri-Licious Veg Atta Noodles',
        'brand_name': 'Nestle',
        'category': 'Instant Noodles',
        'pack_weight_g': 72.5,
        'health_score': 54,
        'nova_grade': 3,
      },
    ];

    Map<String, dynamic>? selectedProduct;
    bool scanOcrTapped = false;
    bool manualEntryTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineVariantMatchSheet(
            barcode: '8901058999999',
            brandName: 'Nestlé India',
            siblingProducts: siblingProducts,
            onSelectProduct: (p) => selectedProduct = p,
            onScanOcr: () => scanOcrTapped = true,
            onManualEntry: () => manualEntryTapped = true,
          ),
        ),
      ),
    );

    // Verify brand badge & title
    expect(find.text('GS1 PREFIX MATCH: Nestlé India'), findsOneWidget);
    expect(find.text('Offline Pack-Size Variant Match'), findsOneWidget);
    expect(find.textContaining('8901058999999'), findsOneWidget);

    // Verify sibling cards
    expect(find.text('Maggi 2-Minute Noodles Masala'), findsOneWidget);
    expect(find.text('Maggi Nutri-Licious Veg Atta Noodles'), findsOneWidget);
    expect(find.text('39'), findsOneWidget);
    expect(find.text('54'), findsOneWidget);
    expect(find.text('NOVA 4'), findsOneWidget);
    expect(find.text('NOVA 3'), findsOneWidget);

    // Tap first sibling card
    await tester.tap(find.text('Maggi 2-Minute Noodles Masala'));
    await tester.pumpAndSettle();
    expect(selectedProduct, isNotNull);
    expect(selectedProduct!['product_name'], 'Maggi 2-Minute Noodles Masala');

    // Tap Scan Label (OCR)
    await tester.tap(find.text('Scan Label (OCR)'));
    await tester.pumpAndSettle();
    expect(scanOcrTapped, isTrue);

    // Tap Enter Macros
    await tester.tap(find.text('Enter Macros'));
    await tester.pumpAndSettle();
    expect(manualEntryTapped, isTrue);
  });
}

