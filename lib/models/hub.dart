/// Hub types supported by the app
enum HubType {
  family,           // Core family hub (free)
  extendedFamily,   // Extended family hub (premium)
  homeschooling,    // Homeschooling hub (premium)
  coparenting,      // Co-parenting hub (premium)
}

extension HubTypeExtension on HubType {
  String get value {
    switch (this) {
      case HubType.family:
        return 'family';
      case HubType.extendedFamily:
        return 'extended_family';
      case HubType.homeschooling:
        return 'homeschooling';
      case HubType.coparenting:
        return 'coparenting';
    }
  }

  static HubType fromString(String value) {
    switch (value) {
      case 'family':
        return HubType.family;
      case 'extended_family':
        return HubType.extendedFamily;
      case 'homeschooling':
        return HubType.homeschooling;
      case 'coparenting':
        return HubType.coparenting;
      default:
        return HubType.family;
    }
  }
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
  final HubType hubType; // Type of hub (family, extended_family, etc.)
  final Map<String, dynamic>? typeSpecificData; // Hub type-specific configuration

  Hub({
    required this.id,
    required this.name,
    required this.description,
    required this.creatorId,
    this.memberIds = const [],
    required this.createdAt,
    this.icon,
    bool? videoCallsEnabled,
    HubType? hubType,
    this.typeSpecificData,
  })  : videoCallsEnabled = videoCallsEnabled ?? true, // Default true for family hubs
        hubType = hubType ?? HubType.family; // Default to family hub

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'creatorId': creatorId,
        'memberIds': memberIds,
        'createdAt': createdAt.toIso8601String(),
        'icon': icon,
        'videoCallsEnabled': videoCallsEnabled,
        'hubType': hubType.value,
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
        hubType: json['hubType'] != null
            ? HubTypeExtension.fromString(json['hubType'] as String)
            : HubType.family,
        typeSpecificData: json['typeSpecificData'] != null
            ? Map<String, dynamic>.from(json['typeSpecificData'] as Map)
            : null,
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
    HubType? hubType,
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
        hubType: hubType ?? this.hubType,
        typeSpecificData: typeSpecificData ?? this.typeSpecificData,
      );
  
  /// Check if this is a premium hub type
  bool get isPremiumHub => hubType != HubType.family;
  
  /// Check if this is an extended family hub
  bool get isExtendedFamilyHub => hubType == HubType.extendedFamily;
}

