class ReceiptItem {
  final String name;
  final int quantity;
  final double? price;

  ReceiptItem({
    required this.name,
    required this.quantity,
    this.price,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'price': price,
      };

  factory ReceiptItem.fromJson(Map<String, dynamic> json) {
    return ReceiptItem(
      name: json['name'] as String? ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      price: (json['price'] as num?)?.toDouble(),
    );
  }
}

class ShoppingReceipt {
  final String id;
  final String? listId;
  final String imageUrl;
  final String uploadedBy;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isProcessed;
  final Map<String, dynamic>? ocrData;
  final double? totalAmount;
  final bool? isVerified;
  final DateTime? purchaseDate;
  final String? storeName;
  final List<ReceiptItem>? items;

  ShoppingReceipt({
    required this.id,
    this.listId,
    required this.imageUrl,
    required this.uploadedBy,
    required this.createdAt,
    this.updatedAt,
    this.isProcessed = false,
    this.ocrData,
    this.totalAmount,
    this.isVerified,
    this.purchaseDate,
    this.storeName,
    this.items,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'listId': listId,
        'imageUrl': imageUrl,
        'uploadedBy': uploadedBy,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'isProcessed': isProcessed,
        'ocrData': ocrData,
        'totalAmount': totalAmount,
        'isVerified': isVerified,
        'purchaseDate': purchaseDate?.toIso8601String(),
        'storeName': storeName,
        'items': items?.map((item) => item.toJson()).toList(),
      };

  factory ShoppingReceipt.fromJson(Map<String, dynamic> json) {
    try {
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

      return ShoppingReceipt(
        id: json['id'] as String? ?? '',
        listId: json['listId'] as String?,
        imageUrl: json['imageUrl'] as String? ?? '',
        uploadedBy: json['uploadedBy'] as String? ?? '',
        createdAt: createdAt,
        updatedAt: json['updatedAt'] != null
            ? (json['updatedAt'] is String
                ? DateTime.parse(json['updatedAt'] as String)
                : json['updatedAt'] as DateTime)
            : null,
        isProcessed: json['isProcessed'] as bool? ?? false,
        ocrData: json['ocrData'] as Map<String, dynamic>?,
        totalAmount: (json['totalAmount'] as num?)?.toDouble(),
        isVerified: json['isVerified'] as bool?,
        purchaseDate: json['purchaseDate'] != null
            ? (json['purchaseDate'] is String
                ? DateTime.parse(json['purchaseDate'] as String)
                : json['purchaseDate'] as DateTime)
            : null,
        storeName: json['storeName'] as String?,
        items: json['items'] != null
            ? (json['items'] as List)
                .map((item) => ReceiptItem.fromJson(item as Map<String, dynamic>))
                .toList()
            : null,
      );
    } catch (e, st) {
      throw FormatException('Error parsing ShoppingReceipt: $e', st);
    }
  }

  ShoppingReceipt copyWith({
    String? id,
    String? listId,
    String? imageUrl,
    String? uploadedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isProcessed,
    Map<String, dynamic>? ocrData,
    double? totalAmount,
    bool? isVerified,
    DateTime? purchaseDate,
    String? storeName,
    List<ReceiptItem>? items,
  }) {
    return ShoppingReceipt(
      id: id ?? this.id,
      listId: listId ?? this.listId,
      imageUrl: imageUrl ?? this.imageUrl,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isProcessed: isProcessed ?? this.isProcessed,
      ocrData: ocrData ?? this.ocrData,
      totalAmount: totalAmount ?? this.totalAmount,
      isVerified: isVerified ?? this.isVerified,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      storeName: storeName ?? this.storeName,
      items: items ?? this.items,
    );
  }

  double? get total => totalAmount;
}

