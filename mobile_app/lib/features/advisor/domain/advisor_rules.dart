import 'advisor_chat_model.dart';

/// Domain rules, system prompts, and out-of-scope guardrails for VeriBite AI Advisor.
class AdvisorRules {
  static const String appName = 'VeriBite';
  static const String advisorTitle = 'VeriBite AI Advisor';

  static const String outOfScopeRefusal =
      'I am the VeriBite Food Safety & App Advisor. I can only assist with questions '
      'about packaged food ingredients, nutrition, chemical additives (INS), safe portions, '
      'or using the VeriBite app. Please ask a question related to food products or this application!';

  static const String identityResponse =
      'I am the VeriBite AI Advisor, built into the VeriBite application to help you '
      'evaluate packaged food ingredients, chemical toxicology, safe consumption dosage, '
      'and in-app features. How can I help you evaluate your food or navigate the app today?';

  /// Complete system prompt injected into Gemini generation
  static String buildSystemPrompt({
    required double weightKg,
    required bool isChild,
    required bool isDiabetic,
    required bool isHypertensive,
    String? productName,
    String? brandName,
    String? category,
    int? healthScore,
    int? novaGrade,
    Map<String, dynamic>? nutrition,
    List<Map<String, dynamic>>? additives,
    List<String>? ingredients,
    Map<String, dynamic>? healthIntelligence,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('You are the VeriBite AI Advisor, an expert in packaged food toxicology, ingredient analysis, clinical nutrition, and VeriBite app guidance.');
    buffer.writeln('');
    buffer.writeln('STRICT BEHAVIORAL REGULATIONS & SAFETY BOUNDARIES:');
    buffer.writeln('1. IDENTITY RULE: You are ONLY the "VeriBite AI Advisor". NEVER disclose or mention your underlying AI model (e.g., Gemini, GPT, LLM), model version, or creator/developer (e.g., Google, OpenAI, DeepMind). If asked who created you or what model you are, state only that you are the VeriBite AI Advisor built for this app.');
    buffer.writeln('2. STRICT DOMAIN BOUNDARY: You answer questions related to packaged foods, ingredients, botanical extracts, chemical INS additives, nutrition facts, toxicology, safe portion limits, and VeriBite app features.');
    buffer.writeln('   For ANY question strictly unrelated to food, nutrition, biology, health, or the app (e.g., writing programming code/scripts, sports scores, movie reviews, cryptocurrency, or political elections), you MUST POLITELY REFUSE.');
    buffer.writeln('3. CHARITABLE TYPO INTERPRETATION: Always interpret user typos charitably without lecturing (e.g., "colestrol" -> cholesterol, "protien" -> protein, "carbs/carbohydrate", "sugr" -> sugar). Never refuse a query due to spelling or grammatical typos.');
    buffer.writeln('4. INTELLIGENT NUTRIENT INFERENCE (NO DEAD-END REPLIES):');
    buffer.writeln('   If the user asks for a specific nutrient (such as Cholesterol, Carbohydrates, Sugar, Fat, Protein, Sodium, or Calories) that is not explicitly printed in the label numbers:');
    buffer.writeln('   - DO NOT refuse, and DO NOT simply say "Data missing".');
    buffer.writeln('   - Instead, provide the exact scanned value if present, OR provide the scientifically deduced value based on the product formulation.');
    buffer.writeln('   - Example: For plant-based or Ayurvedic herbal tonics (like Hamdard Safi), confirm that as a 100% botanical Unani formulation, it contains 0 mg Cholesterol (cholesterol only exists in animal products). Its carbohydrates (~7g-8g per 10ml serving, ~70-80g per 100ml) stem from its Invert Sugar Syrup / Qand Safaid base.');
    buffer.writeln('5. CONCISE CLINICAL BULLETS: Give ONLY the details requested. Answer directly with 3-5 punchy, high-density bullet points followed by a 1-sentence safe portion verdict. Keep total response under 120 words. Avoid conversational fluff or boilerplate.');
    buffer.writeln('6. NO MEDICAL DIAGNOSIS: Never diagnose clinical illnesses or prescribe pharmaceuticals. Base evaluations on published regulatory monographs (WHO, EFSA, FSSAI, JECFA, ICMR).');
    buffer.writeln('');
    buffer.writeln('USER HEALTH PROFILE & BIOMETRIC GUARDRAILS:');
    buffer.writeln('- Calibrated Body Weight: ${weightKg.toStringAsFixed(1)} kg');
    buffer.writeln('- Life Stage: ${isChild ? "Child (<12 years old)" : "Adult"}');
    buffer.writeln('- Diabetic Guardrail: ${isDiabetic ? "ACTIVE (Elevated Glycemic Sensitivity)" : "Inactive"}');
    buffer.writeln('- Hypertension Guardrail: ${isHypertensive ? "ACTIVE (Strict Sodium Ceiling)" : "Inactive"}');

    if (productName != null && productName.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('ACTIVE SCANNED PRODUCT CONTEXT:');
      buffer.writeln('- Product Name: $productName');
      if (brandName != null && brandName.isNotEmpty) buffer.writeln('- Brand: $brandName');
      if (category != null && category.isNotEmpty) buffer.writeln('- Category: $category');
      if (healthScore != null) buffer.writeln('- Health Score: $healthScore/100');
      if (novaGrade != null) buffer.writeln('- NOVA Group: $novaGrade');

      if (nutrition != null && nutrition.isNotEmpty) {
        buffer.writeln('- Nutritional Profile (per 100g / per serving):');
        buffer.writeln('  * Calories / Energy: ${nutrition["calories"] ?? nutrition["energy_kcal"] ?? "N/A"} kcal');
        buffer.writeln('  * Total Carbohydrates: ${nutrition["carbohydrates_g_per_100g"] ?? nutrition["carbohydrates"] ?? nutrition["carbs_100g"] ?? "N/A"} g');
        buffer.writeln('  * Total Sugars: ${nutrition["sugars_100g"] ?? nutrition["sugar_g_per_100g"] ?? "N/A"} g');
        buffer.writeln('  * Added Sugars: ${nutrition["added_sugars_g"] ?? nutrition["added_sugar_g_per_100g"] ?? "N/A"} g');
        buffer.writeln('  * Total Fat: ${nutrition["total_fat_g_per_100g"] ?? nutrition["total_fat"] ?? "N/A"} g');
        buffer.writeln('  * Saturated Fat: ${nutrition["sat_fat_100g"] ?? nutrition["sat_fat_g_per_100g"] ?? "N/A"} g');
        buffer.writeln('  * Trans Fat: ${nutrition["trans_fat_g_per_100g"] ?? "0"} g');
        buffer.writeln('  * Cholesterol: ${nutrition["cholesterol_mg_per_100g"] ?? nutrition["cholesterol"] ?? "0"} mg');
        buffer.writeln('  * Protein: ${nutrition["protein_g"] ?? nutrition["protein_100g"] ?? "N/A"} g');
        buffer.writeln('  * Sodium: ${nutrition["sodium_100g"] ?? nutrition["sodium_mg_per_100g"] ?? "N/A"} mg');
        buffer.writeln('  * Dietary Fibre: ${nutrition["fiber_g"] ?? "N/A"} g');
      }

      if (ingredients != null && ingredients.isNotEmpty) {
        buffer.writeln('- Ingredients: ${ingredients.join(", ")}');
      }

      if (additives != null && additives.isNotEmpty) {
        buffer.writeln('- Detected Additives:');
        for (final a in additives) {
          final ins = a['ins_code'] ?? '';
          final name = a['name'] ?? a['primary_name'] ?? '';
          final tier = a['risk_tier'] ?? 'Caution';
          buffer.writeln('  * INS $ins ($name) — Risk Tier: $tier');
        }
      }

      if (healthIntelligence != null && healthIntelligence.isNotEmpty) {
        buffer.writeln('- Botanical & Bioactive Intelligence:');
        if (healthIntelligence['category_domain'] != null) {
          buffer.writeln('  * Category Domain: ${healthIntelligence['category_domain']}');
        }
        final bioactives = healthIntelligence['bioactive_compounds'] as List<dynamic>?;
        if (bioactives != null && bioactives.isNotEmpty) {
          buffer.writeln('  * Bioactive Compounds:');
          for (final b in bioactives) {
            if (b is Map) {
              buffer.writeln('    - ${b['name']} (${b['function_category'] ?? "Active"}): ${b['physiological_effect'] ?? ""} [Risk: ${b['risk_level'] ?? "moderate"}]');
            }
          }
        }
        final organImpact = healthIntelligence['organ_impact'] as Map<String, dynamic>?;
        if (organImpact != null) {
          buffer.writeln('  * Organ Impact:');
          organImpact.forEach((k, v) => buffer.writeln('    - $k: $v'));
        }
        final warnings = healthIntelligence['contraindications'] as Map<String, dynamic>?;
        if (warnings != null) {
          buffer.writeln('  * Contraindications:');
          warnings.forEach((k, v) => buffer.writeln('    - $k: $v'));
        }
      }
    }

    return buffer.toString();
  }

  /// Checks if query is attempting to interrogate AI model or creator details
  static bool isIdentityQuery(String query) {
    final lower = query.toLowerCase().trim();
    return lower.contains('which model') ||
        lower.contains('what model') ||
        lower.contains('who created you') ||
        lower.contains('who made you') ||
        lower.contains('who developed you') ||
        lower.contains('are you gemini') ||
        lower.contains('are you chatgpt') ||
        lower.contains('are you an llm') ||
        lower.contains('what ai are you') ||
        lower.contains('who is your creator');
  }

  /// Strict off-topic denylist patterns (coding, politics, sports, entertainment, finance, homework)
  static final List<RegExp> _strictDenylistPatterns = [
    RegExp(r'\b(write|create|generate|debug)\s+(python|java|javascript|c\+\+|code|script|sql|html|css|program|function|class)\b', caseSensitive: false),
    RegExp(r'\b(bubble sort|binary search|leetcode|github repository|pull request|unit test in python)\b', caseSensitive: false),
    RegExp(r'\b(pm of|prime minister|president of|chief minister|governor|election|parliament|bjp|congress|democrat|republican)\b', caseSensitive: false),
    RegExp(r'\b(who is the (pm|president|minister|king|queen|ceo of))\b', caseSensitive: false),
    RegExp(r'\b(cricket|football|fifa|ipl|match score|world cup|olympics|messi|ronaldo|virat kohli)\b', caseSensitive: false),
    RegExp(r'\b(capital of|currency of|population of|weather in|temperature in)\b', caseSensitive: false),
    RegExp(r'\b(movie review|actor|actress|cinema|bollywood|hollywood|song lyrics|box office)\b', caseSensitive: false),
    RegExp(r'\b(tell me a joke|write a poem|tell a story|sing a song)\b', caseSensitive: false),
    RegExp(r'\b(stock price|bitcoin|crypto|share market|nifty|sensex|ethereum|dogecoin)\b', caseSensitive: false),
    RegExp(r'\b(car|bike|automobile|flight ticket|train ticket)\b', caseSensitive: false),
    RegExp(r'\b(solve (equation|math|physics|calculus|algebra)|homework)\b', caseSensitive: false),
  ];

  /// Comprehensive nutrition, medical, botanical, and app stem allowlist (with phonetic typos)
  static const List<String> _domainStems = [
    // Macronutrients & Lipids (with typos)
    'carb', 'carbo', 'sugar', 'gluco', 'fructo', 'sucro', 'calor', 'kcal', 'energ',
    'prot', 'fat', 'lipid', 'saturat', 'unsaturat', 'trans', 'cholest', 'colest',
    'colesterol', 'colestrol', 'fiber', 'fibr', 'starch',
    // Micronutrients & Minerals
    'sodiu', 'salt', 'potassi', 'calciu', 'iron', 'magnesi', 'zinc', 'vitam',
    'mineral', 'electrolyt', 'antioxid', 'omega',
    // Additives, Herbs & Bioactives
    'additiv', 'ins', 'e-number', 'preserv', 'color', 'colour', 'flavour', 'flavor',
    'emulsif', 'sweeten', 'caffein', 'taurin', 'herbal', 'ayurved', 'unani', 'botanic',
    'senna', 'sana', 'neem', 'tulsi', 'chiraita', 'aloe', 'laxat', 'purif', 'detox',
    'tonic', 'supplement', 'whey', 'maltodextrin', 'palm oil', 'atta', 'maida', 'gluten',
    // Health, Organs, Conditions & Dosage
    'health', 'safe', 'toxic', 'harm', 'risk', 'side effect', 'benefit', 'dosag', 'dose',
    'portion', 'serv', 'daily', 'limit', 'rda', 'who', 'fssai', 'nova', 'score', 'grade',
    'diabet', 'glycem', 'insul', 'bp', 'pressure', 'heart', 'cardio', 'liver', 'kidney',
    'renal', 'gut', 'stomach', 'digest', 'constipat', 'diarrh', 'cramps', 'acne', 'skin',
    'pimple', 'weight', 'pregnan', 'breastfeed', 'child', 'kid', 'teen', 'adult',
    'allerg', 'gluten', 'lactos', 'vegan', 'veg', 'eat', 'food', 'snack', 'biscuit',
    'noodle', 'maggi', 'chip', 'drink', 'beverage', 'syrup', 'packet', 'bottle',
    // App & Scanner Usage
    'veribite', 'app', 'scan', 'barcode', 'qr', 'camera', 'ocr', 'label', 'offline',
    'report', 'pdf', 'history', 'profile', 'swap', 'blinkit', 'zepto', 'instamart',
    'guardrail', 'settings', 'how to', 'help', 'issue', 'not working', 'focus', 'zoom', 'reticle'
  ];

  /// Context-aware intent router:
  /// RULE 1: If active product is pinned, auto-pass queries related to product/context/inquiry.
  /// RULE 2: If query matches any domain stem (nutrition, botanical, organs, app), auto-pass.
  /// RULE 3: Strict off-topic denylist blocks completely unrelated topics (coding, politics, crypto).
  static bool isOutOfScope(String query, [ProductAdvisorContext? productContext]) {
    final lower = query.toLowerCase().trim();

    // 1. Strict Off-Topic Denylist Check: If message explicitly asks for coding/politics/sports/crypto
    final matchesDenylist = _strictDenylistPatterns.any((pattern) => pattern.hasMatch(lower));

    // 2. Greetings and brief queries
    if (lower == 'hi' || lower == 'hello' || lower == 'hey' || lower == 'help' || lower == 'thanks' || lower == 'thank you') {
      return false;
    }

    // 3. RULE 1 — ACTIVE PRODUCT CONTEXT AUTO-PASS
    if (productContext != null) {
      // Check product name, brand, category, and ingredients
      final productWords = <String>{};
      for (final part in productContext.productName.toLowerCase().split(RegExp(r'\s+'))) {
        if (part.length >= 3) productWords.add(part);
      }
      if (productContext.brandName != null) {
        for (final part in productContext.brandName!.toLowerCase().split(RegExp(r'\s+'))) {
          if (part.length >= 3) productWords.add(part);
        }
      }
      for (final ing in productContext.ingredients) {
        for (final part in ing.toLowerCase().split(RegExp(r'\s+'))) {
          if (part.length >= 3) productWords.add(part);
        }
      }

      final mentionsProductTokens = productWords.any((pw) => lower.contains(pw));
      if (mentionsProductTokens && !matchesDenylist) {
        return false;
      }

      // Contextual references
      final contextualRefs = ['this', 'it', 'this product', 'the product', 'syrup', 'packet', 'bottle', 'drink', 'food', 'item', 'brand'];
      final hasContextRef = contextualRefs.any((ref) => lower.contains(ref));

      // Inquiry & Question markers
      final questionMarkers = [
        'what', 'how', 'why', 'is', 'can', 'does', 'should', 'tell', 'explain',
        'level', 'amount', 'value', 'content', 'much', 'many', 'good', 'bad', 'safe', 'risk'
      ];
      final hasQuestionMarker = questionMarkers.any((q) => lower.contains(q));

      if ((hasContextRef || hasQuestionMarker) && !matchesDenylist) {
        return false;
      }
    }

    // 4. RULE 2 — COMPREHENSIVE NUTRITION & MEDICAL STEM ALLOWLIST
    final hasDomainStem = _domainStems.any((stem) => lower.contains(stem));
    if (hasDomainStem && !matchesDenylist) {
      return false;
    }

    // 5. RULE 3 — STRICT OFF-TOPIC REFUSAL
    if (matchesDenylist) {
      return true;
    }

    // If query is >= 3 words and has zero overlap with product context, nutrition stems, or app usage
    final words = lower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 3 && !hasDomainStem) {
      return true;
    }

    return false;
  }

  /// Checks if query is an in-app help or troubleshooting request
  static bool isAppHelpQuery(String query) {
    final lower = query.toLowerCase().trim();
    return lower.contains('how to scan') ||
        lower.contains('how do i scan') ||
        lower.contains('camera not') ||
        lower.contains('camera issue') ||
        lower.contains('torch') ||
        lower.contains('flashlight') ||
        lower.contains('change weight') ||
        lower.contains('update weight') ||
        lower.contains('change profile') ||
        lower.contains('diabetic guardrail') ||
        lower.contains('child mode') ||
        lower.contains('how to use this app') ||
        lower.contains('how veribite works') ||
        lower.contains('health score') ||
        lower.contains('red cap') ||
        lower.contains('swaps') ||
        lower.contains('blinkit');
  }

  /// Generates step-by-step guidance for in-app feature usage
  static String buildAppHelpResponse(String query) {
    final lower = query.toLowerCase().trim();

    if (lower.contains('scan') || lower.contains('camera') || lower.contains('torch')) {
      return '### How to Scan with VeriBite:\n\n'
          '1. **Open Scanner:** Tap the central **Scan** tab in the bottom bar.\n'
          '2. **Frame Barcode:** Align the product barcode inside the 320px central reticle.\n'
          '3. **Low Light:** Tap the **Flashlight (⚡)** icon to toggle the torch.\n'
          '4. **Curved Bottles:** Tap the **Curved (4-Angle)** chip for cylindrical bottles.\n'
          '5. **Manual Entry:** Tap **Manual Entry** to adjust sliders if the label is damaged.';
    }

    if (lower.contains('weight') || lower.contains('profile') || lower.contains('diabet') || lower.contains('child')) {
      return '### How to Adjust Biometrics & Guardrails:\n\n'
          '1. **Go to Profile:** Tap the **Profile** icon in the top-right of Home or navigation bar.\n'
          '2. **Edit Biometrics:** Tap the **Edit** button on the Biometrics card.\n'
          '3. **Weight Slider:** Slide between 15 kg and 120 kg or tap a 1-tap preset (45, 60, 65, 75, 85 kg).\n'
          '4. **Life Stage:** Toggle between **Adult** and **Child (<12 yrs)** for hyperactivity protection.\n'
          '5. **Health Guardrails:** Toggle **Type-2 Diabetes** or **Hypertension** ceilings, then tap **Save Changes**.';
    }

    if (lower.contains('swap') || lower.contains('blinkit') || lower.contains('zepto')) {
      return '### How to Find Healthier Clean Swaps:\n\n'
          '1. **From Scanned Verdict:** Tap the green **"Smart Healthier Clean Swaps"** banner on any product report.\n'
          '2. **From Home Hub:** Tap the **Blinkit Swaps** quick action tile.\n'
          '3. **Compare:** Tap any alternative card to view side-by-side calories, sugars, and additives.\n'
          '4. **Order:** Tap any 1-tap delivery pill (**Blinkit**, **Zepto**, **Instamart**, or **BigBasket**) to search instantly.';
    }

    if (lower.contains('score') || lower.contains('red cap')) {
      return '### Understanding VeriBite Health Scores:\n\n'
          '• **0 to 100 Scale:** Higher is cleaner and healthier (80+ Green = Excellent, 50-79 Amber = Moderate).\n'
          '• **39/100 Hard Red Cap:** Any product containing toxic Red-tier chemical additives (e.g. INS 635, azo dyes) is strictly capped at a maximum score of 39/100.\n'
          '• **Safe Dosage:** VeriBite calculates exact grams and pieces tailored to your calibrated body weight.';
    }

    return '### VeriBite App Quick Guide:\n\n'
        '• **Scan Products:** Tap the center **Scan** button to scan any packaged barcode.\n'
        '• **Search Catalog:** Tap the **Search** tab to explore 500+ verified foods and INS chemical codes.\n'
        '• **Health Advisor:** Ask me about food safety, sugar ceilings, or additive risks.\n'
        '• **Adjust Limits:** Visit **Profile** to update your body weight and health guardrails.';
  }
}

