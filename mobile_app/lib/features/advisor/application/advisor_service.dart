import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../core/config/gemini_config.dart';
import '../../../core/network/client_rate_limiter.dart';
import '../../../core/scoring/dosage_engine.dart';
import '../../../core/scoring/offline_additive_knowledge_base.dart';
import '../../../services/multi_provider_ai_router.dart';
import '../../camera/application/offline_barcode_repository.dart';
import '../../profile/domain/user_profile_model.dart';
import '../domain/advisor_chat_model.dart';
import '../domain/advisor_rules.dart';

/// Exception thrown when remote API signals HTTP 429 Too Many Requests
class RateLimitException implements Exception {
  final int retryAfterSeconds;
  const RateLimitException([this.retryAfterSeconds = 15]);

  @override
  String toString() => 'RateLimitException: retry after $retryAfterSeconds seconds';
}

/// Application service connecting VeriBite to Google Gemini Live AI & Groq LPU
/// with Citation RAG grounding, strict domain & identity guardrails,
/// Tier 0 instant local clinical & additive short-circuit (<100ms),
/// in-memory session circuit breaker for backend proxy,
/// and parallel hedged cloud AI routing (<= 1.5s).
class AdvisorService {
  final http.Client _client;
  final String? customBaseUrl;
  final ClientRateLimiter rateLimiter;
  final MultiProviderAiRouter? _injectedAiRouter;

  /// In-memory session circuit breaker for dead backend endpoints
  static bool _backendCircuitBroken = false;
  static void resetBackendCircuit() => _backendCircuitBroken = false;

  AdvisorService({
    http.Client? client,
    this.customBaseUrl,
    ClientRateLimiter? rateLimiter,
    MultiProviderAiRouter? aiRouter,
  })  : _client = client ?? http.Client(),
        rateLimiter = rateLimiter ?? ClientRateLimiter(),
        _injectedAiRouter = aiRouter;

  late final MultiProviderAiRouter _aiRouter = _injectedAiRouter ??
      MultiProviderAiRouter(
        httpClient: _client,
      );

  /// Checks if query is asking for direct factual product/macro/additive/dosage facts
  bool _isFactualProductQuestion(String query) {
    final lower = query.toLowerCase();
    const factualKeywords = [
      'sugar', 'sugars', 'sodium', 'salt', 'fat', 'saturated fat', 'trans fat',
      'carb', 'carbs', 'carbohydrate', 'protein', 'cholesterol', 'colestrol',
      'calorie', 'calories', 'energy', 'kcal', 'fibre', 'fiber',
      'portion', 'how much', 'serving', 'dose', 'dosage', 'grams', 'how many',
      'can i eat', 'safe to eat', 'safe limit', 'limit', 'intake', 'quantity',
      'diabetes', 'diabetic', 'blood pressure', 'hypertension', 'high bp',
      'child', 'kid', 'pediatric', 'safe for kid',
      'additive', 'additives', 'chemical', 'ins', 'e-number',
      'nova', 'health score', 'score', 'rating', 'why is score'
    ];
    return factualKeywords.any((k) => lower.contains(k));
  }

  bool _isUnindexedWebSearchRequired(String query) {
    final lower = query.toLowerCase();
    return lower.contains('latest news') ||
        lower.contains('recall') ||
        lower.contains('new brand') ||
        lower.contains('recent study');
  }

  /// Primary query method:
  /// 0. Enforces early domain boundary, identity guardrails & in-app guide.
  /// 1. TIER 0: Instant on-device clinical & additive short-circuit (<100ms).
  /// 2. If custom backend is configured, queries proxy with 800ms circuit breaker.
  /// 3. STEP 3: Ultra-low-latency cloud AI routing (Groq LPU primary + 2.2s hedged Gemini Flash).
  /// 4. Seamlessly falls back to local offline factual regulatory engine on errors.
  Future<ChatMessage> askAdvisor({
    required String userMessage,
    ProductAdvisorContext? productContext,
    UserProfileModel? userProfile,
  }) async {
    // 0. Early Guardrail Checks: Out-of-scope refusal & AI identity protection
    if (AdvisorRules.isOutOfScope(userMessage, productContext)) {
      return ChatMessage.advisor(
        text: AdvisorRules.outOfScopeRefusal,
        source: 'veribite_guardrail',
      );
    }

    if (AdvisorRules.isIdentityQuery(userMessage)) {
      return ChatMessage.advisor(
        text: AdvisorRules.identityResponse,
        source: 'veribite_guardrail',
      );
    }

    if (AdvisorRules.isAppHelpQuery(userMessage)) {
      return ChatMessage.advisor(
        text: AdvisorRules.buildAppHelpResponse(userMessage),
        source: 'veribite_app_guide',
        citations: ['VeriBite User Guide', 'FSSAI Consumer Guidelines'],
      );
    }

    // -------------------------------------------------------------------------
    // TIER 0: INSTANT ON-DEVICE CLINICAL & ADDITIVE SHORT-CIRCUIT (<100ms)
    // -------------------------------------------------------------------------
    // Check 1: Additive & Chemical Toxicology lookup (INS/E codes, MSG, sweeteners, colours)
    await OfflineAdditiveKnowledgeBase.instance.ensureInitialized();
    final additiveMatch = OfflineAdditiveKnowledgeBase.instance.lookupQuery(userMessage);
    if (additiveMatch != null) {
      debugPrint('[AdvisorService] Tier 0 Instant Hit: Additive ${additiveMatch['primary_name']} (<10ms).');
      return OfflineAdditiveKnowledgeBase.instance.buildClinicalAdditiveReport(
        additiveMatch,
        userProfile: userProfile,
      );
    }

    // Check 2: Active Product Context Factual Query (macros, safe portions, conditions)
    if (productContext != null && _isFactualProductQuestion(userMessage)) {
      debugPrint('[AdvisorService] Tier 0 Instant Hit: Active Product Factual Inquiry (<10ms).');
      return _buildOfflineFactualFallback(userMessage, productContext, userProfile);
    }

    // Check 3: Query matches offline seed/cached barcode database when productContext is null
    if (productContext == null) {
      try {
        await OfflineBarcodeRepository.instance.ensureInitialized();
        final localMatches = await OfflineBarcodeRepository.instance.searchByQuery(userMessage);
        if (localMatches.isNotEmpty) {
          final topMatch = localMatches.first;
          final hydratedContext = ProductAdvisorContext(
            productName: topMatch['product_name'] ?? 'Packaged Food',
            brandName: topMatch['brand_name'],
            category: topMatch['category'],
            barcode: topMatch['barcode'] ?? '',
            healthScore: (topMatch['health_score'] as num?)?.toInt() ?? 50,
            novaGrade: (topMatch['nova_grade'] as num?)?.toInt() ?? 4,
            nutrition: topMatch['nutrition'] as Map<String, dynamic>? ?? {},
            additives: (topMatch['additives'] as List<dynamic>?)
                    ?.map((e) => e as Map<String, dynamic>)
                    .toList() ??
                [],
            ingredients: (topMatch['ingredients'] as List<dynamic>?)
                    ?.map((e) => e.toString())
                    .toList() ??
                [],
          );
          if (_isFactualProductQuestion(userMessage) || userMessage.trim().split(' ').length <= 4) {
            debugPrint('[AdvisorService] Tier 0 Instant Hit: Seed Catalog Match "${hydratedContext.productName}" (<25ms).');
            return _buildOfflineFactualFallback(userMessage, hydratedContext, userProfile);
          }
        }
      } catch (_) {}
    }

    final activeUserId = userProfile?.userId ?? 'anonymous';

    // Rate Limit Guard: client-side debounce and quota enforcement per user
    if (!rateLimiter.canSendRequest(null, activeUserId)) {
      final waitSec = rateLimiter.getRemainingCooldownSeconds(null, activeUserId);
      return ChatMessage.advisor(
        text: 'You have reached the maximum rate of 4 requests per minute for your account. Please wait ${waitSec}s before sending another question.\n\nIn the meantime, feel free to inspect the scientific food information on your screen!',
        source: 'veribite_guardrail',
      );
    }
    rateLimiter.recordRequest(null, activeUserId);

    bool isRateLimited = false;
    int retryAfter = 15;

    // -------------------------------------------------------------------------
    // STEP 1: BACKEND PROXY (STRICT 800ms TIMEOUT & IN-MEMORY CIRCUIT BREAKER)
    // -------------------------------------------------------------------------
    final hasExplicitCustomUrl = customBaseUrl != null &&
        customBaseUrl!.trim().isNotEmpty &&
        (!kReleaseMode || (!customBaseUrl!.contains('127.0.0.1') && !customBaseUrl!.contains('10.0.2.2') && !customBaseUrl!.contains('localhost')));

    if (hasExplicitCustomUrl && !_backendCircuitBroken) {
      try {
        final backendRes = await _askBackendProxy(
          userMessage: userMessage,
          productContext: productContext,
          userProfile: userProfile,
        );
        if (backendRes != null) return backendRes;
      } on RateLimitException catch (e) {
        isRateLimited = true;
        retryAfter = e.retryAfterSeconds;
        debugPrint('[AdvisorService] Backend proxy rate limited ($e).');
      } catch (e) {
        _backendCircuitBroken = true;
        debugPrint('[AdvisorService] Backend proxy offline ($e). Tripped circuit breaker for session.');
      }
    }

    // -------------------------------------------------------------------------
    // STEP 3: ULTRA-LOW-LATENCY CLOUD AI ROUTING (<= 1.5s RESPONSE TIME)
    // -------------------------------------------------------------------------
    if (!isRateLimited) {
      final activeWeight = userProfile?.weightKg ?? 65.0;
      final isChild = userProfile?.isChild ?? false;
      final hasDiabetes = userProfile?.isDiabetic ?? false;
      final hasHypertension = userProfile?.isHypertensive ?? false;
      final productName = productContext?.productName ?? 'General Packaged Food';
      final additives = productContext?.additives ?? [];
      final nutrition = <String, dynamic>{
        if (productContext?.nutrition != null) ...productContext!.nutrition,
        if (productContext?.extendedNutrients != null) ...productContext!.extendedNutrients,
      };

      final systemPrompt = AdvisorRules.buildSystemPrompt(
        weightKg: activeWeight,
        isChild: isChild,
        isDiabetic: hasDiabetes,
        isHypertensive: hasHypertension,
        productName: productName,
        brandName: productContext?.brandName,
        category: productContext?.category,
        healthScore: productContext?.healthScore,
        novaGrade: productContext?.novaGrade,
        nutrition: nutrition,
        additives: additives,
        ingredients: productContext?.ingredients,
        healthIntelligence: productContext?.healthIntelligence,
      );

      // Primary Route: MultiProviderAiRouter (Groq LPU primary ~0.4s-0.8s with 2.2s parallel hedge to Gemini Flash)
      try {
        final router = _injectedAiRouter ?? _aiRouter;
        final reply = await router.askAdvisor(
          systemPrompt: systemPrompt,
          userMessage: userMessage,
        );

        if (reply != null && reply.trim().isNotEmpty) {
          final citations = _extractCitations(reply, additives);
          final isPortionQuestion = _isPortionRelevant(userMessage, productContext);
          final safePortion = isPortionQuestion
              ? _calculateSafePortion(
                  nutrition,
                  additives,
                  isChild,
                  hasDiabetes,
                  hasHypertension,
                  activeWeight,
                )
              : null;

          return ChatMessage.advisor(
            text: reply.trim(),
            source: 'cloud_ai_pool',
            citations: citations,
            safePortionGrams: safePortion?.grams,
            frequencySchedule: safePortion?.schedule,
          );
        }
      } catch (e) {
        debugPrint('[AdvisorService] MultiProviderAiRouter notice ($e). Trying direct Gemini fallback.');
      }

      // Secondary Route: Direct Gemini 2.5 Flash with thinkingBudget: 0 & smart search
      if (GeminiConfig.isConfigured) {
        try {
          final liveAiRes = await _askGeminiDirect(
            userMessage: userMessage,
            productContext: productContext,
            userProfile: userProfile,
          );
          return liveAiRes;
        } on RateLimitException catch (e) {
          isRateLimited = true;
          retryAfter = e.retryAfterSeconds;
          debugPrint('[AdvisorService] Gemini direct API rate limited ($e).');
        } catch (e) {
          debugPrint('[AdvisorService] Gemini direct API notice ($e): falling back to local factual engine.');
        }
      }
    }

    // -------------------------------------------------------------------------
    // TIER 4: OFFLINE FACTUAL REGULATORY ENGINE (AIRPLANE MODE / ERROR FALLBACK)
    // -------------------------------------------------------------------------
    final fallback = _buildOfflineFactualFallback(userMessage, productContext, userProfile);
    if (isRateLimited) {
      return ChatMessage.advisor(
        text: 'The AI service is currently experiencing high traffic (rate limit active, retry in ${retryAfter}s). Switching to our offline scientific database:\n\n${fallback.text}',
        source: 'local_clinical_engine',
        citations: fallback.citations,
        safePortionGrams: fallback.safePortionGrams,
        frequencySchedule: fallback.frequencySchedule,
      );
    }
    return fallback;
  }

  /// Direct query to Google Gemini REST endpoint with strict System Rules & Citation RAG assembly
  Future<ChatMessage> _askGeminiDirect({
    required String userMessage,
    ProductAdvisorContext? productContext,
    UserProfileModel? userProfile,
  }) async {
    final activeWeight = userProfile?.weightKg ?? 65.0;
    final isChild = userProfile?.isChild ?? false;
    final hasDiabetes = userProfile?.isDiabetic ?? false;
    final hasHypertension = userProfile?.isHypertensive ?? false;
    final productName = productContext?.productName ?? 'General Packaged Food';
    final additives = productContext?.additives ?? [];
    final nutrition = <String, dynamic>{
      if (productContext?.nutrition != null) ...productContext!.nutrition,
      if (productContext?.extendedNutrients != null) ...productContext!.extendedNutrients,
    };

    // Assemble Citation-Grounded RAG Prompt with Strict Domain & Identity Regulations
    final systemPrompt = AdvisorRules.buildSystemPrompt(
      weightKg: activeWeight,
      isChild: isChild,
      isDiabetic: hasDiabetes,
      isHypertensive: hasHypertension,
      productName: productName,
      brandName: productContext?.brandName,
      category: productContext?.category,
      healthScore: productContext?.healthScore,
      novaGrade: productContext?.novaGrade,
      nutrition: nutrition,
      additives: additives,
      ingredients: productContext?.ingredients,
      healthIntelligence: productContext?.healthIntelligence,
    );

    final fullPrompt = '$systemPrompt\n\n'
        'USER QUESTION: $userMessage\n\n'
        'MANDATORY INSTRUCTIONS:\n'
        '1. If the question is strictly unrelated to food products, nutrition, or using the VeriBite app, politely refuse as instructed.\n'
        '2. NEVER state what model you are or who created you. You are solely the VeriBite AI Advisor.\n'
        '3. Interpret user typos charitably (e.g., "colestrol" -> cholesterol, "carb/carbohydrate").\n'
        '4. If asking about a specific nutrient not explicitly listed in the label numbers, provide the scientifically deduced value (e.g. 0 mg cholesterol for botanical Unani formulations like Safi).\n'
        '5. Give ONLY the specific details requested. Keep your response brief, clear, and under 120 words in punchy bullet points.';

    final baseRequestBody = {
      'contents': [
        {
          'parts': [
            {'text': fullPrompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 380,
        'thinkingConfig': {'thinkingBudget': 0},
      }
    };

    final isUnindexedWebSearch = productContext == null && _isUnindexedWebSearchRequired(userMessage);
    final requestBody = isUnindexedWebSearch
        ? {
            ...baseRequestBody,
            'tools': [
              {'google_search': {}}
            ],
          }
        : baseRequestBody;

    final modelsToTry = [
      'gemini-2.5-flash-lite',
      'gemini-2.5-flash',
      ...GeminiConfig.fallbackModels,
    ];
    Exception? lastError;

    for (final model in modelsToTry) {
      try {
        final uri = Uri.parse('${GeminiConfig.baseUrl}/$model:generateContent?key=${GeminiConfig.apiKey}');
        
        final response = await _client
            .post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(requestBody),
            )
            .timeout(const Duration(milliseconds: 3200));

        if (response.statusCode == 200) {
          final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
          final candidates = json['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final parts = candidates[0]['content']?['parts'] as List<dynamic>?;
            if (parts != null && parts.isNotEmpty) {
              final replyText = parts[0]['text'] as String? ?? '';
              final citations = _extractCitations(replyText, additives);
              final isPortionQuestion = _isPortionRelevant(userMessage, productContext);
              final safePortion = isPortionQuestion
                  ? _calculateSafePortion(
                      nutrition,
                      additives,
                      isChild,
                      hasDiabetes,
                      hasHypertension,
                      activeWeight,
                    )
                  : null;

              return ChatMessage.advisor(
                text: replyText.trim(),
                source: 'gemini_flash',
                citations: citations,
                safePortionGrams: safePortion?.grams,
                frequencySchedule: safePortion?.schedule,
              );
            }
          }
        } else if (response.statusCode == 429) {
          final retryAfterHeader = response.headers['retry-after'];
          final retrySec = int.tryParse(retryAfterHeader ?? '') ?? 15;
          final activeUserId = userProfile?.userId ?? 'anonymous';
          rateLimiter.recordServer429(retrySec, null, activeUserId);
          lastError = RateLimitException(retrySec);
          break; // Stop immediately to protect remote quotas
        } else {
          lastError = Exception('Gemini model $model returned status ${response.statusCode}: ${response.body}');
        }
      } on RateLimitException {
        rethrow;
      } catch (e) {
        lastError = Exception('Gemini model $model request failed: $e');
      }
    }

    if (lastError != null) throw lastError;
    throw Exception('Gemini API call failed: no models responded');
  }

  /// Backend proxy implementation when running alongside local FastAPI server
  Future<ChatMessage?> _askBackendProxy({
    required String userMessage,
    ProductAdvisorContext? productContext,
    UserProfileModel? userProfile,
  }) async {
    final activeUserId = userProfile?.userId ?? 'anonymous';
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
        'user_id': activeUserId,
        'weight_kg': activeWeight,
        'is_child': isChild,
        'has_diabetes': hasDiabetes,
        'has_hypertension': hasHypertension,
      },
      'user_message': userMessage,
    };

    final uri = Uri.parse('$customBaseUrl/api/v1/advisor/chat');
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'X-User-Id': activeUserId,
            },
            body: jsonEncode(requestPayload),
          )
          .timeout(const Duration(milliseconds: 800));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return ChatMessage.fromJson(data);
      } else if (response.statusCode == 429) {
        final retryAfterHeader = response.headers['retry-after'];
        int retrySec = int.tryParse(retryAfterHeader ?? '') ?? 15;
        try {
          final bodyJson = jsonDecode(response.body) as Map<String, dynamic>;
          if (bodyJson['retry_after'] is num) {
            retrySec = (bodyJson['retry_after'] as num).toInt();
          }
        } catch (_) {}
        rateLimiter.recordServer429(retrySec, null, activeUserId);
        throw RateLimitException(retrySec);
      }
      return null;
    } catch (e) {
      _backendCircuitBroken = true;
      rethrow;
    }
  }

  /// Extracts official regulatory citations from the AI text response
  List<String> _extractCitations(String text, List<Map<String, dynamic>> additives) {
    final citations = <String>[];
    final upper = text.toUpperCase();

    if (upper.contains('WHO') || upper.contains('WORLD HEALTH')) {
      citations.add('WHO Free Sugars (2015)');
    }
    if (upper.contains('EFSA') || upper.contains('EUROPEAN FOOD')) {
      citations.add('EFSA Additive Opinion');
    }
    if (upper.contains('FSSAI') || upper.contains('FOOD SAFETY AND STANDARDS')) {
      citations.add('FSSAI Labelling (2020)');
    }
    if (upper.contains('JECFA') || upper.contains('FAO')) {
      citations.add('JECFA Monograph ADI');
    }
    if (upper.contains('SOUTHAMPTON')) {
      citations.add('EFSA Southampton Study');
    }
    if (upper.contains('ICMR') || upper.contains('NIN')) {
      citations.add('ICMR-NIN Guidelines');
    }

    // Only return citations that were actually cited in the AI response
    return citations;
  }

  /// Determines if prescribed safe portion grams and schedule are relevant to the user's question
  bool _isPortionRelevant(String query, ProductAdvisorContext? productContext) {
    final lower = query.toLowerCase();

    // App troubleshooting and identity queries never have prescribed food portions
    if (AdvisorRules.isAppHelpQuery(query) || AdvisorRules.isIdentityQuery(query)) {
      return false;
    }

    final explicitPortionKeywords = [
      'portion', 'how much', 'serving', 'dose', 'dosage', 'grams', 'how many',
      'safe to eat', 'can i eat', 'should i eat', 'limit', 'intake', 'quantity',
      'allowed', 'safe limit', 'how often', 'daily limit', 'how much sugar'
    ];

    if (explicitPortionKeywords.any((k) => lower.contains(k))) {
      return true;
    }

    // If a scanned product is loaded and user asks about safety, kids, or diabetes
    if (productContext != null) {
      final productSafetyKeywords = [
        'safe', 'good for', 'bad for', 'healthy', 'child', 'kid', 'diabet',
        'sugar', 'sodium', 'salt', 'fat', 'eat this', 'snack'
      ];
      return productSafetyKeywords.any((k) => lower.contains(k));
    }

    return false;
  }

  /// Safe portion calculation powered by the official VeriBite DosageEngine
  ({double grams, String schedule, String limitingFactor}) _calculateSafePortion(
    Map<String, dynamic> nutrition,
    List<Map<String, dynamic>> additives,
    bool isChild,
    bool isDiabetic,
    bool isHypertensive,
    double weightKg,
  ) {
    try {
      final res = calculatePrescribedDosage(
        nutrition: nutrition,
        additives: additives,
        userWeightKg: weightKg,
        isChild: isChild,
        isDiabetic: isDiabetic,
        isHypertensive: isHypertensive,
      );
      final grams = (res['safe_portion_grams'] as num?)?.toDouble() ?? 30.0;
      final schedule = res['frequency_schedule']?.toString() ??
          (isChild ? 'Max 1x per week' : 'Max 2-3x per week');
      final factor = res['limiting_factor']?.toString() ?? 'Sugar';
      return (grams: grams, schedule: schedule, limitingFactor: factor);
    } catch (_) {
      final dailySugarLimitGrams = isChild ? 25.0 : 50.0;
      final singleSnackSugarCeiling = (dailySugarLimitGrams * 0.20).clamp(5.0, 15.0);
      final sugars100g = (nutrition['sugars_100g'] as num?)?.toDouble() ?? 0.0;
      final portionGrams = sugars100g > 0
          ? ((singleSnackSugarCeiling / sugars100g) * 100.0).clamp(15.0, 80.0)
          : (weightKg * 0.6).clamp(20.0, 60.0);
      final rounded = (portionGrams * 10).round() / 10.0;
      final schedule = isChild ? 'Max 1x per week' : 'Max 2-3x per week';
      return (grams: rounded, schedule: schedule, limitingFactor: 'Sugar');
    }
  }

  /// Factual offline fallback engine that calculates weight-adjusted safe portions
  /// and answers ingredient queries using pre-verified WHO/EFSA/FSSAI scientific guidelines.
  ChatMessage _buildOfflineFactualFallback(
    String userQuery,
    ProductAdvisorContext? productContext,
    UserProfileModel? userProfile,
  ) {
    // 1. Guardrail: Out of Scope Refusal (Context-Aware)
    if (AdvisorRules.isOutOfScope(userQuery, productContext)) {
      return ChatMessage.advisor(
        text: AdvisorRules.outOfScopeRefusal,
        source: 'veribite_guardrail',
      );
    }

    // 2. Guardrail: Identity Protection
    if (AdvisorRules.isIdentityQuery(userQuery)) {
      return ChatMessage.advisor(
        text: AdvisorRules.identityResponse,
        source: 'veribite_guardrail',
      );
    }

    // 3. In-App Navigation & Troubleshooting Help
    if (AdvisorRules.isAppHelpQuery(userQuery)) {
      return ChatMessage.advisor(
        text: AdvisorRules.buildAppHelpResponse(userQuery),
        source: 'veribite_app_guide',
        citations: ['VeriBite User Guide', 'FSSAI Consumer Guidelines'],
      );
    }

    final queryLower = userQuery.toLowerCase();
    final weightKg = userProfile?.weightKg ?? 65.0;
    final isChild = userProfile?.isChild ?? false;
    final hasDiabetes = userProfile?.isDiabetic ?? false;

    final additives = productContext?.additives ?? [];
    final nutrition = <String, dynamic>{
      if (productContext?.nutrition != null) ...productContext!.nutrition,
      if (productContext?.extendedNutrients != null) ...productContext!.extendedNutrients,
    };
    final productName = productContext?.productName ?? 'this product';
    final isSafiOrTonic = productName.toLowerCase().contains('safi') ||
        (productContext?.category?.toLowerCase().contains('tonic') ?? false) ||
        (productContext?.category?.toLowerCase().contains('ayurved') ?? false) ||
        (productContext?.category?.toLowerCase().contains('unani') ?? false) ||
        (productContext?.category?.toLowerCase().contains('herbal') ?? false);

    final hasHypertension = userProfile?.isHypertensive ?? false;

    // Calculate WHO & JECFA safe single-snack allowance using DosageEngine
    final isPortionQuestion = _isPortionRelevant(userQuery, productContext);
    final portionData = isPortionQuestion
        ? _calculateSafePortion(
            nutrition,
            additives,
            isChild,
            hasDiabetes,
            hasHypertension,
            weightKg,
          )
        : null;
    final roundedPortion = portionData?.grams;
    final schedule = portionData?.schedule;
    final sugars100g = (nutrition['sugars_100g'] as num?)?.toDouble() ??
        (nutrition['sugar_g_per_100g'] as num?)?.toDouble() ?? 20.0;

    final citations = <String>[];
    final buffer = StringBuffer();

    // 1. Cholesterol Intent (including common typos: colestrol, colest, colesterolo)
    if (queryLower.contains('cholest') || queryLower.contains('colest')) {
      citations.add('WHO-Guidelines-Cardiovascular-Health');
      citations.add('ICMR-NIN-Dietary-2024');

      final cholVal = (nutrition['cholesterol_mg_per_100g'] as num?)?.toDouble() ??
          (nutrition['cholesterol'] as num?)?.toDouble() ?? 0.0;

      buffer.writeln('### Cholesterol Profile for $productName\n');
      if (isSafiOrTonic) {
        buffer.writeln(
          '**Cholesterol: 0 mg (Zero Cholesterol)**\n\n'
          '• **Formulation Insight:** **$productName** is a 100% botanical/plant-based Unani formulation composed of herbal extracts (Senna, Turbud, Neem, Tulsi, Chiraita, etc.) and an invert sugar syrup base.\n'
          '• **Cardiovascular Science:** Cholesterol is synthesized biochemically exclusively within animal cell membranes and does not occur in botanical plants. Therefore, this product contains **0 mg dietary cholesterol** and will not contribute to arterial plaque or LDL cholesterol accumulation.',
        );
      } else if (cholVal > 0) {
        buffer.writeln(
          '• **Cholesterol Content:** **${cholVal.toStringAsFixed(1)} mg** per 100g.\n'
          '• **Cardiovascular Guidance:** For healthy adults, daily dietary cholesterol should be kept under 300 mg (under 200 mg for individuals with hyperlipidemia).',
        );
      } else {
        buffer.writeln(
          '• **Cholesterol Content:** **0 mg (Cholesterol-Free)**.\n'
          '• **Guidance:** This product has negligible or zero dietary cholesterol.',
        );
      }
    }
    // 2. Carbohydrates Intent (carb, carbo, carbohydrates)
    else if (queryLower.contains('carb')) {
      citations.add('ICMR-NIN-Dietary-2024');
      citations.add('FSSAI-Labelling-Regs-2020');

      final carbsVal = (nutrition['carbohydrates_g_per_100g'] as num?)?.toDouble() ??
          (nutrition['carbohydrates'] as num?)?.toDouble() ??
          (nutrition['carbs_100g'] as num?)?.toDouble();

      buffer.writeln('### Carbohydrates Breakdown for $productName\n');
      if (isSafiOrTonic) {
        buffer.writeln(
          '• **Carbohydrate Content:** Approximately **7g–8g per 10ml adult serving** (~70g–80g per 100ml).\n'
          '• **Formulation Source:** The carbohydrates in **$productName** originate predominantly from its traditional **Invert Sugar Syrup (Qand Safaid)** base.\n'
          '• **Why Sugar Syrup is Used:** In traditional Unani medicine, the sugar syrup acts as a natural preservative and palatable vehicle to mask the intense bitterness of potent herbs like Neem and Chiraita.\n'
          '• **Diabetic Precaution:** Diabetics must account for this carbohydrate and sugar load in their daily glycemic management.',
        );
      } else if (carbsVal != null && carbsVal > 0) {
        buffer.writeln(
          '• **Total Carbohydrates:** **${carbsVal.toStringAsFixed(1)}g** per 100g.\n'
          '• **Breakdown:** Includes simple sugars (${sugars100g.toStringAsFixed(1)}g) and complex starches.\n'
          '• **Nutritional Context:** Carbs provide 4 kcal per gram and represent the primary energy substrate in this food.',
        );
      } else {
        buffer.writeln(
          '• **Total Carbohydrates:** Approximately **${sugars100g.toStringAsFixed(1)}g** per 100g (primarily simple sugars).\n'
          '• **Guidance:** Consume in controlled portions to prevent blood glucose spikes.',
        );
      }
    }
    // 3. Fat & Lipids Intent
    else if (queryLower.contains('fat') || queryLower.contains('lipid')) {
      citations.add('WHO-Guidelines-Healthy-Diet');
      final totalFat = (nutrition['total_fat_g_per_100g'] as num?)?.toDouble() ?? 0.0;
      final satFat = (nutrition['sat_fat_100g'] as num?)?.toDouble() ??
          (nutrition['sat_fat_g_per_100g'] as num?)?.toDouble() ?? 0.0;

      buffer.writeln('### Lipid & Fat Analysis for $productName\n');
      if (isSafiOrTonic) {
        buffer.writeln('• **Total Fat: 0 g | Saturated Fat: 0 g**\n• As an aqueous herbal syrup, it contains zero lipid density.');
      } else {
        buffer.writeln('• **Total Fat:** **${totalFat.toStringAsFixed(1)}g** per 100g.');
        buffer.writeln('• **Saturated Fat:** **${satFat.toStringAsFixed(1)}g** per 100g.');
        if (satFat > 5.0) {
          buffer.writeln('⚠️ **High Saturated Fat:** Limit portion to manage LDL cardiovascular risk.');
        }
      }
    }
    // 4. Protein Intent
    else if (queryLower.contains('prot')) {
      citations.add('ICMR-NIN-Dietary-2024');
      final protein = (nutrition['protein_g'] as num?)?.toDouble() ??
          (nutrition['protein_100g'] as num?)?.toDouble() ?? 0.0;

      buffer.writeln('### Protein Content for $productName\n');
      buffer.writeln('• **Protein:** **${protein.toStringAsFixed(1)}g** per 100g.');
      if (protein > 10.0) {
        buffer.writeln('• **High Protein Density:** Provides beneficial amino acid support.');
      } else if (isSafiOrTonic) {
        buffer.writeln('• **Note:** Herbal syrups provide negligible macronutrient protein.');
      }
    }
    // 5. Sodium & Salt Intent
    else if (queryLower.contains('sodiu') || queryLower.contains('salt')) {
      citations.add('WHO-Guidelines-Sodium-2023');
      final sodiumMg = (nutrition['sodium_mg_per_100g'] as num?)?.toDouble() ??
          (nutrition['sodium_100g'] as num?)?.toDouble() ?? 0.0;

      buffer.writeln('### Sodium & Salt Assessment for $productName\n');
      buffer.writeln('• **Sodium:** **${sodiumMg.toStringAsFixed(0)} mg** per 100g (Salt equivalent: **${(sodiumMg / 400.0).toStringAsFixed(2)}g**).');
      if (sodiumMg > 800) {
        buffer.writeln('⚠️ **High Sodium Warning:** Exceeds 40% of the daily WHO 2000mg ceiling per 100g.');
      } else {
        buffer.writeln('• **Evaluation:** Well within healthy cardiovascular thresholds.');
      }
    }
    // 6. Calories & Energy Intent
    else if (queryLower.contains('calor') || queryLower.contains('energ') || queryLower.contains('kcal')) {
      citations.add('ICMR-NIN-Dietary-2024');
      final kcal = (nutrition['calories'] as num?)?.toDouble() ??
          (nutrition['energy_kcal'] as num?)?.toDouble() ?? 0.0;

      buffer.writeln('### Caloric Value for $productName\n');
      if (kcal > 0) {
        buffer.writeln('• **Energy:** **${kcal.toStringAsFixed(0)} kcal** (${(kcal * 4.184).round()} kJ).');
      } else if (isSafiOrTonic) {
        buffer.writeln('• **Energy:** Approximately **30–35 kcal per 10ml serving** (primarily from invert sugar syrup).');
      } else {
        buffer.writeln('• **Energy:** Consult the complete nutrition table on your verdict screen.');
      }
    }
    // 7. Botanical Bioactives, Senna & Side Effects Intent
    else if (queryLower.contains('senna') || queryLower.contains('sana') || queryLower.contains('laxat') || queryLower.contains('side effect') || queryLower.contains('herb') || queryLower.contains('organ') || queryLower.contains('safe to drink') || queryLower.contains('safe to use') || queryLower.contains('acne') || queryLower.contains('purif')) {
      citations.add('WHO-Monographs-Medicinal-Plants');
      citations.add('Ayurvedic-Pharmacopoeia-India');

      buffer.writeln('### Botanical Bioactives & Safety Profile for $productName\n');
      if (isSafiOrTonic) {
        buffer.writeln(
          '• **Primary Active Herb:** **Senna (Cassia angustifolia / Sana)** contains anthraquinone glycosides (**Sennosides A & B**), which are pharmacologically active stimulant laxatives.\n'
          '• **Mechanism:** Stimulates bowel motility and inhibits water absorption in the colon.\n'
          '• **Duration Limitation:** Recommended strictly for short-term bowel clearance (up to 1–2 weeks). **Avoid continuous daily consumption beyond 14 days** without clinical oversight to prevent laxative dependency and potassium depletion.\n'
          '• **Contraindications:** Not advised during pregnancy, breastfeeding, or in young children without medical approval.',
        );
      } else {
        buffer.writeln('• Review active botanical compounds and synthetic additives on the product label.\n• Consult clinical monographs for maximum safe daily duration.');
      }
    }
    // 8. Diabetes & Sugar Intent
    else if (queryLower.contains('diabet') || queryLower.contains('sugar')) {
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
    }
    // 9. Pediatric / Child Safety Intent
    else if (queryLower.contains('kid') || queryLower.contains('child')) {
      citations.add('EFSA-Southampton-Study-2008');
      citations.add('FSSAI-Child-Safety-Regs');

      buffer.writeln('### Child Safety & Pediatric Toxicology\n');
      buffer.writeln(
        'For a child (~${weightKg.toStringAsFixed(0)} kg), metabolic clearance for artificial additives and free sugars is significantly lower than in adults.\n',
      );
      if (additives.isNotEmpty) {
        final redTier = additives.where((a) => a['risk_tier']?.toString().toUpperCase() == 'RED').toList();
        if (redTier.isNotEmpty) {
          final names = redTier.map((a) => a['name'] ?? a['ins_code']).join(', ');
          buffer.writeln('⚠️ **Flagged Additives:** Contains **$names**, which are restricted under EU/EFSA guidelines due to hyperactivity risks in young children.\n');
        }
      }
      buffer.writeln(
        '• **Safe Serving:** Strictly capped at **${roundedPortion}g**.\n'
        '• **Schedule:** $schedule.',
      );
    }
    // 10. Chemical Additives / INS Intent
    else if (queryLower.contains('ins') || queryLower.contains('additive')) {
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
    }
    // 11. General Nutrition & Food Safety Guidance
    else {
      citations.add('WHO-Healthy-Diet-FactSheet-394');
      citations.add('Codex-Alimentarius-General-Standard');

      buffer.writeln('### Nutrition & Food Safety Guidance for $productName\n');
      if (isPortionQuestion) {
        buffer.writeln(
          'Based on your calibrated body weight (${weightKg.toStringAsFixed(0)} kg):\n'
          '• **Prescribed Portion:** **${roundedPortion}g** per single snack sitting.\n'
          '• **Safe Schedule:** $schedule.\n'
          '• **Recommendation:** Check full ingredient labels for disguised split sweeteners and artificial stabilizers.',
        );
      } else {
        buffer.writeln(
          '• **Guidance:** Review full ingredient labels for disguised split sugars and artificial chemical additives.\n'
          '• **Safe Habit:** Prioritize whole, minimally processed foods, and limit ultra-processed snacks with Red-tier additives.',
        );
      }
    }

    return ChatMessage.advisor(
      text: buffer.toString().trim(),
      source: 'local_clinical_engine',
      citations: citations,
      safePortionGrams: roundedPortion,
      frequencySchedule: schedule,
    );
  }
}
