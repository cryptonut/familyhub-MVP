import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/phone_number_utils.dart';

/// SMS message model
class SmsMessage {
  final String id;
  final String phoneNumber;
  final String? normalizedPhoneNumber;
  final String? contactName;
  final String content;
  final DateTime timestamp;
  final bool isSent; // true for sent, false for received
  final bool isRead;
  final String threadId; // Phone number used as thread ID
  final String? firestoreId; // For metadata sync

  SmsMessage({
    required this.id,
    required this.phoneNumber,
    String? normalizedPhoneNumber,
    this.contactName,
    required this.content,
    required this.timestamp,
    required this.isSent,
    this.isRead = false,
    String? threadId,
    this.firestoreId,
  }) : normalizedPhoneNumber = normalizedPhoneNumber ?? PhoneNumberUtils.normalizePhoneNumber(phoneNumber),
       threadId = threadId ?? PhoneNumberUtils.normalizePhoneNumber(phoneNumber) ?? phoneNumber;

  Map<String, dynamic> toJson() => {
        'id': id,
        'phoneNumber': phoneNumber,
        if (normalizedPhoneNumber != null) 'normalizedPhoneNumber': normalizedPhoneNumber,
        if (contactName != null) 'contactName': contactName,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
        'isSent': isSent,
        'isRead': isRead,
        'threadId': threadId,
        if (firestoreId != null) 'firestoreId': firestoreId,
      };

  factory SmsMessage.fromJson(Map<String, dynamic> json) {
    DateTime timestamp = DateTime.now();
    if (json['timestamp'] != null) {
      final value = json['timestamp'];
      if (value is Timestamp) {
        timestamp = value.toDate();
      } else if (value is String) {
        timestamp = DateTime.parse(value);
      }
    }

    return SmsMessage(
      id: json['id'] as String,
      phoneNumber: json['phoneNumber'] as String,
      normalizedPhoneNumber: json['normalizedPhoneNumber'] as String?,
      contactName: json['contactName'] as String?,
      content: json['content'] as String,
      timestamp: timestamp,
      isSent: json['isSent'] as bool? ?? false,
      isRead: json['isRead'] as bool? ?? false,
      threadId: json['threadId'] as String?,
      firestoreId: json['firestoreId'] as String?,
    );
  }

  SmsMessage copyWith({
    String? id,
    String? phoneNumber,
    String? normalizedPhoneNumber,
    String? contactName,
    String? content,
    DateTime? timestamp,
    bool? isSent,
    bool? isRead,
    String? threadId,
    String? firestoreId,
  }) {
    return SmsMessage(
      id: id ?? this.id,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      normalizedPhoneNumber: normalizedPhoneNumber ?? this.normalizedPhoneNumber,
      contactName: contactName ?? this.contactName,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      isSent: isSent ?? this.isSent,
      isRead: isRead ?? this.isRead,
      threadId: threadId ?? this.threadId,
      firestoreId: firestoreId ?? this.firestoreId,
    );
  }
}
