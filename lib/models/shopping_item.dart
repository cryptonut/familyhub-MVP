enum ShoppingItemStatus {
  pending,
  gotIt,
  unavailable,
  cancelled,
}

class ShoppingItem {
  final String id;
  final String listId;
  final String name;
  final int quantity;
  final String? unit;
  final String addedBy;
  final String? notes;
  final String? categoryId;
  final String categoryName;
  final ShoppingItemStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? purchasedAt;
  final String? completedBy;
  final DateTime? completedAt;
  final int? purchaseCount;
  final bool? isRecurring;

  ShoppingItem({
    required this.id,
    required this.listId,
    required this.name,
    this.quantity = 1,
    this.unit,
    required this.addedBy,
    this.notes,
    this.categoryId,
    this.categoryName = 'Other',
    this.status = ShoppingItemStatus.pending,
    required this.createdAt,
    this.updatedAt,
    this.purchasedAt,
    this.completedBy,
    this.completedAt,
    this.purchaseCount,
    this.isRecurring,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'listId': listId,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'addedBy': addedBy,
        'notes': notes,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'purchasedAt': purchasedAt?.toIso8601String(),
        'completedBy': completedBy,
        'completedAt': completedAt?.toIso8601String(),
        'purchaseCount': purchaseCount,
        'isRecurring': isRecurring,
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
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

      // Parse status
      ShoppingItemStatus status = ShoppingItemStatus.pending;
      if (json['status'] != null) {
        try {
          status = ShoppingItemStatus.values.firstWhere(
            (e) => e.name == json['status'],
            orElse: () => ShoppingItemStatus.pending,
          );
        } catch (e) {
          status = ShoppingItemStatus.pending;
        }
      }

      return ShoppingItem(
        id: json['id'] as String? ?? '',
        listId: json['listId'] as String? ?? '',
        name: json['name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        unit: json['unit'] as String?,
        addedBy: json['addedBy'] as String? ?? '',
        notes: json['notes'] as String?,
        categoryId: json['categoryId'] as String?,
        categoryName: json['categoryName'] as String? ?? 'Other',
        status: status,
        createdAt: createdAt,
        updatedAt: json['updatedAt'] != null
            ? (json['updatedAt'] is String
                ? DateTime.parse(json['updatedAt'] as String)
                : json['updatedAt'] as DateTime)
            : null,
        purchasedAt: json['purchasedAt'] != null
            ? (json['purchasedAt'] is String
                ? DateTime.parse(json['purchasedAt'] as String)
                : json['purchasedAt'] as DateTime)
            : null,
        completedBy: json['completedBy'] as String?,
        completedAt: json['completedAt'] != null
            ? (json['completedAt'] is String
                ? DateTime.parse(json['completedAt'] as String)
                : json['completedAt'] as DateTime)
            : null,
        purchaseCount: (json['purchaseCount'] as num?)?.toInt(),
        isRecurring: json['isRecurring'] as bool?,
      );
    } catch (e, st) {
      throw FormatException('Error parsing ShoppingItem: $e', st);
    }
  }

  ShoppingItem copyWith({
    String? id,
    String? listId,
    String? name,
    int? quantity,
    String? unit,
    String? addedBy,
    String? notes,
    String? categoryId,
    String? categoryName,
    ShoppingItemStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? purchasedAt,
    String? completedBy,
    DateTime? completedAt,
    int? purchaseCount,
    bool? isRecurring,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      addedBy: addedBy ?? this.addedBy,
      notes: notes ?? this.notes,
      categoryId: categoryId ?? this.categoryId,
      categoryName: categoryName ?? this.categoryName,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      completedBy: completedBy ?? this.completedBy,
      completedAt: completedAt ?? this.completedAt,
      purchaseCount: purchaseCount ?? this.purchaseCount,
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }

  bool get isPurchased => status == ShoppingItemStatus.gotIt;
  
  String get quantityDisplay {
    if (unit != null && unit!.isNotEmpty) {
      return '$quantity $unit';
    }
    return quantity.toString();
  }
}

