import 'dart:convert';

/// Domain model representing a user's isolated health profile and biometrics.
/// Strictly partitioned by [userId] to ensure zero data bleeding across accounts.
class UserProfileModel {
  final String userId;
  final double weightKg;
  final bool isChild;
  final int? age;
  final String? gender;
  final double? heightCm;
  final bool isDiabetic;
  final bool isHypertensive;
  final bool isPregnancySafe;
  final bool isLowSugar;
  final List<String> allergens;
  final String? dietaryPreference;
  final String language;
  final bool isCompleted;
  final DateTime updatedAt;

  const UserProfileModel({
    required this.userId,
    this.weightKg = 65.0,
    this.isChild = false,
    this.age,
    this.gender,
    this.heightCm,
    this.isDiabetic = false,
    this.isHypertensive = false,
    this.isPregnancySafe = false,
    this.isLowSugar = false,
    this.allergens = const [],
    this.dietaryPreference,
    this.language = 'en',
    this.isCompleted = true,
    required this.updatedAt,
  });

  /// Standard safe baseline profile (used on Skip)
  factory UserProfileModel.defaults(String userId) {
    return UserProfileModel(
      userId: userId,
      weightKg: 65.0,
      isChild: false,
      isDiabetic: false,
      isHypertensive: false,
      isPregnancySafe: false,
      isLowSugar: false,
      allergens: const [],
      language: 'en',
      isCompleted: false, // Marked as skipped/default
      updatedAt: DateTime.now(),
    );
  }

  UserProfileModel copyWith({
    String? userId,
    double? weightKg,
    bool? isChild,
    int? age,
    String? gender,
    double? heightCm,
    bool? isDiabetic,
    bool? isHypertensive,
    bool? isPregnancySafe,
    bool? isLowSugar,
    List<String>? allergens,
    String? dietaryPreference,
    String? language,
    bool? isCompleted,
    DateTime? updatedAt,
  }) {
    return UserProfileModel(
      userId: userId ?? this.userId,
      weightKg: weightKg ?? this.weightKg,
      isChild: isChild ?? this.isChild,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      heightCm: heightCm ?? this.heightCm,
      isDiabetic: isDiabetic ?? this.isDiabetic,
      isHypertensive: isHypertensive ?? this.isHypertensive,
      isPregnancySafe: isPregnancySafe ?? this.isPregnancySafe,
      isLowSugar: isLowSugar ?? this.isLowSugar,
      allergens: allergens ?? this.allergens,
      dietaryPreference: dietaryPreference ?? this.dietaryPreference,
      language: language ?? this.language,
      isCompleted: isCompleted ?? this.isCompleted,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'user_id': userId,
      'weight_kg': weightKg,
      'is_child': isChild,
      'age': age,
      'gender': gender,
      'height_cm': heightCm,
      'is_diabetic': isDiabetic,
      'is_hypertensive': isHypertensive,
      'is_pregnancy_safe': isPregnancySafe,
      'is_low_sugar': isLowSugar,
      'allergens': allergens,
      'dietary_preference': dietaryPreference,
      'language': language,
      'is_completed': isCompleted,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory UserProfileModel.fromMap(Map<String, dynamic> map) {
    return UserProfileModel(
      userId: map['user_id'] as String? ?? map['device_id'] as String? ?? 'anonymous',
      weightKg: (map['weight_kg'] as num?)?.toDouble() ?? 65.0,
      isChild: map['is_child'] as bool? ?? false,
      age: map['age'] as int?,
      gender: map['gender'] as String?,
      heightCm: (map['height_cm'] as num?)?.toDouble(),
      isDiabetic: map['is_diabetic'] as bool? ?? false,
      isHypertensive: map['is_hypertensive'] as bool? ?? false,
      isPregnancySafe: map['is_pregnancy_safe'] as bool? ?? false,
      isLowSugar: map['is_low_sugar'] as bool? ?? false,
      allergens: (map['allergens'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      dietaryPreference: map['dietary_preference'] as String?,
      language: map['language'] as String? ?? 'en',
      isCompleted: map['is_completed'] as bool? ?? true,
      updatedAt: map['updated_at'] != null
          ? DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory UserProfileModel.fromJson(String source) =>
      UserProfileModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is UserProfileModel &&
        other.userId == userId &&
        other.weightKg == weightKg &&
        other.isChild == isChild &&
        other.age == age &&
        other.gender == gender &&
        other.isDiabetic == isDiabetic &&
        other.isHypertensive == isHypertensive &&
        other.isPregnancySafe == isPregnancySafe &&
        other.isLowSugar == isLowSugar &&
        other.dietaryPreference == dietaryPreference &&
        other.language == language &&
        other.isCompleted == isCompleted;
  }

  @override
  int get hashCode {
    return Object.hash(
      userId,
      weightKg,
      isChild,
      age,
      gender,
      isDiabetic,
      isHypertensive,
      isPregnancySafe,
      isLowSugar,
      dietaryPreference,
      language,
      isCompleted,
    );
  }
}

