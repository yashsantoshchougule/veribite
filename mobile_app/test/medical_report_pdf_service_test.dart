import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/camera/application/product_scanner_service.dart';
import 'package:mobile_app/features/profile/domain/user_profile_model.dart';
import 'package:mobile_app/features/results/application/medical_report_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final testAdultProfile = UserProfileModel.defaults('test_user_adult');
  final testDiabeticChildProfile = UserProfileModel(
    userId: 'test_child_diabetic',
    weightKg: 38.0,
    isChild: true,
    isDiabetic: true,
    isHypertensive: false,
    isCompleted: true,
    updatedAt: DateTime.now(),
  );

  const safeProduct = ScannedProductResult(
    barcode: '8901491101837',
    productName: '100% Whole Grain Rolled Oats',
    brandName: 'Quaker',
    category: 'Breakfast Cereals',
    servingSizeG: 40.0,
    sugarGPer100g: 1.1,
    sugarGPerServing: 0.4,
    caloriesPerServing: 153.0,
    healthScore: 88,
    verdictTag: 'Nutri Safe 🟢',
    novaGrade: 1,
    redCapTriggered: false,
    safePortionGrams: 40,
    safePieces: null,
    limitingFactor: 'Calories',
    frequencySchedule: 'Daily Safe',
    additives: [],
    splitSugars: [],
    portionAdvice: 'Safe consumption portion: 40g (max 1.0 serving). Limiting constraint: Calories.',
    isExceededBudget: false,
  );

  const redCappedProduct = ScannedProductResult(
    barcode: '8901058852339',
    productName: '2-Minute Masala Noodles',
    brandName: 'Maggi',
    category: 'Instant Noodles',
    servingSizeG: 70.0,
    sugarGPer100g: 3.2,
    sugarGPerServing: 2.2,
    caloriesPerServing: 295.0,
    healthScore: 32,
    verdictTag: 'Toxic / Capped 🔴',
    novaGrade: 4,
    redCapTriggered: true,
    safePortionGrams: 25,
    safePieces: null,
    limitingFactor: 'Sodium',
    frequencySchedule: 'Strict 1–2x Per Week',
    additives: [
      {
        'ins_code': '635',
        'primary_name': 'Disodium 5-Ribonucleotides',
        'risk_tier': 'RED',
        'triggers_red_cap': 1,
      },
      {
        'ins_code': '102',
        'primary_name': 'Tartrazine',
        'risk_tier': 'RED',
        'child_hyperactivity_flag': 1,
      },
    ],
    splitSugars: ['Invert Sugar Syrup', 'Liquid Glucose'],
    portionAdvice: 'Safe consumption portion: 25g (max 0.4 serving). Limiting constraint: Sodium.',
    isExceededBudget: false,
  );

  group('MedicalReportPdfService Unit Tests', () {
    final pdfService = MedicalReportPdfService();

    test('generateMedicalReportPdf produces valid PDF bytes for safe product', () async {
      final bytes = await pdfService.generateMedicalReportPdf(
        product: safeProduct,
        userProfile: testAdultProfile,
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(2000));

      // PDF specification requires header to begin with %PDF-
      final header = utf8.decode(bytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });

    test('generateMedicalReportPdf handles red-capped product with split sugars and Southampton additives', () async {
      final bytes = await pdfService.generateMedicalReportPdf(
        product: redCappedProduct,
        userProfile: testDiabeticChildProfile,
        currentServingGrams: 70.0,
        currentSugarGrams: 2.2,
        currentCalories: 295,
        currentSatFatGrams: 6.8,
        currentSodiumMg: 820,
      );

      expect(bytes, isNotEmpty);
      expect(bytes.length, greaterThan(3000));

      final header = utf8.decode(bytes.sublist(0, 5));
      expect(header, equals('%PDF-'));
    });
  });
}
