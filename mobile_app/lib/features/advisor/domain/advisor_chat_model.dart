/// Domain models for Page 11: Personal AI Health Advisor.
/// Encapsulates chat messages, citation metadata, safe dosage advice,
/// and contextual scanned product data passed to the AI.
class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String source; // 'gemini_2.5_flash' | 'rule_based_fallback' | 'local_offline'
  final List<String> citations;
  final double? safePortionGrams;
  final String? frequencySchedule;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.source = 'user',
    this.citations = const [],
    this.safePortionGrams,
    this.frequencySchedule,
  });

  factory ChatMessage.user(String text) {
    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_u',
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      source: 'user',
    );
  }

  factory ChatMessage.advisor({
    required String text,
    String source = 'gemini_3.5_flash',
    List<String> citations = const [],
    double? safePortionGrams,
    String? frequencySchedule,
  }) {
    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}_a',
      text: text,
      isUser: false,
      timestamp: DateTime.now(),
      source: source,
      citations: citations,
      safePortionGrams: safePortionGrams,
      frequencySchedule: frequencySchedule,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String? ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
      text: json['response'] as String? ?? json['text'] as String? ?? '',
      isUser: json['is_user'] as bool? ?? false,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      source: json['source'] as String? ?? 'gemini_3.5_flash',
      citations: (json['citations'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      safePortionGrams: (json['safe_portion_grams'] as num?)?.toDouble(),
      frequencySchedule: json['frequency_schedule'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'is_user': isUser,
      'timestamp': timestamp.toIso8601String(),
      'source': source,
      'citations': citations,
      'safe_portion_grams': safePortionGrams,
      'frequency_schedule': frequencySchedule,
    };
  }
}

/// Product context passed to the AI when asking about a scanned item.
class ProductAdvisorContext {
  final String productName;
  final String barcode;
  final int? healthScore;
  final List<Map<String, dynamic>> additives;
  final Map<String, dynamic> nutrition;
  final String? brandName;
  final String? category;
  final List<String> ingredients;
  final int? novaGrade;
  final Map<String, dynamic> extendedNutrients;
  final Map<String, dynamic>? healthIntelligence;

  const ProductAdvisorContext({
    required this.productName,
    required this.barcode,
    this.healthScore,
    this.additives = const [],
    this.nutrition = const {},
    this.brandName,
    this.category,
    this.ingredients = const [],
    this.novaGrade,
    this.extendedNutrients = const {},
    this.healthIntelligence,
  });

  Map<String, dynamic> toBackendPayload() {
    return {
      'product_name': productName,
      'barcode': barcode,
      'health_score': healthScore,
      'additives': additives,
      'nutrition': nutrition,
      if (brandName != null) 'brand_name': brandName,
      if (category != null) 'category': category,
      'ingredients': ingredients,
      if (novaGrade != null) 'nova_grade': novaGrade,
      'extended_nutrients': extendedNutrients,
      if (healthIntelligence != null) 'health_intelligence': healthIntelligence,
    };
  }
}

