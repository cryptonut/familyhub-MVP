class Hub {
  final String id;
  final String name;
  final String description;
  final String creatorId;
  final List<String> memberIds;
  final DateTime createdAt;
  final String? icon; // Optional icon identifier

  Hub({
    required this.id,
    required this.name,
    required this.description,
    required this.creatorId,
    this.memberIds = const [],
    required this.createdAt,
    this.icon,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'creatorId': creatorId,
        'memberIds': memberIds,
        'createdAt': createdAt.toIso8601String(),
        'icon': icon,
      };

  factory Hub.fromJson(Map<String, dynamic> json) => Hub(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        creatorId: json['creatorId'] as String,
        memberIds: List<String>.from(json['memberIds'] as List? ?? []),
        createdAt: DateTime.parse(json['createdAt'] as String),
        icon: json['icon'] as String?,
      );

  Hub copyWith({
    String? id,
    String? name,
    String? description,
    String? creatorId,
    List<String>? memberIds,
    DateTime? createdAt,
    String? icon,
  }) =>
      Hub(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        creatorId: creatorId ?? this.creatorId,
        memberIds: memberIds ?? this.memberIds,
        createdAt: createdAt ?? this.createdAt,
        icon: icon ?? this.icon,
      );
}

