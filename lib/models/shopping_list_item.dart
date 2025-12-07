import 'package:cloud_firestore/cloud_firestore.dart';

enum ItemStatus {
  pending,
  gotIt,
  unavailable,
  cancelled,
}

class ShoppingListItem {
  final String id;
  final String listId;
  final String name;
  final int quantity;
  final String? notes;
  final String? category;
  final String addedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final ItemStatus status;
  final List<String> attachmentUrls; // Photo URLs
  final int? orderIndex; // For drag-to-reorder

  ShoppingListItem({
    required this.id,
    required this.listId,
    required this.name,
    this.quantity = 1,
    this.notes,
    this.category,
    required this.addedBy,
    required this.createdAt,
    this.updatedAt,
    this.status = ItemStatus.pending,
    List<String>? attachmentUrls,
    this.orderIndex,
  }) : attachmentUrls = attachmentUrls ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'listId': listId,
        'name': name,
        'quantity': quantity,
        'notes': notes,
        'category': category,
        'addedBy': addedBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'status': status.name,
        'attachmentUrls': attachmentUrls,
        'orderIndex': orderIndex,
      };

  factory ShoppingListItem.fromJson(Map<String, dynamic> json) {
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

    return ShoppingListItem(
      id: json['id'] as String? ?? '',
      listId: json['listId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      notes: json['notes'] as String?,
      category: json['category'] as String?,
      addedBy: json['addedBy'] as String? ?? '',
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: json['updatedAt'] != null ? parseDateTime(json['updatedAt']) : null,
      status: json['status'] != null
          ? ItemStatus.values.firstWhere(
              (e) => e.name == json['status'],
              orElse: () => ItemStatus.pending,
            )
          : ItemStatus.pending,
      attachmentUrls: (json['attachmentUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      orderIndex: (json['orderIndex'] as num?)?.toInt(),
    );
  }

  ShoppingListItem copyWith({
    String? id,
    String? listId,
    String? name,
    int? quantity,
    String? notes,
    String? category,
    String? addedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    ItemStatus? status,
    List<String>? attachmentUrls,
    int? orderIndex,
  }) =>
      ShoppingListItem(
        id: id ?? this.id,
        listId: listId ?? this.listId,
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        notes: notes ?? this.notes,
        category: category ?? this.category,
        addedBy: addedBy ?? this.addedBy,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        status: status ?? this.status,
        attachmentUrls: attachmentUrls ?? this.attachmentUrls,
        orderIndex: orderIndex ?? this.orderIndex,
      );

  bool get isCompleted => status == ItemStatus.gotIt;
  bool get isPending => status == ItemStatus.pending;
}
