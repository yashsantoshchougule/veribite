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
    int? healthScore,
    Map<String, dynamic>? nutrition,
    List<Map<String, dynamic>>? additives,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('You are the VeriBite AI Advisor, an expert in packaged food toxicology, ingredient analysis, and VeriBite app guidance.');
    buffer.writeln('');
    buffer.writeln('STRICT BEHAVIORAL REGULATIONS & SAFETY BOUNDARIES:');
    buffer.writeln('1. IDENTITY RULE: You are ONLY the "VeriBite AI Advisor". NEVER disclose or mention your underlying AI model (e.g., Gemini, GPT, LLM), model version, or creator/developer (e.g., Google, OpenAI, DeepMind). If asked who created you or what model you are, state only that you are the VeriBite AI Advisor built for this app.');
    buffer.writeln('2. STRICT DOMAIN BOUNDARY: You ONLY answer questions related to:');
    buffer.writeln('   a) Packaged foods, ingredients, chemical INS additives, nutrition facts, toxicology, and safe portion limits.');
    buffer.writeln('   b) VeriBite application usage, troubleshooting, scanning, and features.');
    buffer.writeln('   For ANY question unrelated to food, nutrition, or the VeriBite app (such as politics, world trivia, e.g. "Who is the PM of India?", sports, movies, general coding, weather, or jokes), you MUST POLITELY REFUSE and ask the user to submit a food- or app-related question.');
    buffer.writeln('3. CONCISENESS & BREVITY: Give ONLY the details requested. Do NOT give long lectures, unsolicited essays, or unasked-for life advice. Keep your response direct, practical, and focused strictly on the user query (under 150 words unless a detailed breakdown is explicitly requested).');
    buffer.writeln('4. IN-APP TROUBLESHOOTING: If the user asks how to use VeriBite, how to scan, how to adjust weight, or resolve camera/scan issues, provide clear, step-by-step in-app guidance.');
    buffer.writeln('5. NO MEDICAL DIAGNOSIS: Never diagnose illnesses or prescribe pharmaceuticals. Base food safety on official regulatory standards (WHO, EFSA, FSSAI, JECFA).');
    buffer.writeln('6. UNBIASED TOXICOLOGY: Base food evaluations on published ingredient labels and regulatory monographs. Prohibit emotional or unsubstantiated brand attacks.');
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
      if (healthScore != null) buffer.writeln('- Health Score: $healthScore/100');
      if (nutrition != null) {
        buffer.writeln('- Sugars (per 100g): ${nutrition["sugars_100g"] ?? "N/A"}');
        buffer.writeln('- Sodium (per 100g): ${nutrition["sodium_100g"] ?? "N/A"}');
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

  /// Checks if query is clearly out of food safety / app scope
  static bool isOutOfScope(String query) {
    final lower = query.toLowerCase().trim();

    // Explicit non-food/app trigger patterns
    final outOfScopePatterns = [
      RegExp(r'\b(pm|prime minister|president|chief minister|governor|minister)\b'),
      RegExp(r'\b(who is the (pm|president|minister|king|queen|ceo of))\b'),
      RegExp(r'\b(capital of|currency of|population of|weather in|temperature in)\b'),
      RegExp(r'\b(cricket|football|fifa|ipl|match score|world cup|olympics)\b'),
      RegExp(r'\b(movie|actor|actress|cinema|bollywood|hollywood|song|lyrics)\b'),
      RegExp(r'\b(write (python|java|javascript|c\+\+|code|a poem|a story|a joke))\b'),
      RegExp(r'\b(tell me a joke|write a poem|tell a story|sing a song)\b'),
      RegExp(r'\b(stock price|bitcoin|crypto|share market|nifty|sensex)\b'),
      RegExp(r'\b(car|bike|automobile|flight|train ticket)\b'),
    ];

    for (final pattern in outOfScopePatterns) {
      if (pattern.hasMatch(lower)) return true;
    }

    // Positive domain keywords (if query has at least one of these, it is in-scope)
    final domainKeywords = [
      'food', 'eat', 'safe', 'sugar', 'salt', 'sodium', 'fat', 'calorie', 'nutrition',
      'diet', 'child', 'kid', 'diabet', 'hypertens', 'weight', 'health', 'portion',
      'serving', 'ins', 'additive', 'e-number', 'preservative', 'color', 'sweetener',
      'maltodextrin', 'palm oil', 'protein', 'fiber', 'atta', 'maida', 'gluten',
      'allergy', 'biscuit', 'noodle', 'maggi', 'chip', 'snack', 'drink', 'beverage',
      'veribite', 'app', 'scan', 'camera', 'barcode', 'history', 'score', 'red flag',
      'swap', 'blinkit', 'zepto', 'instamart', 'profile', 'guardrail', 'settings',
      'how to', 'help', 'issue', 'not working', 'focus', 'zoom', 'reticle'
    ];

    final hasDomainKeyword = domainKeywords.any((keyword) => lower.contains(keyword));
    if (hasDomainKeyword) return false;

    // Short greetings or app questions are in-scope
    if (lower == 'hi' || lower == 'hello' || lower == 'hey' || lower == 'help') {
      return false;
    }

    // If query is sufficiently long (> 3 words) and has zero food/app/health concepts, treat as out of scope
    final words = lower.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.length >= 3 && !hasDomainKeyword) {
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
