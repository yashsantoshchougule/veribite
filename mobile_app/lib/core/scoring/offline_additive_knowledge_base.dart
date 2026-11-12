import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../features/advisor/domain/advisor_chat_model.dart';
import '../../features/profile/domain/user_profile_model.dart';

/// Instant On-Device Additive & Toxicology Knowledge Base (Tier 0).
/// Loads the 770+ harmonized additive corpus from `assets/db/full_additives_corpus.json`
/// into an O(1) in-memory index (<1ms query response time).
class OfflineAdditiveKnowledgeBase {
  static OfflineAdditiveKnowledgeBase? _instance;
  static OfflineAdditiveKnowledgeBase get instance =>
      _instance ??= OfflineAdditiveKnowledgeBase();

  bool _isInitialized = false;
  final Map<String, Map<String, dynamic>> _insIndex = {};
  final Map<String, Map<String, dynamic>> _eIndex = {};
  final Map<String, Map<String, dynamic>> _nameIndex = {};
  final Map<String, Map<String, dynamic>> _synonymIndex = {};

  /// Common high-frequency synonyms / trade names
  static const Map<String, String> _commonSynonyms = {
    'msg': '621',
    'ajinomoto': '621',
    'monosodium glutamate': '621',
    'tartrazine': '102',
    'sunset yellow': '110',
    'carmoisine': '122',
    'ponceau 4r': '124',
    'allura red': '129',
    'brilliant blue': '133',
    'quinoline yellow': '104',
    'aspartame': '951',
    'acesulfame k': '950',
    'acesulfame potassium': '950',
    'sucralose': '955',
    'sodium benzoate': '211',
    'potassium sorbate': '202',
    'citric acid': '330',
    'soy lecithin': '322',
    'lecithin': '322',
    'bha': '320',
    'bht': '321',
    'tbhq': '319',
    'carmine': '120',
    'cochineal': '120',
    'titanium dioxide': '171',
    'potassium bromate': '924a',
  };

  /// Ensure index is loaded into memory
  Future<void> ensureInitialized() async {
    if (_isInitialized) return;
    try {
      final jsonString =
          await rootBundle.loadString('assets/db/full_additives_corpus.json');
      final list = jsonDecode(jsonString) as List<dynamic>;

      for (final item in list) {
        if (item is! Map<String, dynamic>) continue;
        final ins = (item['ins_code']?.toString() ?? '').toLowerCase().trim();
        final eCode = (item['e_code']?.toString() ?? '').toLowerCase().trim();
        final name = (item['primary_name']?.toString() ?? '').toLowerCase().trim();
        final synonyms =
            (item['synonyms_csv']?.toString() ?? '').toLowerCase().split(',');

        if (ins.isNotEmpty) {
          _insIndex[ins] = item;
          // Also index normalized numeric part, e.g. "621" from "621" or "100" from "100(i)"
          final cleanNum = ins.replaceAll(RegExp(r'[^0-9a-z]'), '');
          if (cleanNum.isNotEmpty && !_insIndex.containsKey(cleanNum)) {
            _insIndex[cleanNum] = item;
          }
        }
        if (eCode.isNotEmpty) {
          _eIndex[eCode] = item;
          final cleanE = eCode.replaceAll(RegExp(r'[^0-9a-z]'), '');
          if (cleanE.isNotEmpty && !_eIndex.containsKey(cleanE)) {
            _eIndex[cleanE] = item;
          }
        }
        if (name.isNotEmpty) {
          _nameIndex[name] = item;
        }
        for (final syn in synonyms) {
          final trimmed = syn.trim();
          if (trimmed.length > 2 && !_synonymIndex.containsKey(trimmed)) {
            _synonymIndex[trimmed] = item;
          }
        }
      }
      _isInitialized = true;
      debugPrint(
          '[OfflineAdditiveKnowledgeBase] Initialized ${_insIndex.length} INS codes & ${_nameIndex.length} additives into memory.');
    } catch (e) {
      debugPrint('[OfflineAdditiveKnowledgeBase] Initialization notice: $e');
    }
  }

  /// Fast regex extraction of INS/E codes or known chemical names from user query
  Map<String, dynamic>? lookupQuery(String query) {
    if (!_isInitialized) return null;
    final lower = query.toLowerCase().trim();

    // 1. Direct synonym matching (e.g., "msg", "tartrazine", "aspartame")
    for (final entry in _commonSynonyms.entries) {
      final pattern = RegExp(r'\b' + RegExp.escape(entry.key) + r'\b');
      if (pattern.hasMatch(lower)) {
        final code = entry.value;
        if (_insIndex.containsKey(code)) return _insIndex[code];
      }
    }

    // 2. Regex for INS / E codes, e.g., "INS 621", "INS-621", "INS621", "E621", "E-102", "INS 150d"
    final insMatch = RegExp(r'\b(?:ins|e)[ -]?(\d{3,4}[a-z]?(?:\([a-z0-9]+\))?)\b')
        .firstMatch(lower);
    if (insMatch != null) {
      final code = insMatch.group(1)?.toLowerCase().trim();
      if (code != null) {
        if (_insIndex.containsKey(code)) return _insIndex[code];
        if (_eIndex.containsKey('e$code')) return _eIndex['e$code'];
        final cleanCode = code.replaceAll(RegExp(r'[^0-9a-z]'), '');
        if (_insIndex.containsKey(cleanCode)) return _insIndex[cleanCode];
      }
    }

    // 3. Check for standalone 3 or 4 digit numbers if query mentions "additive" or "code"
    if (lower.contains('additive') || lower.contains('code') || lower.contains('chemical') || lower.contains('number')) {
      final numMatch = RegExp(r'\b(\d{3,4}[a-z]?)\b').firstMatch(lower);
      if (numMatch != null) {
        final code = numMatch.group(1)?.toLowerCase().trim();
        if (code != null && _insIndex.containsKey(code)) {
          return _insIndex[code];
        }
      }
    }

    // 4. Exact or substring match in name index
    for (final entry in _nameIndex.entries) {
      if (entry.key.length >= 4 && lower.contains(entry.key)) {
        return entry.value;
      }
    }

    // 5. Synonym index match
    for (final entry in _synonymIndex.entries) {
      if (entry.key.length >= 4 && lower.contains(entry.key)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Builds a complete authoritative clinical toxicology response in <5ms
  ChatMessage buildClinicalAdditiveReport(
    Map<String, dynamic> additive, {
    UserProfileModel? userProfile,
  }) {
    final ins = additive['ins_code'] ?? 'Unknown';
    final eCode = additive['e_code'] ?? 'E$ins';
    final name = additive['primary_name'] ?? 'Food Additive';
    final functionalClass = additive['functional_class'] ?? 'Food Formulation Agent';
    final riskTier = (additive['risk_tier']?.toString() ?? 'CAUTION').toUpperCase();
    final triggersRedCap = additive['triggers_red_cap'] == 1 || additive['triggers_red_cap'] == true;
    final jecfaAdi = (additive['jecfa_adi_mg_kg'] as num?)?.toDouble();
    final childFlag = additive['child_hyperactivity_flag'] == 1 || additive['child_hyperactivity_flag'] == true;
    final bannedIn = additive['banned_jurisdictions']?.toString();

    final userWeight = userProfile?.weightKg ?? 65.0;
    final isChild = userProfile?.isChild ?? false;

    final buffer = StringBuffer();
    buffer.writeln('### Clinical Toxicology Profile: $name (INS $ins / $eCode)\n');

    // Risk Tier Pill & Classification
    if (riskTier == 'RED' || triggersRedCap) {
      buffer.writeln('🛑 **Safety Classification: HIGH RISK / RED-TIER ADVISORY**');
      buffer.writeln('• **Enforcement:** Triggers VeriBite Scientific Red-Cap (≤39/100) due to recognized clinical or toxicological concerns.');
    } else if (riskTier == 'CAUTION' || riskTier == 'YELLOW') {
      buffer.writeln('⚠️ **Safety Classification: MODERATE CAUTION / YELLOW TIER**');
      buffer.writeln('• **Enforcement:** Safe within regulatory limits, but continuous heavy cumulative exposure is cautioned.');
    } else {
      buffer.writeln('✅ **Safety Classification: RECOGNIZED AS SAFE (GREEN TIER)**');
      buffer.writeln('• **Enforcement:** Evaluated by WHO/JECFA and FSSAI with minimal health risk in typical dietary portions.');
    }

    buffer.writeln('• **Functional Class:** $functionalClass');

    // JECFA ADI Calculation scaled to user body weight
    if (jecfaAdi != null && jecfaAdi > 0) {
      final userDailyLimitMg = (jecfaAdi * userWeight).round();
      buffer.writeln('• **Acceptable Daily Intake (ADI):** **${jecfaAdi.toStringAsFixed(1)} mg/kg body weight/day** (JECFA harmonized).');
      buffer.writeln('  * *Personal Daily Ceiling:* For your calibrated body weight (${userWeight.toStringAsFixed(0)} kg), safe intake is capped at **$userDailyLimitMg mg per day**.');
    } else {
      buffer.writeln('• **Acceptable Daily Intake (ADI):** Not Specified (Self-limiting in standard food formulations under Good Manufacturing Practice).');
    }

    // Pediatric Southampton warning
    if (childFlag || isChild) {
      buffer.writeln('\n👶 **Pediatric & Child Safety Advisory:**');
      if (childFlag) {
        buffer.writeln('• ⚠️ Included in the **Southampton Six** cohort of synthetic colourings/additives associated with increased hyperactivity and attention deficit symptoms in children (EU Regulation 1333/2008 requires warning label).');
      } else {
        buffer.writeln('• Children clear synthetic additives at lower metabolic rates. Limit ultra-processed foods containing this additive.');
      }
    }

    // International Bans / Jurisdictions
    if (bannedIn != null && bannedIn.isNotEmpty && bannedIn != 'None') {
      buffer.writeln('\n🌍 **Global Jurisdictional Status:**');
      buffer.writeln('• **Restricted/Banned In:** $bannedIn.');
    }

    final citations = <String>[
      'WHO/FAO JECFA Monograph',
      'FSSAI Food Safety Standards (2011)',
      if (childFlag) 'EFSA Southampton Evaluation (2008)',
      'Codex General Standard for Food Additives (GSFA)',
    ];

    return ChatMessage.advisor(
      text: buffer.toString().trim(),
      source: 'local_clinical_engine',
      citations: citations,
    );
  }
}
