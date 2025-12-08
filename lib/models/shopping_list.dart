import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a shopping list that can be shared among family members
class ShoppingList {
  final String id;
  final String name;
  final String? description;
  final String creatorId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isDefault;
  final List<String> sharedWith; // Family member IDs who can see this list
  final bool isArchived;
  final int itemCount; // Cached count of items
  final int completedItemCount; // Cached count of completed items

  ShoppingList({
    required this.id,
    required this.name,
    this.description,
    required this.creatorId,
    required this.createdAt,
    this.updatedAt,
    this.isDefault = false,
    List<String>? sharedWith,
    this.isArchived = false,
    this.itemCount = 0,
    this.completedItemCount = 0,
  }) : sharedWith = sharedWith ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'creatorId': creatorId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'isDefault': isDefault,
        'sharedWith': sharedWith,
        'isArchived': isArchived,
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

    DateTime? parseOptionalDateTime(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          return null;
        }
      }
      return null;
    }

    return ShoppingList(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Untitled List',
      description: json['description'] as String?,
      creatorId: json['creatorId'] as String? ?? '',
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseOptionalDateTime(json['updatedAt']),
      isDefault: json['isDefault'] as bool? ?? false,
      sharedWith: (json['sharedWith'] as List<dynamic>?)?.cast<String>() ?? [],
      isArchived: json['isArchived'] as bool? ?? false,
      itemCount: json['itemCount'] as int? ?? 0,
      completedItemCount: json['completedItemCount'] as int? ?? 0,
    );
  }

  ShoppingList copyWith({
    String? id,
    String? name,
    String? description,
    String? creatorId,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isDefault,
    List<String>? sharedWith,
    bool? isArchived,
    int? itemCount,
    int? completedItemCount,
  }) =>
      ShoppingList(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        creatorId: creatorId ?? this.creatorId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isDefault: isDefault ?? this.isDefault,
        sharedWith: sharedWith ?? this.sharedWith,
        isArchived: isArchived ?? this.isArchived,
        itemCount: itemCount ?? this.itemCount,
        completedItemCount: completedItemCount ?? this.completedItemCount,
      );

  /// Progress as a percentage (0-100)
  double get progress => itemCount > 0 ? (completedItemCount / itemCount) * 100 : 0;
  
  /// Whether all items are completed
  bool get isCompleted => itemCount > 0 && completedItemCount >= itemCount;
}
