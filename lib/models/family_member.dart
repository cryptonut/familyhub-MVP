class FamilyMember {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatarUrl;
  final double? latitude;
  final double? longitude;
  final DateTime? lastSeen;

  FamilyMember({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatarUrl,
    this.latitude,
    this.longitude,
    this.lastSeen,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'avatarUrl': avatarUrl,
        'latitude': latitude,
        'longitude': longitude,
        'lastSeen': lastSeen?.toIso8601String(),
      };

  factory FamilyMember.fromJson(Map<String, dynamic> json) => FamilyMember(
        id: json['id'] as String,
        name: json['name'] as String,
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        avatarUrl: json['avatarUrl'] as String?,
        latitude: json['latitude'] as double?,
        longitude: json['longitude'] as double?,
        lastSeen: json['lastSeen'] != null
            ? DateTime.parse(json['lastSeen'] as String)
            : null,
      );

  FamilyMember copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatarUrl,
    double? latitude,
    double? longitude,
    DateTime? lastSeen,
  }) =>
      FamilyMember(
        id: id ?? this.id,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        lastSeen: lastSeen ?? this.lastSeen,
      );
}

