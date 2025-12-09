class ShoppingCategory {
  final String id;
  final String name;
  final String? icon;
  final int order;
  final DateTime createdAt;

  ShoppingCategory({
    required this.id,
    required this.name,
    this.icon,
    this.order = 0,
    required this.createdAt,
  });

  static List<ShoppingCategory> get defaultCategories => [
        ShoppingCategory(
          id: 'produce',
          name: 'Produce',
          icon: '🥬',
          order: 1,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'dairy',
          name: 'Dairy',
          icon: '🥛',
          order: 2,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'meat',
          name: 'Meat & Seafood',
          icon: '🥩',
          order: 3,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'bakery',
          name: 'Bakery',
          icon: '🍞',
          order: 4,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'frozen',
          name: 'Frozen',
          icon: '🧊',
          order: 5,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'pantry',
          name: 'Pantry',
          icon: '🥫',
          order: 6,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'beverages',
          name: 'Beverages',
          icon: '🥤',
          order: 7,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'snacks',
          name: 'Snacks',
          icon: '🍿',
          order: 8,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'household',
          name: 'Household',
          icon: '🧴',
          order: 9,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'personal',
          name: 'Personal Care',
          icon: '🧼',
          order: 10,
          createdAt: DateTime.now(),
        ),
        ShoppingCategory(
          id: 'other',
          name: 'Other',
          icon: '📦',
          order: 99,
          createdAt: DateTime.now(),
        ),
      ];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon,
        'order': order,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ShoppingCategory.fromJson(Map<String, dynamic> json) {
    try {
      // Handle createdAt - it's required but might be missing
      DateTime createdAt;
      if (json['createdAt'] != null) {
        if (json['createdAt'] is String) {
          createdAt = DateTime.parse(json['createdAt'] as String);
        } else if (json['createdAt'] is DateTime) {
          createdAt = json['createdAt'] as DateTime;
        } else {
          createdAt = DateTime.now();
        }
      } else {
        createdAt = DateTime.now();
      }

      return ShoppingCategory(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Other',
        icon: json['icon'] as String?,
        order: (json['order'] as num?)?.toInt() ?? 99,
        createdAt: createdAt,
      );
    } catch (e, st) {
      throw FormatException('Error parsing ShoppingCategory: $e', st);
    }
  }

  ShoppingCategory copyWith({
    String? id,
    String? name,
    String? icon,
    int? order,
    DateTime? createdAt,
  }) {
    return ShoppingCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

