class HubInvite {
  final String id;
  final String hubId;
  final String hubName;
  final String inviterId;
  final String inviterName;
  final String? email;
  final String? phoneNumber;
  final String? userId; // If inviting an existing user
  final String status; // 'pending', 'accepted', 'declined'
  final DateTime createdAt;
  final DateTime? expiresAt;

  HubInvite({
    required this.id,
    required this.hubId,
    required this.hubName,
    required this.inviterId,
    required this.inviterName,
    this.email,
    this.phoneNumber,
    this.userId,
    this.status = 'pending',
    required this.createdAt,
    this.expiresAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'hubId': hubId,
        'hubName': hubName,
        'inviterId': inviterId,
        'inviterName': inviterName,
        'email': email,
        'phoneNumber': phoneNumber,
        'userId': userId,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
      };

  factory HubInvite.fromJson(Map<String, dynamic> json) => HubInvite(
        id: json['id'] as String,
        hubId: json['hubId'] as String,
        hubName: json['hubName'] as String,
        inviterId: json['inviterId'] as String,
        inviterName: json['inviterName'] as String,
        email: json['email'] as String?,
        phoneNumber: json['phoneNumber'] as String?,
        userId: json['userId'] as String?,
        status: json['status'] as String? ?? 'pending',
        createdAt: DateTime.parse(json['createdAt'] as String),
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'] as String)
            : null,
      );

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }
}

