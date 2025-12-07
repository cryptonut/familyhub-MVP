import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a category for grouping shopping items
class ShoppingCategory {
  final String id;
  final String name;
  final String? icon; // Icon name or emoji
  final String? color; // Hex color string
  final int order; // Sort order
  final bool isSystem; // System-defined categories can't be deleted
  final DateTime createdAt;

  ShoppingCategory({
    required this.id,
    required this.name,
    this.icon,
    this.color,
    this.order = 0,
    this.isSystem = false,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'color': color,
        'order': order,
        'isSystem': isSystem,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ShoppingCategory.fromJson(Map<String, dynamic> json) {
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

    return ShoppingCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Uncategorized',
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      order: json['order'] as int? ?? 0,
      isSystem: json['isSystem'] as bool? ?? false,
      createdAt: parseDateTime(json['createdAt']),
    );
  }

  ShoppingCategory copyWith({
    String? id,
    String? name,
    String? icon,
    String? color,
    int? order,
    bool? isSystem,
    DateTime? createdAt,
  }) =>
      ShoppingCategory(
        id: id ?? this.id,
        name: name ?? this.name,
        icon: icon ?? this.icon,
        color: color ?? this.color,
        order: order ?? this.order,
        isSystem: isSystem ?? this.isSystem,
        createdAt: createdAt ?? this.createdAt,
      );

  /// Default shopping categories
  static List<ShoppingCategory> get defaultCategories => [
        ShoppingCategory(
          id: 'produce',
          name: 'Produce',
          icon: '🥬',
          color: '#4CAF50',
          order: 0,
          isSystem: true,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'dairy',
          name: 'Dairy',
          icon: '🥛',
          color: '#2196F3',
          order: 1,
          isSystem: true,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'meat',
          name: 'Meat & Seafood',
          icon: '🥩',
          color: '#F44336',
          order: 2,
          isSystem: true,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'bakery',
          name: 'Bakery',
          icon: '🍞',
          color: '#FF9800',
          order: 3,
          isSystem: true,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'frozen',
          name: 'Frozen',
          icon: '🧊',
          color: '#00BCD4',
          order: 4,
          isSystem: true,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'pantry',
          name: 'Pantry',
          icon: '🥫',
          color: '#795548',
          order: 5,
          isSystem: true,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'beverages',
          name: 'Beverages',
          icon: '🥤',
          color: '#9C27B0',
          order: 6,
          isSystem: true,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'snacks',
          name: 'Snacks',
          icon: '🍿',
          color: '#FF5722',
          order: 7,
          isSystem: true,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'household',
          name: 'Household',
          icon: '🧹',
          color: '#607D8B',
          order: 8,
          isSystem: true,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'personal',
          name: 'Personal Care',
          icon: '🧴',
          color: '#E91E63',
          order: 9,
          isSystem: true,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'other',
          name: 'Other',
          icon: '📦',
          color: '#9E9E9E',
          order: 99,
          isSystem: true,
          createdAt: DateTime.now(),
        ),
      ];
}
