/// Model for privacy activity log entries
class PrivacyActivity {
  final String id;
  final String userId;
  final String action; // 'enabled', 'disabled', 'paused', 'stopped'
  final String shareType; // 'location', 'calendar', 'birthday', 'geofence'
  final DateTime timestamp;
  final String? description;

  PrivacyActivity({
    required this.id,
    required this.userId,
    required this.action,
    required this.shareType,
    required this.timestamp,
    this.description,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'action': action,
        'shareType': shareType,
        'timestamp': timestamp.toIso8601String(),
        if (description != null) 'description': description,
      };

  factory PrivacyActivity.fromJson(Map<String, dynamic> json) => PrivacyActivity(
        id: json['id'] as String,
        userId: json['userId'] as String,
        action: json['action'] as String,
        shareType: json['shareType'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        description: json['description'] as String?,
      );
}

