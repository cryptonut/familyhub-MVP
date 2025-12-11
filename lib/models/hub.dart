enum HubType {
  family,
  extendedFamily,
  homeschooling,
  coparenting,
}

class Hub {
  final String id;
  final String name;
  final String description;
  final String creatorId;
  final List<String> memberIds;
  final DateTime createdAt;
  final String? icon; // Optional icon identifier
  final bool videoCallsEnabled; // Whether video calls are enabled in this hub
  final HubType type;
  final Map<String, dynamic> typeSpecificData;

  Hub({
    required this.id,
    required this.name,
    required this.description,
    required this.creatorId,
    this.memberIds = const [],
    required this.createdAt,
    this.icon,
    bool? videoCallsEnabled,
    this.type = HubType.family,
    this.typeSpecificData = const {},
  }) : videoCallsEnabled = videoCallsEnabled ?? true; // Default true for family hubs

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'creatorId': creatorId,
        'memberIds': memberIds,
        'createdAt': createdAt.toIso8601String(),
        'icon': icon,
        'videoCallsEnabled': videoCallsEnabled,
        'type': type.toString().split('.').last,
        'typeSpecificData': typeSpecificData,
      };

  factory Hub.fromJson(Map<String, dynamic> json) => Hub(
        id: json['id'] as String,
        name: json['name'] as String,
        description: json['description'] as String,
        creatorId: json['creatorId'] as String,
        memberIds: List<String>.from(json['memberIds'] as List? ?? []),
        createdAt: DateTime.parse(json['createdAt'] as String),
        icon: json['icon'] as String?,
        videoCallsEnabled: json['videoCallsEnabled'] as bool? ?? true,
        type: HubType.values.firstWhere(
          (e) => e.toString().split('.').last == json['type'],
          orElse: () => HubType.family,
        ),
        typeSpecificData: json['typeSpecificData'] as Map<String, dynamic>? ?? {},
      );

  Hub copyWith({
    String? id,
    String? name,
    String? description,
    String? creatorId,
    List<String>? memberIds,
    DateTime? createdAt,
    String? icon,
    bool? videoCallsEnabled,
    HubType? type,
    Map<String, dynamic>? typeSpecificData,
  }) =>
      Hub(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        creatorId: creatorId ?? this.creatorId,
        memberIds: memberIds ?? this.memberIds,
        createdAt: createdAt ?? this.createdAt,
        icon: icon ?? this.icon,
        videoCallsEnabled: videoCallsEnabled ?? this.videoCallsEnabled,
        type: type ?? this.type,
        typeSpecificData: typeSpecificData ?? this.typeSpecificData,
      );
}
