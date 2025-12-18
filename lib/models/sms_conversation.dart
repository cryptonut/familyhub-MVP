import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/phone_number_utils.dart';

/// SMS conversation model
class SmsConversation {
  final String phoneNumber;
  final String normalizedPhoneNumber;
  final String? contactName;
  final String? contactPhotoUrl;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final String threadId;
  final bool isAppUser;
  final String? appUserId;
  final int messageCount;
  final DateTime? lastSyncedAt;

  SmsConversation({
    required this.phoneNumber,
    String? normalizedPhoneNumber,
    this.contactName,
    this.contactPhotoUrl,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    String? threadId,
    this.isAppUser = false,
    this.appUserId,
    this.messageCount = 0,
    this.lastSyncedAt,
  }) : normalizedPhoneNumber = normalizedPhoneNumber ?? PhoneNumberUtils.normalizePhoneNumber(phoneNumber) ?? phoneNumber,
       threadId = threadId ?? PhoneNumberUtils.normalizePhoneNumber(phoneNumber) ?? phoneNumber;

  Map<String, dynamic> toJson() => {
        'phoneNumber': phoneNumber,
        'normalizedPhoneNumber': normalizedPhoneNumber,
        if (contactName != null) 'contactName': contactName,
        if (contactPhotoUrl != null) 'contactPhotoUrl': contactPhotoUrl,
        if (lastMessage != null) 'lastMessage': lastMessage,
        if (lastMessageTime != null) 'lastMessageTime': lastMessageTime!.toIso8601String(),
        'unreadCount': unreadCount,
        'threadId': threadId,
        'isAppUser': isAppUser,
        if (appUserId != null) 'appUserId': appUserId,
        'messageCount': messageCount,
        if (lastSyncedAt != null) 'lastSyncedAt': lastSyncedAt!.toIso8601String(),
      };

  factory SmsConversation.fromJson(Map<String, dynamic> json) {
    DateTime? lastMessageTime;
    if (json['lastMessageTime'] != null) {
      final value = json['lastMessageTime'];
      if (value is Timestamp) {
        lastMessageTime = value.toDate();
      } else if (value is String) {
        lastMessageTime = DateTime.parse(value);
      }
    }

    DateTime? lastSyncedAt;
    if (json['lastSyncedAt'] != null) {
      final value = json['lastSyncedAt'];
      if (value is Timestamp) {
        lastSyncedAt = value.toDate();
      } else if (value is String) {
        lastSyncedAt = DateTime.parse(value);
      }
    }

    return SmsConversation(
      phoneNumber: json['phoneNumber'] as String,
      normalizedPhoneNumber: json['normalizedPhoneNumber'] as String?,
      contactName: json['contactName'] as String?,
      contactPhotoUrl: json['contactPhotoUrl'] as String?,
      lastMessage: json['lastMessage'] as String?,
      lastMessageTime: lastMessageTime,
      unreadCount: json['unreadCount'] as int? ?? 0,
      threadId: json['threadId'] as String?,
      isAppUser: json['isAppUser'] as bool? ?? false,
      appUserId: json['appUserId'] as String?,
      messageCount: json['messageCount'] as int? ?? 0,
      lastSyncedAt: lastSyncedAt,
    );
  }

  SmsConversation copyWith({
    String? phoneNumber,
    String? normalizedPhoneNumber,
    String? contactName,
    String? contactPhotoUrl,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    String? threadId,
    bool? isAppUser,
    String? appUserId,
    int? messageCount,
    DateTime? lastSyncedAt,
  }) {
    return SmsConversation(
      phoneNumber: phoneNumber ?? this.phoneNumber,
      normalizedPhoneNumber: normalizedPhoneNumber ?? this.normalizedPhoneNumber,
      contactName: contactName ?? this.contactName,
      contactPhotoUrl: contactPhotoUrl ?? this.contactPhotoUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      threadId: threadId ?? this.threadId,
      isAppUser: isAppUser ?? this.isAppUser,
      appUserId: appUserId ?? this.appUserId,
      messageCount: messageCount ?? this.messageCount,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    );
  }
}

