class UserModel {
  final String uid;
  final String email;
  final String displayName;
  final String? photoUrl;
  final DateTime createdAt;
  final String? familyId;
  final List<String> roles; // e.g., ['admin', 'banker', 'approver']
  final String? relationship; // Relationship from family creator's perspective (e.g., 'father', 'mother', 'daughter', 'son')

  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    this.photoUrl,
    required this.createdAt,
    this.familyId,
    List<String>? roles,
    this.relationship,
  }) : roles = roles ?? [];

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'email': email,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'createdAt': createdAt.toIso8601String(),
        'familyId': familyId,
        'roles': roles,
        if (relationship != null) 'relationship': relationship,
      };

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Handle roles - could be List or missing
    List<String> roles = [];
    if (json['roles'] != null) {
      if (json['roles'] is List) {
        roles = (json['roles'] as List).map((e) => e.toString()).toList();
      }
    }
    
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      familyId: json['familyId'] as String?,
      roles: roles,
      relationship: json['relationship'] as String?,
    );
  }

  UserModel copyWith({
    String? uid,
    String? email,
    String? displayName,
    String? photoUrl,
    DateTime? createdAt,
    String? familyId,
    List<String>? roles,
    String? relationship,
  }) =>
      UserModel(
        uid: uid ?? this.uid,
        email: email ?? this.email,
        displayName: displayName ?? this.displayName,
        photoUrl: photoUrl ?? this.photoUrl,
        createdAt: createdAt ?? this.createdAt,
        familyId: familyId ?? this.familyId,
        roles: roles ?? this.roles,
        relationship: relationship ?? this.relationship,
      );
  
  // Helper methods for role checking
  bool hasRole(String role) => roles.contains(role.toLowerCase());
  bool isAdmin() => hasRole('admin');
  bool isBanker() => hasRole('banker');
  bool isApprover() => hasRole('approver');
}

