import '../../camera/application/product_scanner_service.dart';
import '../../profile/domain/user_profile_model.dart';

/// Clinical toxicology & multilingual voice script builder for audible verdict readouts.
/// Generates native-script audible clinical summaries across 5 regional languages:
/// - Hindi (Devanagari)
/// - Marathi (Devanagari)
/// - Tamil (Tamil script)
/// - Telugu (Telugu script)
/// - English
class RegionalVoiceScriptBuilder {
  RegionalVoiceScriptBuilder._();

  /// Builds a complete audible clinical toxicology and safe dosage readout script
  /// tailored to the user's selected [language] and personalized biometrics.
  static String build({
    required ScannedProductResult product,
    required UserProfileModel userProfile,
    RegionalVoiceLanguage? language,
  }) {
    final lang = language ?? RegionalVoiceLanguage.fromString(userProfile.language);

    switch (lang) {
      case RegionalVoiceLanguage.hindi:
        return _buildHindiScript(product, userProfile);
      case RegionalVoiceLanguage.marathi:
        return _buildMarathiScript(product, userProfile);
      case RegionalVoiceLanguage.tamil:
        return _buildTamilScript(product, userProfile);
      case RegionalVoiceLanguage.telugu:
        return _buildTeluguScript(product, userProfile);
      case RegionalVoiceLanguage.english:
        return _buildEnglishScript(product, userProfile);
    }
  }

  /// Extracts red-tier toxic additives detected in the product
  static List<String> _extractRedAdditives(ScannedProductResult product) {
    return product.additives
        .where((a) {
          final tier = a['risk_tier']?.toString().toUpperCase();
          final redCap = a['triggers_red_cap'];
          return tier == 'RED' || redCap == 1 || redCap == true;
        })
        .map((a) => (a['primary_name'] ?? 'INS ${a["ins_code"]}').toString())
        .toList();
  }

  /// 1. HINDI (हिंदी - Devanagari)
  static String _buildHindiScript(
    ScannedProductResult product,
    UserProfileModel userProfile,
  ) {
    final b = StringBuffer();
    final name = product.productName;
    final score = product.healthScore;
    final nova = product.novaGrade;
    final weight = userProfile.weightKg.round();
    final safeGrams = product.safePortionGrams;
    final redAdditives = _extractRedAdditives(product);

    // Product Header
    b.write('$name का वेरीबाइट स्वास्थ्य विश्लेषण। ');

    // Health Score & Verdict
    if (score != null) {
      if (score >= 70 && !product.redCapTriggered) {
        b.write('इसका स्वास्थ्य स्कोर 100 में से $score है। यह उत्पाद पौष्टिक और सुरक्षित (NOVA $nova) श्रेणी में आता है। ');
      } else if (score >= 40 && !product.redCapTriggered) {
        b.write('इसका स्वास्थ्य स्कोर 100 में से $score है। यह उत्पाद मध्यम सावधानी (NOVA $nova) श्रेणी में आता है। ');
      } else {
        b.write('इसका स्वास्थ्य स्कोर 100 में से $score है। यह उत्पाद स्वास्थ्य के लिए जोखिमपूर्ण / अल्ट्रा-प्रोसेस्ड (NOVA $nova) श्रेणी में आता है। ');
      }
    } else {
      b.write('पर्याप्त जानकारी उपलब्ध न होने के कारण स्वास्थ्य स्कोर निर्धारित नहीं हो सका। ');
    }

    // Red-Cap & Toxic Additive Override Warning
    if (product.redCapTriggered) {
      b.write('चेतावनी: इसमें लाल-श्रेणी के हानिकारक केमिकल एडिटिव्स पाए गए हैं');
      if (redAdditives.isNotEmpty) {
        b.write(' (${redAdditives.take(3).join(", ")})');
      }
      b.write('। इसका स्वास्थ्य स्कोर 39 या उससे कम तक सीमित किया गया है। ');
    }

    // Nutrient & Additive Breakdown
    final sugar = product.sugarGPer100g.toStringAsFixed(1);
    final sodium = product.sodiumMgPer100g.round();
    final satFat = product.satFatGPer100g.toStringAsFixed(1);
    b.write('प्रति 100 ग्राम में $sugar ग्राम चीनी, $sodium मिलीग्राम सोडियम, और $satFat ग्राम सैचुरेटेड फैट है। ');

    if (redAdditives.isNotEmpty) {
      b.write('इसमें ${redAdditives.length} हानिकारक केमिकल एडिटिव्स पाए गए हैं। ');
    } else if (product.additives.isNotEmpty) {
      b.write('इसमें ${product.additives.length} खाद्य एडिटिव्स शामिल हैं। ');
    }

    // Sugar Splitting Warning
    if (product.splitSugars.isNotEmpty) {
      b.write('सावधान: इसमें ${product.splitSugars.length} गुप्त मीठे तत्व (हिडन शुगर्स) पाए गए हैं। ');
    }

    // Personalized Safe Dosage Recommendation
    b.write('आपके $weight किलोग्राम वजन के अनुसार, एक बार में अधिकतम सुरक्षित मात्रा $safeGrams ग्राम है');
    if (product.safePieces != null && product.safePieces! > 0) {
      b.write(' (लगभग ${product.safePieces} पीस)');
    }
    b.write('। सुरक्षित आवृत्ति: ${product.frequencySchedule}। सीमित कारक: ${product.limitingFactor}।');

    return b.toString();
  }

  /// 2. MARATHI (मराठी - Devanagari)
  static String _buildMarathiScript(
    ScannedProductResult product,
    UserProfileModel userProfile,
  ) {
    final b = StringBuffer();
    final name = product.productName;
    final score = product.healthScore;
    final nova = product.novaGrade;
    final weight = userProfile.weightKg.round();
    final safeGrams = product.safePortionGrams;
    final redAdditives = _extractRedAdditives(product);

    // Product Header
    b.write('$name चे वेरीबाइट आरोग्य विश्लेषण. ');

    // Health Score & Verdict
    if (score != null) {
      if (score >= 70 && !product.redCapTriggered) {
        b.write('याचे आरोग्य गुण १०० पैकी $score आहेत. हे उत्पादन पौष्टिक आणि सुरक्षित (NOVA $nova) वर्गात मोडते. ');
      } else if (score >= 40 && !product.redCapTriggered) {
        b.write('याचे आरोग्य गुण १०० पैकी $score आहेत. हे उत्पादन मध्यम काळजीपूर्वक (NOVA $nova) वर्गात मोडते. ');
      } else {
        b.write('याचे आरोग्य गुण १०० पैकी $score आहेत. हे उत्पादन आरोग्यासाठी हानिकारक आणि अल्ट्रा-प्रोसेस्ड (NOVA $nova) वर्गात मोडते. ');
      }
    } else {
      b.write('अपुऱ्या माहितीमुळे आरोग्य गुण निश्चित करता आले नाहीत. ');
    }

    // Red-Cap & Toxic Additive Override Warning
    if (product.redCapTriggered) {
      b.write('धोक्याचा इशारा: यात लाल-श्रेणीतील घातक केमिकल घटक आढळले आहेत');
      if (redAdditives.isNotEmpty) {
        b.write(' (${redAdditives.take(3).join(", ")})');
      }
      b.write('. याचे आरोग्य गुण ३९ किंवा त्यापेक्षा कमी मर्यादित केले आहेत. ');
    }

    // Nutrient & Additive Breakdown
    final sugar = product.sugarGPer100g.toStringAsFixed(1);
    final sodium = product.sodiumMgPer100g.round();
    final satFat = product.satFatGPer100g.toStringAsFixed(1);
    b.write('प्रति १०० ग्रॅममध्ये $sugar ग्रॅम साखर, $sodium मिग्रॅ सोडियम, आणि $satFat ग्रॅम सॅच्युरेटेड फॅट आहे. ');

    if (redAdditives.isNotEmpty) {
      b.write('यात ${redAdditives.length} घातक केमिकल एडिटिव्स आढळले आहेत. ');
    } else if (product.additives.isNotEmpty) {
      b.write('यात ${product.additives.length} अन्न घटक समाविष्ट आहेत. ');
    }

    // Sugar Splitting Warning
    if (product.splitSugars.isNotEmpty) {
      b.write('सावध राहा: यात ${product.splitSugars.length} छुपे साखरेचे प्रकार आढळले आहेत. ');
    }

    // Personalized Safe Dosage Recommendation
    b.write('तुमच्या $weight किलोग्रॅम वजनानुसार सुरक्षित प्रमाण $safeGrams ग्रॅम आहे');
    if (product.safePieces != null && product.safePieces! > 0) {
      b.write(' (सुमारे ${product.safePieces} तुकडे)');
    }
    b.write('. शिफारस केलेली वारंवारता: ${product.frequencySchedule}. मर्यादित घटक: ${product.limitingFactor}.');

    return b.toString();
  }

  /// 3. TAMIL (தமிழ் - Tamil Script)
  static String _buildTamilScript(
    ScannedProductResult product,
    UserProfileModel userProfile,
  ) {
    final b = StringBuffer();
    final name = product.productName;
    final score = product.healthScore;
    final nova = product.novaGrade;
    final weight = userProfile.weightKg.round();
    final safeGrams = product.safePortionGrams;
    final redAdditives = _extractRedAdditives(product);

    // Product Header
    b.write('$name க்கான வெரிபைட் ஆரோக்கிய ஆய்வு. ');

    // Health Score & Verdict
    if (score != null) {
      if (score >= 70 && !product.redCapTriggered) {
        b.write('இதன் ஆரோக்கிய மதிப்பெண் 100 க்கு $score ஆகும். இது சத்தான மற்றும் பாதுகாப்பான (NOVA $nova) பிரிவில் உள்ளது. ');
      } else if (score >= 40 && !product.redCapTriggered) {
        b.write('இதன் ஆரோக்கிய மதிப்பெண் 100 க்கு $score ஆகும். இது மிதமான எச்சரிக்கை (NOVA $nova) பிரிவில் உள்ளது. ');
      } else {
        b.write('இதன் ஆரோக்கிய மதிப்பெண் 100 க்கு $score ஆகும். இது ஆரோக்கியத்திற்கு ஆபத்தான அல்ட்ரா-பதப்படுத்தப்பட்ட (NOVA $nova) உணவுப் பொருள் ஆகும். ');
      }
    } else {
      b.write('போதுமான தகவல்கள் இல்லாததால் ஆரோக்கிய மதிப்பெண் கணக்கிட முடியவில்லை. ');
    }

    // Red-Cap Override
    if (product.redCapTriggered) {
      b.write('எச்சரிக்கை: இதில் சிவப்பு-பிரிவு அபாயகரமான ரசாயன பொருட்கள் கண்டறியப்பட்டுள்ளன');
      if (redAdditives.isNotEmpty) {
        b.write(' (${redAdditives.take(3).join(", ")})');
      }
      b.write('. இதன் மதிப்பெண் 39 அல்லது அதற்கும் குறைவாக கட்டுப்படுத்தப்பட்டுள்ளது. ');
    }

    // Nutrient Breakdown
    final sugar = product.sugarGPer100g.toStringAsFixed(1);
    final sodium = product.sodiumMgPer100g.round();
    final satFat = product.satFatGPer100g.toStringAsFixed(1);
    b.write('100 கிராமில் $sugar கிராம் சர்க்கரை, $sodium மி.கி சோடியம், மற்றும் $satFat கிராம் நிறைவுற்ற கொழுப்பு உள்ளது. ');

    if (redAdditives.isNotEmpty) {
      b.write('இதில் ${redAdditives.length} அபாயகரமான ரசாயன சேர்க்கைகள் உள்ளன. ');
    } else if (product.additives.isNotEmpty) {
      b.write('இதில் ${product.additives.length} உணவு சேர்க்கைகள் உள்ளன. ');
    }

    // Sugar Splitting Warning
    if (product.splitSugars.isNotEmpty) {
      b.write('கவனம்: இதில் ${product.splitSugars.length} மறைமுக சர்க்கரை வகைகள் உள்ளன. ');
    }

    // Personalized Safe Dosage Recommendation
    b.write('உங்கள் $weight கிலோ உடல் எடைக்கு ஏற்ப, ஒரு முறைக்கு பரிந்துரைக்கப்படும் பாதுகாப்பான அளவு $safeGrams கிராம் ஆகும்');
    if (product.safePieces != null && product.safePieces! > 0) {
      b.write(' (சுமார் ${product.safePieces} துண்டுகள்)');
    }
    b.write('. பரிந்துரைக்கப்படும் பயன்பாடு: ${product.frequencySchedule}. வரம்புக்குட்பட்ட காரணி: ${product.limitingFactor}.');

    return b.toString();
  }

  /// 4. TELUGU (తెలుగు - Telugu Script)
  static String _buildTeluguScript(
    ScannedProductResult product,
    UserProfileModel userProfile,
  ) {
    final b = StringBuffer();
    final name = product.productName;
    final score = product.healthScore;
    final nova = product.novaGrade;
    final weight = userProfile.weightKg.round();
    final safeGrams = product.safePortionGrams;
    final redAdditives = _extractRedAdditives(product);

    // Product Header
    b.write('$name యొక్క వెరిబైట్ ఆరోగ్య విశ్లేషణ. ');

    // Health Score & Verdict
    if (score != null) {
      if (score >= 70 && !product.redCapTriggered) {
        b.write('దీని ఆరోగ్య స్కోరు 100 కి $score. ఇది పోషకమైన మరియు సురక్షితమైన (NOVA $nova) వర్గంలోకి వస్తుంది. ');
      } else if (score >= 40 && !product.redCapTriggered) {
        b.write('దీని ఆరోగ్య స్కోరు 100 కి $score. ఇది జాగ్రత్త వహించాల్సిన (NOVA $nova) వర్గంలోకి వస్తుంది. ');
      } else {
        b.write('దీని ఆరోగ్య స్కోరు 100 కి $score. ఇది ఆరోగ్యానికి ప్రమాదకరమైన అల్ట్రా-ప్రాసెస్డ్ (NOVA $nova) ఆహారంగా వర్గీకరించబడింది. ');
      }
    } else {
      b.write('సరిపడా సమాచారం లేనందున ఆరోగ్య స్కోరు లెక్కించబడలేదు. ');
    }

    // Red-Cap Override
    if (product.redCapTriggered) {
      b.write('హెచ్చరిక: ఇందులో రెడ్-టైర్ హానికరమైన రసాయన సంకలనాలు గుర్తించబడ్డాయి');
      if (redAdditives.isNotEmpty) {
        b.write(' (${redAdditives.take(3).join(", ")})');
      }
      b.write('. దీని స్కోరు 39 లేదా అంతకంటే తక్కువగా పరిమితం చేయబడింది. ');
    }

    // Nutrient Breakdown
    final sugar = product.sugarGPer100g.toStringAsFixed(1);
    final sodium = product.sodiumMgPer100g.round();
    final satFat = product.satFatGPer100g.toStringAsFixed(1);
    b.write('ప్రతి 100 గ్రాములలో $sugar గ్రాముల చక్కెర, $sodium మిల్లీగ్రాముల సోడియం, మరియు $satFat గ్రాముల సంతృప్త కొవ్వు ఉన్నాయి. ');

    if (redAdditives.isNotEmpty) {
      b.write('ఇందులో ${redAdditives.length} హానికరమైన రసాయన సంకలనాలు ఉన్నాయి. ');
    } else if (product.additives.isNotEmpty) {
      b.write('ఇందులో ${product.additives.length} ఆహార సంకలనాలు ఉన్నాయి. ');
    }

    // Sugar Splitting Warning
    if (product.splitSugars.isNotEmpty) {
      b.write('గమనిక: ఇందులో ${product.splitSugars.length} దాగి ఉన్న చక్కెర రకాలు ఉన్నాయి. ');
    }

    // Personalized Safe Dosage Recommendation
    b.write('మీ $weight కిలోల బరువు ప్రకారం, ఒకేసారి తీసుకోగల గరిష్ట సురక్షిత పరిమాణం $safeGrams గ్రాములు');
    if (product.safePieces != null && product.safePieces! > 0) {
      b.write(' (సుమారు ${product.safePieces} ముక్కలు)');
    }
    b.write('. సిఫార్సు చేసిన వ్యవధి: ${product.frequencySchedule}. పరిమితి అంశం: ${product.limitingFactor}.');

    return b.toString();
  }

  /// 5. ENGLISH (en-IN)
  static String _buildEnglishScript(
    ScannedProductResult product,
    UserProfileModel userProfile,
  ) {
    final b = StringBuffer();
    final name = product.productName;
    final score = product.healthScore;
    final nova = product.novaGrade;
    final weight = userProfile.weightKg.round();
    final safeGrams = product.safePortionGrams;
    final redAdditives = _extractRedAdditives(product);

    // Product Header
    b.write('Here is the safety verdict for $name. ');

    // Health Score & Verdict
    if (score != null) {
      if (score >= 70 && !product.redCapTriggered) {
        b.write('Overall health score is $score out of 100, classified as Nutri Safe (NOVA $nova). ');
      } else if (score >= 40 && !product.redCapTriggered) {
        b.write('Overall health score is $score out of 100, classified as Caution (NOVA $nova). ');
      } else {
        b.write('Overall health score is $score out of 100, classified as Hazardous or Ultra-Processed (NOVA $nova). ');
      }
    } else {
      b.write('Overall health score has insufficient data. ');
    }

    // Red-Cap Override
    if (product.redCapTriggered) {
      b.write('Warning: A strict red-cap toxic override is triggered. ');
      if (redAdditives.isNotEmpty) {
        b.write('This product contains hazardous additives: ${redAdditives.take(3).join(", ")}. ');
      }
      b.write('Health score is restricted to 39 or below. ');
    } else {
      b.write('No toxic red-cap chemical additives were detected. ');
    }

    // Nutrient Breakdown
    final sugar = product.sugarGPer100g.toStringAsFixed(1);
    final sodium = product.sodiumMgPer100g.round();
    final satFat = product.satFatGPer100g.toStringAsFixed(1);
    b.write('Per 100 grams, it contains $sugar grams sugar, $sodium milligrams sodium, and $satFat grams saturated fat. ');

    if (product.splitSugars.isNotEmpty) {
      b.write(
        'Be aware: Hidden sugar splitting was detected across ${product.splitSugars.length} sweetener aliases. ',
      );
    }

    // Personalized Safe Dosage Recommendation
    b.write('Based on your body weight of $weight kilograms, your prescribed safe consumption limit is $safeGrams grams');
    if (product.safePieces != null && product.safePieces! > 0) {
      b.write(', or about ${product.safePieces} pieces');
    }
    b.write('. Recommended frequency: ${product.frequencySchedule}. Limiting constraint: ${product.limitingFactor}.');

    return b.toString();
  }
}
