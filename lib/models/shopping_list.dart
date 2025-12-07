import 'package:cloud_firestore/cloud_firestore.dart';

enum ShoppingListStatus {
  active,
  completed,
  archived,
}

class ShoppingList {
  final String id;
  final String name;
  final String familyId;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? completedAt;
  final ShoppingListStatus status;
  final bool isDefault;
  final Map<String, bool> sharedWith; // userId -> bool (true if shared)
  final int itemCount;
  final int completedItemCount;

  ShoppingList({
    required this.id,
    required this.name,
    required this.familyId,
    required this.createdBy,
    required this.createdAt,
    this.completedAt,
    this.status = ShoppingListStatus.active,
    this.isDefault = false,
    Map<String, bool>? sharedWith,
    this.itemCount = 0,
    this.completedItemCount = 0,
  }) : sharedWith = sharedWith ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'familyId': familyId,
        'createdBy': createdBy,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'status': status.name,
        'isDefault': isDefault,
        'sharedWith': sharedWith,
        'itemCount': itemCount,
        'completedItemCount': completedItemCount,
      };

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
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

    return ShoppingList(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled List',
      familyId: json['familyId'] as String? ?? '',
      createdBy: json['createdBy'] as String? ?? '',
      createdAt: parseDateTime(json['createdAt']),
      completedAt: json['completedAt'] != null ? parseDateTime(json['completedAt']) : null,
      status: json['status'] != null
          ? ShoppingListStatus.values.firstWhere(
              (e) => e.name == json['status'],
              orElse: () => ShoppingListStatus.active,
            )
          : ShoppingListStatus.active,
      isDefault: json['isDefault'] == true,
      sharedWith: (json['sharedWith'] as Map<String, dynamic>?)
              ?.map((k, v) => MapEntry(k, v == true))
          ?? {},
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      completedItemCount: (json['completedItemCount'] as num?)?.toInt() ?? 0,
    );
  }

  ShoppingList copyWith({
    String? id,
    String? name,
    String? familyId,
    String? createdBy,
    DateTime? createdAt,
    DateTime? completedAt,
    ShoppingListStatus? status,
    bool? isDefault,
    Map<String, bool>? sharedWith,
    int? itemCount,
    int? completedItemCount,
  }) =>
      ShoppingList(
        id: id ?? this.id,
        name: name ?? this.name,
        familyId: familyId ?? this.familyId,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
        completedAt: completedAt ?? this.completedAt,
        status: status ?? this.status,
        isDefault: isDefault ?? this.isDefault,
        sharedWith: sharedWith ?? this.sharedWith,
        itemCount: itemCount ?? this.itemCount,
        completedItemCount: completedItemCount ?? this.completedItemCount,
      );

  bool get isCompleted => status == ShoppingListStatus.completed;
  bool get isActive => status == ShoppingListStatus.active;
  double get completionPercentage => itemCount > 0 ? (completedItemCount / itemCount) : 0.0;
}
