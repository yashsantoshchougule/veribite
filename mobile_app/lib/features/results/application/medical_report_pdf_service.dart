import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../camera/application/product_scanner_service.dart';
import '../../profile/domain/user_profile_model.dart';

/// Clinical PDF Export Service for VeriBite.
/// Produces publication-grade, multi-page medical and dietitian reports
/// evaluating food toxicology, macro loads, and safe biometric consumption limits.
class MedicalReportPdfService {
  static String _cleanText(String input) {
    return input
        .replaceAll('•', '|')
        .replaceAll('≤', '<=')
        .replaceAll('≥', '>=')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('🟢', '')
        .replaceAll('🟠', '')
        .replaceAll('🔴', '')
        .replaceAll('⚠️', '')
        .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '')
        .trim();
  }
  static const PdfColor colorObsidian = PdfColor.fromInt(0xFF0E1424);
  static const PdfColor colorBronze = PdfColor.fromInt(0xFF8C7A6B);
  static const PdfColor colorSurface = PdfColor.fromInt(0xFFFDFBF7);
  static const PdfColor colorBorder = PdfColor.fromInt(0xFFEAE0D5);
  static const PdfColor colorTextMuted = PdfColor.fromInt(0xFF59524A);

  static const PdfColor colorRed = PdfColor.fromInt(0xFFBA1A1A);
  static const PdfColor colorRedBg = PdfColor.fromInt(0xFFFDF2F2);
  static const PdfColor colorAmber = PdfColor.fromInt(0xFFC05621);
  static const PdfColor colorAmberBg = PdfColor.fromInt(0xFFFDF5EB);
  static const PdfColor colorGreen = PdfColor.fromInt(0xFF137333);
  static const PdfColor colorGreenBg = PdfColor.fromInt(0xFFEBF7EE);

  /// Generates the raw PDF bytes for a clinical medical and dietitian report
  Future<Uint8List> generateMedicalReportPdf({
    required ScannedProductResult product,
    required UserProfileModel userProfile,
    double? currentServingGrams,
    double? currentSugarGrams,
    int? currentCalories,
    double? currentSatFatGrams,
    int? currentSodiumMg,
  }) async {
    final doc = pw.Document(
      title: 'VeriBite Clinical Report - ${product.productName}',
      author: 'VeriBite AI Food Safety & Toxicology Engine',
    );

    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final reportId =
        'VBT-${product.barcode.substring(0, product.barcode.length.clamp(0, 8))}-${now.millisecondsSinceEpoch.toRadixString(36).toUpperCase()}';

    final effectiveServingG = currentServingGrams ?? product.servingSizeG;
    final effectiveSugarG = currentSugarGrams ?? product.sugarGPerServing;
    final effectiveCalories = currentCalories ?? product.caloriesPerServing.round();
    final effectiveSatFatG = currentSatFatGrams ??
        (product.satFatGPerServing > 0 ? product.satFatGPerServing : (product.sugarGPerServing * 0.4));
    final effectiveSodiumMg = currentSodiumMg ??
        (product.sodiumMgPerServing > 0 ? product.sodiumMgPerServing.round() : (product.servingSizeG * 6.5).round());

    final maxSugarCeiling = userProfile.isDiabetic ? 10.0 : (userProfile.isChild ? 19.0 : 25.0);
    final sugarPercentage = ((effectiveSugarG / maxSugarCeiling) * 100).round();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (pw.Context context) => _buildPdfHeader(context, reportId, dateStr),
        footer: (pw.Context context) => _buildPdfFooter(context, reportId),
        build: (pw.Context context) {
          return [
            pw.SizedBox(height: 12),

            // 1. Patient Biometrics & Guardrail Context Box
            _buildPatientContextSection(userProfile, maxSugarCeiling),

            pw.SizedBox(height: 14),

            // 2. Product Identity & Health Verdict Banner
            _buildProductVerdictSection(product),

            pw.SizedBox(height: 14),

            // 3. Red-Cap Strict Alert (if triggered)
            if (product.redCapTriggered) ...[
              _buildRedCapClinicalAlert(product),
              pw.SizedBox(height: 14),
            ],

            // 4. Prescribed Safe Consumption Portion & Frequency
            _buildSafeDosagePrescription(product),

            pw.SizedBox(height: 14),

            // 5. Macro & Micro Nutritional Breakdown Table
            _buildNutritionTable(
              product: product,
              servingG: effectiveServingG,
              sugarG: effectiveSugarG,
              calories: effectiveCalories,
              satFatG: effectiveSatFatG,
              sodiumMg: effectiveSodiumMg,
              maxSugarCeiling: maxSugarCeiling,
              sugarPct: sugarPercentage,
            ),

            pw.SizedBox(height: 14),

            // 6. Anti-Splitting Sweetener Cluster Alert (if detected)
            if (product.splitSugars.isNotEmpty) ...[
              _buildSugarSplittingAlert(product.splitSugars),
              pw.SizedBox(height: 14),
            ],

            // 7. Full Chemical Additives & Toxicology Roster Table
            _buildAdditivesTable(product.additives),

            pw.SizedBox(height: 16),

            // 8. Clinical Sign-off & Medical Disclaimer
            _buildClinicalSignOffSection(),
          ];
        },
      ),
    );

    return doc.save();
  }

  /// Triggers native printing or PDF save dialog
  Future<void> printReport({
    required BuildContext context,
    required ScannedProductResult product,
    required UserProfileModel userProfile,
    double? currentServingGrams,
    double? currentSugarGrams,
    int? currentCalories,
    double? currentSatFatGrams,
    int? currentSodiumMg,
  }) async {
    final pdfBytes = await generateMedicalReportPdf(
      product: product,
      userProfile: userProfile,
      currentServingGrams: currentServingGrams,
      currentSugarGrams: currentSugarGrams,
      currentCalories: currentCalories,
      currentSatFatGrams: currentSatFatGrams,
      currentSodiumMg: currentSodiumMg,
    );

    await Printing.layoutPdf(
      name: 'VeriBite_Medical_Report_${product.barcode}.pdf',
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  /// Triggers native share sheet (WhatsApp, Email, Files, Cloud)
  Future<void> shareReport({
    required BuildContext context,
    required ScannedProductResult product,
    required UserProfileModel userProfile,
    double? currentServingGrams,
    double? currentSugarGrams,
    int? currentCalories,
    double? currentSatFatGrams,
    int? currentSodiumMg,
  }) async {
    final pdfBytes = await generateMedicalReportPdf(
      product: product,
      userProfile: userProfile,
      currentServingGrams: currentServingGrams,
      currentSugarGrams: currentSugarGrams,
      currentCalories: currentCalories,
      currentSatFatGrams: currentSatFatGrams,
      currentSodiumMg: currentSodiumMg,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'VeriBite_Medical_Report_${product.barcode}.pdf',
    );
  }

  // =========================================================================
  // PDF WIDGET BUILDERS
  // =========================================================================

  static pw.Widget _buildPdfHeader(pw.Context context, String reportId, String dateStr) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(color: colorBorder, width: 1.0)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'VERIBITE CLINICAL TOXICOLOGY & NUTRITION DOSAGE REPORT',
                style: const pw.TextStyle(
                  fontSize: 10.5,
                  fontWeight: pw.FontWeight.bold,
                  color: colorObsidian,
                ),
              ),
              pw.Text(
                'Evidence-Based Chemical & Biometric Food Safety Dossier',
                style: const pw.TextStyle(fontSize: 8, color: colorBronze),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('Report ID: $reportId', style: const pw.TextStyle(fontSize: 8, color: colorTextMuted)),
              pw.Text('Evaluated: $dateStr', style: const pw.TextStyle(fontSize: 8, color: colorTextMuted)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfFooter(pw.Context context, String reportId) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: colorBorder, width: 0.8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'VeriBite AI Safety & Dosage Engine v1.0 | WHO / JECFA / EFSA Harmonized Standards',
            style: const pw.TextStyle(fontSize: 7.5, color: colorTextMuted),
          ),
          pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: colorObsidian),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildPatientContextSection(UserProfileModel profile, double maxSugarCeiling) {
    final weightStr = '${profile.weightKg.toStringAsFixed(0)} kg';
    final stageStr = profile.isChild ? 'Pediatric (<18 yrs)' : 'Adult';
    final guardStr = profile.isDiabetic
        ? 'Diabetic Guard Active (10g Cap)'
        : (profile.isHypertensive ? 'Hypertension Guard Active' : 'Standard Baseline');

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: colorSurface,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: colorBorder, width: 1.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'PATIENT BIOMETRIC CONTEXT & GUARDRAIL CEILINGS',
                style: const pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: colorObsidian),
              ),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: colorObsidian,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  guardStr,
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.white),
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Client Weight: $weightStr', style: const pw.TextStyle(fontSize: 8.5, color: colorTextMuted)),
              pw.Text('Life Stage: $stageStr', style: const pw.TextStyle(fontSize: 8.5, color: colorTextMuted)),
              pw.Text(
                'WHO Daily Free Sugar Ceiling: ${maxSugarCeiling.toStringAsFixed(0)}g',
                style: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: colorObsidian),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildProductVerdictSection(ScannedProductResult product) {
    final scoreColor = product.healthScore >= 70
        ? colorGreen
        : (product.healthScore >= 40 ? colorAmber : colorRed);
    final scoreBg = product.healthScore >= 70
        ? colorGreenBg
        : (product.healthScore >= 40 ? colorAmberBg : colorRedBg);

    String novaDesc = 'Ultra-Processed (Nova 4)';
    if (product.novaGrade == 1) novaDesc = 'Unprocessed / Minimally Processed (Nova 1)';
    if (product.novaGrade == 2) novaDesc = 'Processed Culinary Ingredient (Nova 2)';
    if (product.novaGrade == 3) novaDesc = 'Processed Food (Nova 3)';

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: colorSurface,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: colorBorder, width: 1.0),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Left: Product Identity
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  product.productName,
                  style: const pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: colorObsidian),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${_cleanText(product.brandName)} | ${_cleanText(product.category)}',
                  style: const pw.TextStyle(fontSize: 9.5, color: colorTextMuted),
                ),
                pw.Text(
                  'Barcode: ${product.barcode} | Pack Net Weight: ${product.packWeightG > 0 ? product.packWeightG.toStringAsFixed(0) : "N/A"}g',
                  style: const pw.TextStyle(fontSize: 8, color: colorBronze),
                ),
                pw.SizedBox(height: 6),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: pw.BoxDecoration(
                    color: product.novaGrade >= 4 ? colorRedBg : colorGreenBg,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(
                      color: product.novaGrade >= 4 ? colorRed : colorGreen,
                      width: 0.5,
                    ),
                  ),
                  child: pw.Text(
                    novaDesc,
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: product.novaGrade >= 4 ? colorRed : colorGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 14),

          // Right: Health Score Gauge Badge
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: scoreBg,
              borderRadius: pw.BorderRadius.circular(8),
              border: pw.Border.all(color: scoreColor, width: 1.2),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'HEALTH SCORE',
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: scoreColor),
                ),
                pw.Text(
                  '${product.healthScore}',
                  style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold, color: scoreColor),
                ),
                pw.Text(
                  _cleanText(product.verdictTag),
                  style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: scoreColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildRedCapClinicalAlert(ScannedProductResult product) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: colorRedBg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: colorRed, width: 1.0),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              color: colorRed,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Text(
              'RED CAP',
              style: const pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            ),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'STRICT TOXICOLOGY RED-CAP OVERRIDE TRIGGERED',
                  style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: colorRed),
                ),
                pw.Text(
                  'This product contains one or more hazardous chemical additives flagged by WHO/EFSA (banned food dyes, suspected endocrine disruptors, or hazardous artificial preservatives). Health score is strictly capped at <= 39/100.',
                  style: const pw.TextStyle(fontSize: 8, color: colorRed),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSafeDosagePrescription(ScannedProductResult product) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: colorSurface,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: colorBorder, width: 1.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PRESCRIBED SAFE CONSUMPTION PORTION & FREQUENCY CEILING',
            style: const pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: colorObsidian),
          ),
          pw.SizedBox(height: 6),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Prescribed Max Portion', style: const pw.TextStyle(fontSize: 8, color: colorTextMuted)),
                  pw.Text(
                    '${product.safePortionGrams} g ${product.safePieces != null ? "(${product.safePieces} pcs)" : ""}',
                    style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: colorObsidian),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Consumption Frequency', style: const pw.TextStyle(fontSize: 8, color: colorTextMuted)),
                  pw.Text(
                    _cleanText(product.frequencySchedule),
                    style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: colorBronze),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Limiting Constraint', style: const pw.TextStyle(fontSize: 8, color: colorTextMuted)),
                  pw.Text(
                    _cleanText(product.limitingFactor),
                    style: const pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: colorRed),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            _cleanText(product.portionAdvice),
            style: const pw.TextStyle(fontSize: 8.5, color: colorTextMuted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildNutritionTable({
    required ScannedProductResult product,
    required double servingG,
    required double sugarG,
    required int calories,
    required double satFatG,
    required int sodiumMg,
    required double maxSugarCeiling,
    required int sugarPct,
  }) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: colorSurface,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: colorBorder, width: 1.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: pw.Text(
              'MACRONUTRIENT & WHO THRESHOLD ANALYSIS (Per ${servingG.toStringAsFixed(0)}g Serving)',
              style: const pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: colorObsidian),
            ),
          ),
          pw.TableHelper.fromTextArray(
            headerStyle: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: colorObsidian),
            headerDecoration: const pw.BoxDecoration(color: colorBorder),
            cellStyle: const pw.TextStyle(fontSize: 8, color: colorTextMuted),
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
            data: [
              ['Nutrient', 'Per 100g', 'Per Current Portion', 'WHO Daily Limit', 'Clinical Status'],
              [
                'Calories',
                '${((product.caloriesPerServing / (product.servingSizeG > 0 ? product.servingSizeG : 30)) * 100).round()} kcal',
                '$calories kcal',
                '2000 kcal',
                calories > 350 ? 'High Energy Density' : 'Moderate',
              ],
              [
                'Total Sugars',
                '${product.sugarGPer100g.toStringAsFixed(1)} g',
                '${sugarG.toStringAsFixed(1)} g',
                '${maxSugarCeiling.toStringAsFixed(0)} g',
                sugarPct >= 100
                    ? 'EXCEEDED ($sugarPct% Daily)'
                    : (sugarPct >= 50 ? 'ELEVATED ($sugarPct% Daily)' : 'Safe ($sugarPct% Daily)'),
              ],
              [
                'Saturated Fat',
                '${product.satFatGPer100g > 0 ? product.satFatGPer100g.toStringAsFixed(1) : "N/A"} g',
                '${satFatG.toStringAsFixed(1)} g',
                '20 g',
                satFatG > 5.0 ? 'High Lipid Load' : 'Safe',
              ],
              [
                'Sodium',
                '${product.sodiumMgPer100g > 0 ? product.sodiumMgPer100g.toStringAsFixed(0) : "N/A"} mg',
                '$sodiumMg mg',
                '2000 mg',
                sodiumMg > 400 ? 'High Sodium Ceiling' : 'Safe',
              ],
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildSugarSplittingAlert(List<String> splitSugars) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: colorAmberBg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: colorAmber, width: 1.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: colorAmber,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'SUGAR SPLITTING DETECTED',
                  style: const pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                ),
              ),
              pw.SizedBox(width: 6),
              pw.Text(
                'Hidden Sweetener Cluster Alert',
                style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: colorAmber),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'The manufacturer splits added sugars across ${splitSugars.length} distinct aliases to keep refined sugar lower on the ingredients list: ${splitSugars.join(", ")}. Aggregate glycemic load is significantly higher than indicated by any single ingredient position.',
            style: const pw.TextStyle(fontSize: 8, color: colorTextMuted),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildAdditivesTable(List<Map<String, dynamic>> additives) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: colorSurface,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: colorBorder, width: 1.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'CHEMICAL ADDITIVES & TOXICOLOGY ROSTER (${additives.length})',
                  style: const pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: colorObsidian),
                ),
                pw.Text(
                  'JECFA & Codex Alimentarius Standard',
                  style: const pw.TextStyle(fontSize: 8, color: colorBronze),
                ),
              ],
            ),
          ),
          if (additives.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Text(
                'Zero chemical food additives, artificial colorants, or synthetic preservatives detected in this product.',
                style: const pw.TextStyle(fontSize: 8.5, color: colorGreen, fontWeight: pw.FontWeight.bold),
              ),
            )
          else
            pw.TableHelper.fromTextArray(
              headerStyle: const pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: colorObsidian),
              headerDecoration: const pw.BoxDecoration(color: colorBorder),
              cellStyle: const pw.TextStyle(fontSize: 8, color: colorTextMuted),
              cellAlignment: pw.Alignment.centerLeft,
              headerAlignment: pw.Alignment.centerLeft,
              data: [
                ['INS / E-Code', 'Primary Chemical Name', 'Risk Tier', 'Function / Warning'],
                ...additives.map((a) {
                  final code = a['ins_code']?.toString() ?? a['code']?.toString() ?? 'INS';
                  final name = a['primary_name']?.toString() ?? a['name']?.toString() ?? 'Additive';
                  final tier = a['risk_tier']?.toString() ?? 'SAFE';
                  final warning = a['child_hyperactivity_flag'] == 1
                      ? 'Southampton Six (Child Hyperactivity)'
                      : (a['triggers_red_cap'] == 1 ? 'Hard Red-Cap Flag' : 'Codex Standard');

                  return [
                    'INS $code',
                    name,
                    tier,
                    warning,
                  ];
                }),
              ],
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildClinicalSignOffSection() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: colorSurface,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: colorBorder, width: 1.0),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CLINICAL REVIEW DISCLAIMER & PRACTITIONER SIGN-OFF',
            style: const pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: colorObsidian),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'This report is generated by VeriBite for clinical dietary consultation and patient education. Toxicological findings, ADI limits, and red-cap alerts are cross-referenced against WHO/JECFA, EFSA, and Codex standards. Patients should review these recommendations with their attending physician or certified clinical dietitian before making clinical dietary adjustments.',
            style: const pw.TextStyle(fontSize: 7.5, color: colorTextMuted),
          ),
          pw.SizedBox(height: 16),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 140, height: 1, color: colorObsidian),
                  pw.SizedBox(height: 3),
                  pw.Text('Consulting Physician / Dietitian', style: const pw.TextStyle(fontSize: 7.5, color: colorTextMuted)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 100, height: 1, color: colorObsidian),
                  pw.SizedBox(height: 3),
                  pw.Text('License / Reg. Number', style: const pw.TextStyle(fontSize: 7.5, color: colorTextMuted)),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(width: 80, height: 1, color: colorObsidian),
                  pw.SizedBox(height: 3),
                  pw.Text('Consultation Date', style: const pw.TextStyle(fontSize: 7.5, color: colorTextMuted)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
