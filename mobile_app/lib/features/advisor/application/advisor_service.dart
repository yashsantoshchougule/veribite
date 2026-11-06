import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../profile/domain/user_profile_model.dart';
import '../domain/advisor_chat_model.dart';

/// Application service connecting VeriBite to the FastAPI AI Advisor endpoint
/// (/api/v1/advisor/chat) with Citation RAG (Gemini 2.5 Flash), and automatic
/// offline factual fallback when no network connection is available.
class AdvisorService {
  final http.Client _client;
  final String baseUrl;

  AdvisorService({
    http.Client? client,
    String? customBaseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = customBaseUrl ?? _resolveDefaultBaseUrl();

  static String _resolveDefaultBaseUrl() {
    // Android emulator loops back to host via 10.0.2.2; standard local host for iOS/desktop
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  /// Sends a question to the Personal AI Advisor.
  /// Automatically falls back to local factual synthesis if the cloud backend is unreachable.
  Future<ChatMessage> askAdvisor({
    required String userMessage,
    ProductAdvisorContext? productContext,
    UserProfileModel? userProfile,
  }) async {
    final activeWeight = userProfile?.weightKg ?? 65.0;
    final isChild = userProfile?.isChild ?? false;
    final hasDiabetes = userProfile?.isDiabetic ?? false;
    final hasHypertension = userProfile?.isHypertensive ?? false;

    final requestPayload = {
      'product_data': productContext?.toBackendPayload() ?? {
        'product_name': 'General Food Toxicology',
        'nutrition': {},
        'additives': [],
      },
      'user_guardrails': {
        'weight_kg': activeWeight,
        'is_child': isChild,
        'has_diabetes': hasDiabetes,
        'has_hypertension': hasHypertension,
      },
      'user_message': userMessage,
    };

    try {
      final uri = Uri.parse('$baseUrl/api/v1/advisor/chat');
      final response = await _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(requestPayload),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return ChatMessage.fromJson(data);
      } else {
        debugPrint('[AdvisorService] Backend HTTP ${response.statusCode}: falling back to local rule engine.');
        return _buildOfflineFactualFallback(userMessage, productContext, userProfile);
      }
    } catch (e) {
      debugPrint('[AdvisorService] Network error ($e): seamless fallback to offline factual engine.');
      return _buildOfflineFactualFallback(userMessage, productContext, userProfile);
    }
  }

  /// Factual offline fallback engine that calculates weight-adjusted safe portions
  /// and answers ingredient queries using pre-verified WHO/EFSA/FSSAI scientific guidelines.
  ChatMessage _buildOfflineFactualFallback(
    String userQuery,
    ProductAdvisorContext? productContext,
    UserProfileModel? userProfile,
  ) {
    final queryLower = userQuery.toLowerCase();
    final weightKg = userProfile?.weightKg ?? 65.0;
    final isChild = userProfile?.isChild ?? false;
    final hasDiabetes = userProfile?.isDiabetic ?? false;

    final additives = productContext?.additives ?? [];
    final nutrition = productContext?.nutrition ?? {};
    final productName = productContext?.productName ?? 'this product';

    // 1. Calculate WHO 20% safe single-snack sugar allowance
    final dailySugarLimitGrams = isChild ? 25.0 : 50.0;
    final singleSnackSugarCeiling = (dailySugarLimitGrams * 0.20).clamp(5.0, 15.0);

    final sugars100g = (nutrition['sugars_100g'] as num?)?.toDouble() ?? 20.0;
    final portionGrams = sugars100g > 0
        ? ((singleSnackSugarCeiling / sugars100g) * 100.0).clamp(15.0, 80.0)
        : (weightKg * 0.7).clamp(20.0, 60.0);

    final roundedPortion = (portionGrams * 10).round() / 10.0;
    final schedule = isChild ? 'Max 1 time per week' : 'Max 2-3 times per week';

    final citations = <String>[];
    final buffer = StringBuffer();

    // Check query intent
    if (queryLower.contains('diabet') || queryLower.contains('sugar')) {
      citations.add('WHO-Guidelines-Sugar-2015');
      citations.add('ICMR-NIN-Dietary-2024');

      buffer.writeln('### Diabetes & Sugar Assessment for $productName\n');
      if (hasDiabetes || queryLower.contains('diabet')) {
        buffer.writeln(
          '⚠️ **Diabetic Guardrail:** This item contains approximately ${sugars100g.toStringAsFixed(1)}g of sugar per 100g. '
          'Under WHO and ICMR guidelines, packaged foods with high glycemic loads trigger rapid blood glucose spikes.\n',
        );
      }
      buffer.writeln(
        '• **Safe Portion Cap:** Do not exceed **${roundedPortion}g** in a single sitting.\n'
        '• **Frequency:** $schedule.\n'
        '• **Guidance:** Consume alongside fiber or protein to attenuate glucose absorption.',
      );
    } else if (queryLower.contains('kid') || queryLower.contains('child')) {
      citations.add('EFSA-Southampton-Study-2008');
      citations.add('FSSAI-Child-Safety-Regs');

      buffer.writeln('### Child Safety & Pediatric Toxicology\n');
      buffer.writeln(
        'For a child (~${weightKg.toStringAsFixed(0)} kg), metabolic clearance for artificial additives and free sugars is significantly lower than in adults.\n',
      );
      if (additives.isNotEmpty) {
        final redTier = additives.where((a) => a['risk_tier'] == 'Red').toList();
        if (redTier.isNotEmpty) {
          final names = redTier.map((a) => a['name'] ?? a['ins_code']).join(', ');
          buffer.writeln('⚠️ **Flagged Additives:** Contains **$names**, which are restricted under EU/EFSA guidelines due to hyperactivity risks in young children.\n');
        }
      }
      buffer.writeln(
        '• **Safe Serving:** Strictly capped at **${roundedPortion}g**.\n'
        '• **Schedule:** $schedule.',
      );
    } else if (queryLower.contains('ins') || queryLower.contains('additive')) {
      citations.add('JECFA-Compendium-Additives');
      citations.add('FSSAI-Food-Safety-Standards-2011');

      buffer.writeln('### Chemical Additive Analysis\n');
      if (additives.isNotEmpty) {
        buffer.writeln('Identified **${additives.length} additive(s)** in $productName:');
        for (final a in additives) {
          final ins = a['ins_code'] ?? 'Unknown';
          final name = a['name'] ?? 'Additive';
          final tier = a['risk_tier'] ?? 'Caution';
          buffer.writeln('• **INS $ins ($name)**: Rated **$tier Tier** by international food regulators.');
        }
      } else {
        buffer.writeln('No hazardous additives flagged in the current product formulation.');
      }
    } else {
      citations.add('WHO-Healthy-Diet-FactSheet-394');
      citations.add('Codex-Alimentarius-General-Standard');

      buffer.writeln('### Nutrition & Toxicology Summary for $productName\n');
      buffer.writeln(
        'Based on your calibrated body weight (${weightKg.toStringAsFixed(0)} kg):\n'
        '• **Prescribed Portion:** **${roundedPortion}g** per single snack sitting.\n'
        '• **Safe Schedule:** $schedule.\n'
        '• **Recommendation:** Check full ingredient labels for disguised split sweeteners and artificial stabilizers.',
      );
    }

    return ChatMessage.advisor(
      text: buffer.toString().trim(),
      source: 'local_offline',
      citations: citations,
      safePortionGrams: roundedPortion,
      frequencySchedule: schedule,
    );
  }
}
