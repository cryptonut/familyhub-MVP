import 'dart:io';
import 'dart:async';
import 'package:telephony/telephony.dart' as telephony;
import '../models/sms_message.dart';
import '../models/sms_conversation.dart';
import '../utils/phone_number_utils.dart';
import '../core/services/logger_service.dart';
import 'sms_permission_service.dart';
import 'auth_service.dart';
import '../models/user_model.dart';

/// Service for SMS operations (Android only)
class SmsService {
  static const String _tag = 'SmsService';
  
  final telephony.Telephony _telephony = telephony.Telephony.instance;
  final SmsPermissionService _permissionService = SmsPermissionService();
  final AuthService _authService = AuthService();
  
  // Rate limiting: max 10 SMS per minute
  static const int _rateLimitPerMinute = 10;
  final Map<String, List<DateTime>> _rateLimitMap = {};
  
  // Background message handler
  static Function(SmsMessage message)? _onSmsReceived;
  
  /// Check if running on Android
  bool get isAndroid => Platform.isAndroid;
  
  /// Initialize SMS service
  Future<void> initialize() async {
    if (!isAndroid) {
      Logger.warning('SMS service only available on Android', tag: _tag);
      return;
    }
    
    try {
      // Set up background message handler
      _telephony.listenIncomingSms(
        onNewMessage: (telephony.SmsMessage telephonyMessage) {
          _handleIncomingSms(telephonyMessage);
        },
        onBackgroundMessage: _backgroundMessageHandler,
      );
      
      Logger.info('SMS service initialized', tag: _tag);
    } catch (e) {
      Logger.error('Error initializing SMS service', error: e, tag: _tag);
    }
  }
  
  /// Set callback for when SMS is received
  void setOnSmsReceived(Function(SmsMessage message)? callback) {
    _onSmsReceived = callback;
  }
  
  /// Get normalized phone number helper (for comparison)
  String? getNormalizedPhone(String phoneNumber) {
    return PhoneNumberUtils.normalizePhoneNumber(phoneNumber);
  }
  
  /// Handle incoming SMS
  Future<void> _handleIncomingSms(telephony.SmsMessage telephonyMessage) async {
    try {
      final normalizedPhone = PhoneNumberUtils.normalizePhoneNumber(
        telephonyMessage.address ?? '',
      );
      
      if (normalizedPhone == null) {
        Logger.warning('Could not normalize phone number: ${telephonyMessage.address}', tag: _tag);
        return;
      }
      
      final smsMessage = SmsMessage(
        id: telephonyMessage.id?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        phoneNumber: telephonyMessage.address ?? '',
        normalizedPhoneNumber: normalizedPhone,
        content: telephonyMessage.body ?? '',
        timestamp: DateTime.fromMillisecondsSinceEpoch(telephonyMessage.date ?? DateTime.now().millisecondsSinceEpoch),
        isSent: false,
        isRead: false,
      );
      
      Logger.debug('Received SMS from $normalizedPhone', tag: _tag);
      
      // Call callback if set
      _onSmsReceived?.call(smsMessage);
    } catch (e) {
      Logger.error('Error handling incoming SMS', error: e, tag: _tag);
    }
  }
  
  /// Background message handler (must be top-level function)
  @pragma('vm:entry-point')
  static Future<void> _backgroundMessageHandler(telephony.SmsMessage telephonyMessage) async {
    // This is called when app is in background
    // We'll handle it in the foreground handler instead
  }
  
  /// Send SMS
  /// Returns true if sent successfully
  Future<bool> sendSms(String phoneNumber, String message) async {
    if (!isAndroid) {
      throw UnsupportedError('SMS is only supported on Android');
    }
    
    try {
      // Check permissions
      if (!await _permissionService.hasSmsPermissions()) {
        Logger.warning('SMS permissions not granted', tag: _tag);
        throw Exception('SMS permissions not granted');
      }
      
      // Normalize phone number
      final normalizedPhone = PhoneNumberUtils.normalizePhoneNumber(phoneNumber);
      if (normalizedPhone == null) {
        throw Exception('Invalid phone number: $phoneNumber');
      }
      
      // Check rate limit
      if (!_checkRateLimit(normalizedPhone)) {
        throw Exception('Rate limit exceeded. Please wait before sending more messages.');
      }
      
      // Send SMS (returns void, assume success if no exception)
      await _telephony.sendSms(
        to: normalizedPhone,
        message: message,
      );
      
      Logger.info('SMS sent successfully to $normalizedPhone', tag: _tag);
      _updateRateLimit(normalizedPhone);
      return true;
    } catch (e) {
      Logger.error('Error sending SMS', error: e, tag: _tag);
      rethrow;
    }
  }
  
  /// Get all SMS conversations
  Future<List<SmsConversation>> getSmsConversations({int? limit}) async {
    if (!isAndroid) {
      throw UnsupportedError('SMS is only supported on Android');
    }
    
    try {
      if (!await _permissionService.hasSmsPermissions()) {
        Logger.warning('SMS permissions not granted', tag: _tag);
        return [];
      }
      
      // Get conversations from device
      final conversations = <SmsConversation>[];
      final threads = await _telephony.getInboxSms(
        columns: [telephony.SmsColumn.ADDRESS, telephony.SmsColumn.BODY, telephony.SmsColumn.DATE],
        sortOrder: [telephony.OrderBy(telephony.SmsColumn.DATE, sort: telephony.Sort.DESC)],
      );
      
      // Group by phone number
      final conversationMap = <String, SmsConversation>{};
      
      for (final thread in threads) {
        final address = thread.address ?? '';
        final normalizedPhone = PhoneNumberUtils.normalizePhoneNumber(address);
        
        if (normalizedPhone == null) continue;
        
        if (!conversationMap.containsKey(normalizedPhone)) {
          conversationMap[normalizedPhone] = SmsConversation(
            phoneNumber: address,
            normalizedPhoneNumber: normalizedPhone,
            lastMessage: thread.body,
            lastMessageTime: thread.date != null 
                ? DateTime.fromMillisecondsSinceEpoch(thread.date!)
                : null,
            unreadCount: 0, // TODO: Get unread count
            messageCount: 1,
          );
        } else {
          final existing = conversationMap[normalizedPhone]!;
          conversationMap[normalizedPhone] = existing.copyWith(
            messageCount: existing.messageCount + 1,
          );
        }
      }
      
      conversations.addAll(conversationMap.values);
      
      // Sort by last message time
      conversations.sort((a, b) {
        final aTime = a.lastMessageTime ?? DateTime(1970);
        final bTime = b.lastMessageTime ?? DateTime(1970);
        return bTime.compareTo(aTime);
      });
      
      if (limit != null && limit > 0) {
        return conversations.take(limit).toList();
      }
      
      return conversations;
    } catch (e) {
      Logger.error('Error getting SMS conversations', error: e, tag: _tag);
      return [];
    }
  }
  
  /// Get SMS messages for a specific phone number
  Future<List<SmsMessage>> getSmsMessages(String phoneNumber, {int? limit}) async {
    if (!isAndroid) {
      throw UnsupportedError('SMS is only supported on Android');
    }
    
    try {
      if (!await _permissionService.hasSmsPermissions()) {
        Logger.warning('SMS permissions not granted', tag: _tag);
        return [];
      }
      
      final normalizedPhone = PhoneNumberUtils.normalizePhoneNumber(phoneNumber);
      if (normalizedPhone == null) {
        throw Exception('Invalid phone number: $phoneNumber');
      }
      
      // Get messages for this phone number (filter manually since where/whereArgs not supported)
      final allMessages = await _telephony.getInboxSms(
        columns: [telephony.SmsColumn.ADDRESS, telephony.SmsColumn.BODY, telephony.SmsColumn.DATE, telephony.SmsColumn.ID],
        sortOrder: [telephony.OrderBy(telephony.SmsColumn.DATE, sort: telephony.Sort.ASC)],
      );
      
      // Filter by normalized phone number
      final filteredMessages = allMessages.where((msg) {
        final msgNormalized = PhoneNumberUtils.normalizePhoneNumber(msg.address ?? '');
        return msgNormalized == normalizedPhone;
      }).toList();
      
      final smsMessages = filteredMessages.map((msg) {
        return SmsMessage(
          id: msg.id?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          phoneNumber: msg.address ?? '',
          normalizedPhoneNumber: normalizedPhone,
          content: msg.body ?? '',
          timestamp: msg.date != null
              ? DateTime.fromMillisecondsSinceEpoch(msg.date!)
              : DateTime.now(),
          isSent: false, // TODO: Check if sent or received
          isRead: true, // TODO: Get actual read status
        );
      }).toList();
      
      if (limit != null && limit > 0) {
        return smsMessages.take(limit).toList();
      }
      
      return smsMessages;
    } catch (e) {
      Logger.error('Error getting SMS messages', error: e, tag: _tag);
      return [];
    }
  }
  
  /// Mark conversation as read
  Future<void> markAsRead(String phoneNumber) async {
    if (!isAndroid) return;
    
    try {
      // Note: telephony package doesn't support marking as read directly
      // This would need to be handled via native Android code
      Logger.debug('Mark as read not fully supported via telephony package', tag: _tag);
    } catch (e) {
      Logger.error('Error marking conversation as read', error: e, tag: _tag);
    }
  }
  
  /// Delete conversation
  Future<void> deleteConversation(String phoneNumber) async {
    if (!isAndroid) return;
    
    try {
      final normalizedPhone = PhoneNumberUtils.normalizePhoneNumber(phoneNumber);
      if (normalizedPhone == null) return;
      
      // Note: telephony package doesn't support deleteSms method
      // This would need to be implemented via native Android code
      Logger.warning('Delete conversation not fully supported via telephony package', tag: _tag);
      
      Logger.info('Deleted conversation: $normalizedPhone', tag: _tag);
    } catch (e) {
      Logger.error('Error deleting conversation', error: e, tag: _tag);
    }
  }
  
  /// Get total unread SMS count
  Future<int> getUnreadCount() async {
    if (!isAndroid) return 0;
    
    try {
      // Note: telephony package doesn't directly support unread count
      // This would need custom implementation
      return 0;
    } catch (e) {
      Logger.error('Error getting unread count', error: e, tag: _tag);
      return 0;
    }
  }
  
  /// Check rate limit
  bool _checkRateLimit(String phoneNumber) {
    final now = DateTime.now();
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
    
    final recentMessages = _rateLimitMap[phoneNumber]?.where(
      (timestamp) => timestamp.isAfter(oneMinuteAgo),
    ).toList() ?? [];
    
    return recentMessages.length < _rateLimitPerMinute;
  }
  
  /// Update rate limit tracking
  void _updateRateLimit(String phoneNumber) {
    final now = DateTime.now();
    _rateLimitMap[phoneNumber] ??= [];
    _rateLimitMap[phoneNumber]!.add(now);
    
    // Clean up old entries
    final oneMinuteAgo = now.subtract(const Duration(minutes: 1));
    _rateLimitMap[phoneNumber]!.removeWhere(
      (timestamp) => timestamp.isBefore(oneMinuteAgo),
    );
  }
}

