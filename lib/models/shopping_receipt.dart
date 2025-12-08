import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an item extracted from a receipt
class ReceiptItem {
  final String name;
  final int quantity;
  final double price;
  final double? unitPrice;

  ReceiptItem({
    required this.name,
    this.quantity = 1,
    required this.price,
    this.unitPrice,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'price': price,
        'unitPrice': unitPrice,
      };

  factory ReceiptItem.fromJson(Map<String, dynamic> json) => ReceiptItem(
        name: json['name'] as String? ?? '',
        quantity: json['quantity'] as int? ?? 1,
        price: (json['price'] as num?)?.toDouble() ?? 0.0,
        unitPrice: (json['unitPrice'] as num?)?.toDouble(),
      );

  ReceiptItem copyWith({
    String? name,
    int? quantity,
    double? price,
    double? unitPrice,
  }) =>
      ReceiptItem(
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        price: price ?? this.price,
        unitPrice: unitPrice ?? this.unitPrice,
      );
}

/// Represents a shopping receipt with OCR-extracted data
class ShoppingReceipt {
  final String id;
  final String? listId; // Optional link to a shopping list
  final String imageUrl; // Original receipt image
  final String? storeName;
  final String? storeAddress;
  final DateTime? purchaseDate;
  final List<ReceiptItem> items;
  final double? subtotal;
  final double? tax;
  final double? total;
  final String? paymentMethod;
  final String uploadedBy; // User ID who uploaded
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isProcessed; // Whether OCR has been run
  final bool isVerified; // Whether user has verified/corrected the data
  final String? rawOcrText; // Raw OCR output for debugging

  ShoppingReceipt({
    required this.id,
    this.listId,
    required this.imageUrl,
    this.storeName,
    this.storeAddress,
    this.purchaseDate,
    List<ReceiptItem>? items,
    this.subtotal,
    this.tax,
    this.total,
    this.paymentMethod,
    required this.uploadedBy,
    required this.createdAt,
    this.updatedAt,
    this.isProcessed = false,
    this.isVerified = false,
    this.rawOcrText,
  }) : items = items ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'listId': listId,
        'imageUrl': imageUrl,
        'storeName': storeName,
        'storeAddress': storeAddress,
        'purchaseDate': purchaseDate?.toIso8601String(),
        'items': items.map((item) => item.toJson()).toList(),
        'subtotal': subtotal,
        'tax': tax,
        'total': total,
        'paymentMethod': paymentMethod,
        'uploadedBy': uploadedBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'isProcessed': isProcessed,
        'isVerified': isVerified,
        'rawOcrText': rawOcrText,
      };

  factory ShoppingReceipt.fromJson(Map<String, dynamic> json) {
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

    return ShoppingReceipt(
      id: json['id'] as String? ?? '',
      listId: json['listId'] as String?,
      imageUrl: json['imageUrl'] as String? ?? '',
      storeName: json['storeName'] as String?,
      storeAddress: json['storeAddress'] as String?,
      purchaseDate: parseOptionalDateTime(json['purchaseDate']),
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => ReceiptItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      subtotal: (json['subtotal'] as num?)?.toDouble(),
      tax: (json['tax'] as num?)?.toDouble(),
      total: (json['total'] as num?)?.toDouble(),
      paymentMethod: json['paymentMethod'] as String?,
      uploadedBy: json['uploadedBy'] as String? ?? '',
      createdAt: parseDateTime(json['createdAt']),
      updatedAt: parseOptionalDateTime(json['updatedAt']),
      isProcessed: json['isProcessed'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? false,
      rawOcrText: json['rawOcrText'] as String?,
    );
  }

  ShoppingReceipt copyWith({
    String? id,
    String? listId,
    String? imageUrl,
    String? storeName,
    String? storeAddress,
    DateTime? purchaseDate,
    List<ReceiptItem>? items,
    double? subtotal,
    double? tax,
    double? total,
    String? paymentMethod,
    String? uploadedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isProcessed,
    bool? isVerified,
    String? rawOcrText,
  }) =>
      ShoppingReceipt(
        id: id ?? this.id,
        listId: listId ?? this.listId,
        imageUrl: imageUrl ?? this.imageUrl,
        storeName: storeName ?? this.storeName,
        storeAddress: storeAddress ?? this.storeAddress,
        purchaseDate: purchaseDate ?? this.purchaseDate,
        items: items ?? this.items,
        subtotal: subtotal ?? this.subtotal,
        tax: tax ?? this.tax,
        total: total ?? this.total,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        uploadedBy: uploadedBy ?? this.uploadedBy,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isProcessed: isProcessed ?? this.isProcessed,
        isVerified: isVerified ?? this.isVerified,
        rawOcrText: rawOcrText ?? this.rawOcrText,
      );

  /// Total number of items on the receipt
  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
  
  /// Calculated total from items (may differ from receipt total due to rounding)
  double get calculatedTotal => items.fold(0.0, (sum, item) => sum + item.price);
}
