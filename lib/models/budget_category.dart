import 'package:cloud_firestore/cloud_firestore.dart';

/// Budget category model for organizing transactions
class BudgetCategory {
  final String id;
  final String budgetId;
  final String name;
  final String? description;
  final String? icon; // Icon name or emoji
  final String color; // Hex color code
  final double? limit; // Optional spending limit for this category
  final bool isDefault; // Whether this is a default category
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  BudgetCategory({
    required this.id,
    required this.budgetId,
    required this.name,
    this.description,
    this.icon,
    this.color = '#2196F3', // Default blue
    this.limit,
    this.isDefault = false,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'budgetId': budgetId,
        'name': name,
        'description': description,
        'icon': icon,
        'color': color,
        'limit': limit,
        'isDefault': isDefault,
        'isActive': isActive,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      };

  factory BudgetCategory.fromJson(Map<String, dynamic> json) {
    try {
      // Handle createdAt
      DateTime createdAt;
      if (json['createdAt'] != null) {
        if (json['createdAt'] is Timestamp) {
          createdAt = (json['createdAt'] as Timestamp).toDate();
        } else if (json['createdAt'] is String) {
          createdAt = DateTime.parse(json['createdAt'] as String);
        } else {
          createdAt = DateTime.now();
        }
      } else {
        createdAt = DateTime.now();
      }

      // Handle updatedAt
      DateTime? updatedAt;
      if (json['updatedAt'] != null) {
        if (json['updatedAt'] is Timestamp) {
          updatedAt = (json['updatedAt'] as Timestamp).toDate();
        } else if (json['updatedAt'] is String) {
          updatedAt = DateTime.parse(json['updatedAt'] as String);
        }
      }

      return BudgetCategory(
        id: json['id'] as String? ?? '',
        budgetId: json['budgetId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        icon: json['icon'] as String?,
        color: json['color'] as String? ?? '#2196F3',
        limit: (json['limit'] as num?)?.toDouble(),
        isDefault: json['isDefault'] as bool? ?? false,
        isActive: json['isActive'] as bool? ?? true,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
    } catch (e) {
      throw FormatException('Error parsing BudgetCategory: $e');
    }
  }

  BudgetCategory copyWith({
    String? id,
    String? budgetId,
    String? name,
    String? description,
    String? icon,
    String? color,
    double? limit,
    bool? isDefault,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetCategory(
      id: id ?? this.id,
      budgetId: budgetId ?? this.budgetId,
      name: name ?? this.name,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      limit: limit ?? this.limit,
      isDefault: isDefault ?? this.isDefault,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

