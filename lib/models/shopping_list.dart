class ShoppingList {
  final String id;
  final String name;
  final String? description;
  final String creatorId;
  final List<String> sharedWith;
  final bool isDefault;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int itemCount;
  final int completedItemCount;
  final bool isArchived;

  ShoppingList({
    required this.id,
    required this.name,
    this.description,
    required this.creatorId,
    this.sharedWith = const [],
    this.isDefault = false,
    required this.createdAt,
    this.updatedAt,
    this.itemCount = 0,
    this.completedItemCount = 0,
    this.isArchived = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'creatorId': creatorId,
        'sharedWith': sharedWith,
        'isDefault': isDefault,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
        'itemCount': itemCount,
        'completedItemCount': completedItemCount,
        'isArchived': isArchived,
      };

  factory ShoppingList.fromJson(Map<String, dynamic> json) {
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

      // Handle sharedWith - might be List or null
      List<String> sharedWith = [];
      if (json['sharedWith'] != null) {
        if (json['sharedWith'] is List) {
          sharedWith = (json['sharedWith'] as List).map((e) => e.toString()).toList();
        }
      }

      return ShoppingList(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        creatorId: json['creatorId'] as String? ?? '',
        sharedWith: sharedWith,
        isDefault: json['isDefault'] as bool? ?? false,
        createdAt: createdAt,
        updatedAt: json['updatedAt'] != null
            ? (json['updatedAt'] is String
                ? DateTime.parse(json['updatedAt'] as String)
                : json['updatedAt'] as DateTime)
            : null,
        itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
        completedItemCount: (json['completedItemCount'] as num?)?.toInt() ?? 0,
        isArchived: json['isArchived'] as bool? ?? false,
      );
    } catch (e, st) {
      throw FormatException('Error parsing ShoppingList: $e', st);
    }
  }

  ShoppingList copyWith({
    String? id,
    String? name,
    String? description,
    String? creatorId,
    List<String>? sharedWith,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? itemCount,
    int? completedItemCount,
    bool? isArchived,
  }) {
    return ShoppingList(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      creatorId: creatorId ?? this.creatorId,
      sharedWith: sharedWith ?? this.sharedWith,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      itemCount: itemCount ?? this.itemCount,
      completedItemCount: completedItemCount ?? this.completedItemCount,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  double get progress => itemCount > 0 ? completedItemCount / itemCount : 0.0;
  bool get isCompleted => itemCount > 0 && completedItemCount >= itemCount;
}

