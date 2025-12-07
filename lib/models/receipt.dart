import 'package:cloud_firestore/cloud_firestore.dart';

class ReceiptItem {
  final String name;
  final int quantity;
  final double price;
  final String? category;

  ReceiptItem({
    required this.name,
    required this.quantity,
    required this.price,
    this.category,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'price': price,
        'category': category,
      };

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
        name: json['name'] as String? ?? '',
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        category: json['category'] as String?,
      );

  double get total => quantity * price;
}

class Receipt {
  final String id;
  final String listId;
  final String familyId;
  final String store;
  final DateTime date;
  final List<ReceiptItem> items;
  final double total;
  final String? imageUrl;
  final String uploadedBy;
  final DateTime uploadedAt;
  final DateTime? editedAt;
  final bool isEdited; // Whether user manually edited OCR results

  Receipt({
    required this.id,
    required this.listId,
    required this.familyId,
    required this.store,
    required this.date,
    required this.items,
    required this.total,
    this.imageUrl,
    required this.uploadedBy,
    required this.uploadedAt,
    this.editedAt,
    this.isEdited = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'listId': listId,
        'familyId': familyId,
        'store': store,
        'date': date.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
        'total': total,
        'imageUrl': imageUrl,
        'uploadedBy': uploadedBy,
        'uploadedAt': uploadedAt.toIso8601String(),
        'editedAt': editedAt?.toIso8601String(),
        'isEdited': isEdited,
      };

  factory Receipt.fromJson(Map<String, dynamic> json) {
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

    return Receipt(
      id: json['id'] as String? ?? '',
      listId: json['listId'] as String? ?? '',
      familyId: json['familyId'] as String? ?? '',
      store: json['store'] as String? ?? 'Unknown Store',
      date: parseDateTime(json['date']),
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => ReceiptItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl'] as String?,
      uploadedBy: json['uploadedBy'] as String? ?? '',
      uploadedAt: parseDateTime(json['uploadedAt']),
      editedAt: json['editedAt'] != null ? parseDateTime(json['editedAt']) : null,
      isEdited: json['isEdited'] == true,
    );
  }

  Receipt copyWith({
    String? id,
    String? listId,
    String? familyId,
    String? store,
    DateTime? date,
    List<ReceiptItem>? items,
    double? total,
    String? imageUrl,
    String? uploadedBy,
    DateTime? uploadedAt,
    DateTime? editedAt,
    bool? isEdited,
  }) =>
      Receipt(
        id: id ?? this.id,
        listId: listId ?? this.listId,
        familyId: familyId ?? this.familyId,
        store: store ?? this.store,
        date: date ?? this.date,
        items: items ?? this.items,
        total: total ?? this.total,
        imageUrl: imageUrl ?? this.imageUrl,
        uploadedBy: uploadedBy ?? this.uploadedBy,
        uploadedAt: uploadedAt ?? this.uploadedAt,
        editedAt: editedAt ?? this.editedAt,
        isEdited: isEdited ?? this.isEdited,
      );
}
