import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a shopping item
enum ShoppingItemStatus {
  pending,   // Not yet bought
  gotIt,     // Successfully purchased
  unavailable, // Item was not available at the store
  cancelled,  // Item was removed/cancelled
}

/// Represents an item in a shopping list
class ShoppingItem {
  final String id;
  final String listId;
  final String name;
  final int quantity;
  final String? unit; // e.g., 'kg', 'pcs', 'L', etc.
  final String addedBy; // User ID who added this item
  final String? notes;
  final List<String> photoUrls; // Attached photos
  final String? categoryId;
  final String? categoryName; // For display purposes
  final ShoppingItemStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? completedBy; // User ID who marked this as got/unavailable
  final DateTime? completedAt;
  final double? price; // Price from receipt
  final bool isRecurring; // Part of a recurring smart list
  final int purchaseCount; // How many times this item has been purchased (for smart suggestions)

  ShoppingItem({
    required this.id,
    required this.listId,
    required this.name,
    this.quantity = 1,
    this.unit,
    required this.addedBy,
    this.notes,
    List<String>? photoUrls,
    this.categoryId,
    this.categoryName,
    this.status = ShoppingItemStatus.pending,
    required this.createdAt,
    this.updatedAt,
    this.completedBy,
    this.completedAt,
    this.price,
    this.isRecurring = false,
    this.purchaseCount = 0,
  }) : photoUrls = photoUrls ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'listId': listId,
        'name': name,
        'quantity': quantity,
        'unit': unit,
        'addedBy': addedBy,
        'notes': notes,
        'photoUrls': photoUrls,
        'categoryId': categoryId,
        'categoryName': categoryName,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'completedBy': completedBy,
        'completedAt': completedAt?.toIso8601String(),
        'price': price,
        'isRecurring': isRecurring,
        'purchaseCount': purchaseCount,
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
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

    return ShoppingItem(
      id: json['id'] as String? ?? '',
      listId: json['listId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      quantity: json['quantity'] as int? ?? 1,
      unit: json['unit'] as String?,
      addedBy: json['addedBy'] as String? ?? '',
      notes: json['notes'] as String?,
      photoUrls: (json['photoUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      categoryId: json['categoryId'] as String?,
      categoryName: json['categoryName'] as String?,
      status: ShoppingItemStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ShoppingItemStatus.pending,
      ),
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseOptionalDateTime(json['updatedAt']),
      completedBy: json['completedBy'] as String?,
      completedAt: parseOptionalDateTime(json['completedAt']),
      price: json['price'] != null 
          ? (json['price'] is num ? (json['price'] as num).toDouble() : null)
          : null,
      isRecurring: json['isRecurring'] as bool? ?? false,
      purchaseCount: json['purchaseCount'] as int? ?? 0,
    );
  }

  ShoppingItem copyWith({
    String? id,
    String? listId,
    String? name,
    int? quantity,
    String? unit,
    String? addedBy,
    String? notes,
    List<String>? photoUrls,
    String? categoryId,
    String? categoryName,
    ShoppingItemStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? completedBy,
    DateTime? completedAt,
    double? price,
    bool? isRecurring,
    int? purchaseCount,
  }) =>
      ShoppingItem(
        id: id ?? this.id,
        listId: listId ?? this.listId,
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        unit: unit ?? this.unit,
        addedBy: addedBy ?? this.addedBy,
        notes: notes ?? this.notes,
        photoUrls: photoUrls ?? this.photoUrls,
        categoryId: categoryId ?? this.categoryId,
        categoryName: categoryName ?? this.categoryName,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        completedBy: completedBy ?? this.completedBy,
        completedAt: completedAt ?? this.completedAt,
        price: price ?? this.price,
        isRecurring: isRecurring ?? this.isRecurring,
        purchaseCount: purchaseCount ?? this.purchaseCount,
      );

  /// Whether this item has been actioned (not pending)
  bool get isActioned => status != ShoppingItemStatus.pending;
  
  /// Whether this item was successfully purchased
  bool get isPurchased => status == ShoppingItemStatus.gotIt;
  
  /// Display string for quantity with unit
  String get quantityDisplay {
    if (unit != null && unit!.isNotEmpty) {
      return '$quantity $unit';
    }
    return quantity.toString();
  }
}
