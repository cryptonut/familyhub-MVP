import '../utils/phone_number_utils.dart';

/// SMS contact model
class SmsContact {
  final String phoneNumber;
  final String normalizedPhoneNumber;
  final String displayName;
  final String? photoUrl;
  final bool isAppUser;
  final String? appUserId;
  final DateTime? lastSyncedAt;
  final String? contactId; // Device contact ID

  SmsContact({
    required this.phoneNumber,
    String? normalizedPhoneNumber,
    required this.displayName,
    this.photoUrl,
    this.isAppUser = false,
    this.appUserId,
    this.lastSyncedAt,
    this.contactId,
  }) : normalizedPhoneNumber = normalizedPhoneNumber ?? PhoneNumberUtils.normalizePhoneNumber(phoneNumber) ?? phoneNumber;

  Map<String, dynamic> toJson() => {
        'phoneNumber': phoneNumber,
        'normalizedPhoneNumber': normalizedPhoneNumber,
        'displayName': displayName,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'isAppUser': isAppUser,
        if (appUserId != null) 'appUserId': appUserId,
        if (lastSyncedAt != null) 'lastSyncedAt': lastSyncedAt!.toIso8601String(),
        if (contactId != null) 'contactId': contactId,
      };

  factory SmsContact.fromJson(Map<String, dynamic> json) {
    DateTime? lastSyncedAt;
    if (json['lastSyncedAt'] != null) {
      final value = json['lastSyncedAt'];
      if (value is String) {
        lastSyncedAt = DateTime.parse(value);
      }
    }

    return SmsContact(
      phoneNumber: json['phoneNumber'] as String,
      normalizedPhoneNumber: json['normalizedPhoneNumber'] as String?,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      isAppUser: json['isAppUser'] as bool? ?? false,
      appUserId: json['appUserId'] as String?,
      lastSyncedAt: lastSyncedAt,
      contactId: json['contactId'] as String?,
    );
  }

  SmsContact copyWith({
    String? phoneNumber,
    String? normalizedPhoneNumber,
    String? displayName,
    String? photoUrl,
    bool? isAppUser,
    String? appUserId,
    DateTime? lastSyncedAt,
    String? contactId,
  }) {
    return SmsContact(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      normalizedPhoneNumber: normalizedPhoneNumber ?? this.normalizedPhoneNumber,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      isAppUser: isAppUser ?? this.isAppUser,
      appUserId: appUserId ?? this.appUserId,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      contactId: contactId ?? this.contactId,
    );
  }
}

