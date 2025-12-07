import 'package:cloud_firestore/cloud_firestore.dart';

class SmartRecurringList {
  final String id;
  final String familyId;
  final String name;
  final List<String> itemNames; // Suggested items based on history
  final String frequency; // 'weekly', 'monthly', 'custom'
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final int usageCount; // How many times this list has been used
  final Map<String, int> itemFrequencies; // itemName -> count (how often it appears)

  SmartRecurringList({
    required this.id,
    required this.familyId,
    required this.name,
    required this.itemNames,
    this.frequency = 'weekly',
    required this.createdAt,
    this.lastUsedAt,
    this.usageCount = 0,
    Map<String, int>? itemFrequencies,
  }) : itemFrequencies = itemFrequencies ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'familyId': familyId,
        'name': name,
        'itemNames': itemNames,
        'frequency': frequency,
        'createdAt': createdAt.toIso8601String(),
        'lastUsedAt': lastUsedAt?.toIso8601String(),
        'usageCount': usageCount,
        'itemFrequencies': itemFrequencies,
      };

  factory SmartRecurringList.fromJson(Map<String, dynamic> json) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return DateTime.now();
        }
      }
      return DateTime.now();
    }

    return SmartRecurringList(
      id: json['id'] as String? ?? '',
      familyId: json['familyId'] as String? ?? '',
      name: json['name'] as String? ?? 'Smart List',
      itemNames: (json['itemNames'] as List<dynamic>?)?.cast<String>() ?? [],
      frequency: json['frequency'] as String? ?? 'weekly',
      createdAt: parseDateTime(json['createdAt']),
      lastUsedAt: json['lastUsedAt'] != null ? parseDateTime(json['lastUsedAt']) : null,
      usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
      itemFrequencies: (json['itemFrequencies'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, (v as num).toInt()))
          ?? {},
    );
  }

  SmartRecurringList copyWith({
    String? id,
    String? familyId,
    String? name,
    List<String>? itemNames,
    String? frequency,
    DateTime? createdAt,
    DateTime? lastUsedAt,
    int? usageCount,
    Map<String, int>? itemFrequencies,
  }) =>
      SmartRecurringList(
        id: id ?? this.id,
        familyId: familyId ?? this.familyId,
        name: name ?? this.name,
        itemNames: itemNames ?? this.itemNames,
        frequency: frequency ?? this.frequency,
        createdAt: createdAt ?? this.createdAt,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
        usageCount: usageCount ?? this.usageCount,
        itemFrequencies: itemFrequencies ?? this.itemFrequencies,
      );
}
