import 'dart:async';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telephony/telephony.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../core/services/logger_service.dart';

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal() {
    _init();
  }

  final Telephony _telephony = Telephony.instance;
  final Uuid _uuid = const Uuid();

  bool _isSmsEnabled = false;
  bool get isSmsEnabled => _isSmsEnabled;

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSmsEnabled = prefs.getBool('sms_sync_enabled') ?? false;
    } catch (e) {
      Logger.error('Error initializing SmsService', error: e, tag: 'SmsService');
    }
  }

  Future<void> setSmsEnabled(bool enabled) async {
    _isSmsEnabled = enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('sms_sync_enabled', enabled);
      
      // If enabling, check permissions
      if (enabled) {
        final granted = await checkPermissions();
        if (!granted) {
          _isSmsEnabled = false;
          await prefs.setBool('sms_sync_enabled', false);
          throw Exception('Permissions denied');
        }
      }
    } catch (e) {
      Logger.error('Error setting SMS enabled', error: e, tag: 'SmsService');
      rethrow;
    }
  }

  Future<bool> checkPermissions() async {
    if (!Platform.isAndroid) return false;
    
    final bool? result = await _telephony.requestPhoneAndSmsPermissions;
    return result ?? false;
  }

  Future<List<ChatMessage>> getSmsMessages({int limit = 50}) async {
    if (!Platform.isAndroid || !_isSmsEnabled) return [];

    try {
      // Get conversations (threads) first
      final List<SmsConversation> conversations = await _telephony.getConversations(
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      final List<ChatMessage> messages = [];

      // Process top conversations
      for (final conversation in conversations.take(10)) { // Limit to recent threads for performance
        // Only valid if we have messages
        // Fetch messages for this thread
        // Note: Telephony doesn't strictly link conversation objects to full message lists easily in one go
        // We might just fetch all messages or fetch by thread ID if supported. 
        // Telephony.getInbox returns SmsMessage list.
      }
      
      // Better approach: Get Inbox
      final List<SmsMessage> smsMessages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE, SmsColumn.THREAD_ID, SmsColumn.TYPE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      for (final sms in smsMessages.take(limit)) {
        if (sms.body == null || sms.address == null) continue;

        final isInbox = sms.type == SmsType.MESSAGE_TYPE_INBOX;
        
        messages.add(ChatMessage(
          id: 'sms_${sms.id ?? _uuid.v4()}', // Local ID
          senderId: isInbox ? (sms.address ?? 'Unknown') : 'current_user',
          senderName: isInbox ? (sms.address ?? 'Unknown') : 'You', // ContactService will resolve this later
          content: sms.body!,
          timestamp: DateTime.fromMillisecondsSinceEpoch(sms.date ?? DateTime.now().millisecondsSinceEpoch),
          type: MessageType.text,
          isSms: true,
          isLocal: true,
          phoneNumber: sms.address,
          smsThreadId: sms.threadId?.toString(),
        ));
      }

      return messages;
    } catch (e) {
      Logger.error('Error fetching SMS', error: e, tag: 'SmsService');
      return [];
    }
  }

  Future<void> sendSms(String address, String body) async {
    if (Platform.isAndroid) {
      await _telephony.sendSms(to: address, message: body);
    } else {
      // iOS or other - use url_launcher or flutter_sms if integrated
      // For now, we only support direct background sending on Android
      throw UnimplementedError('Background SMS sending only supported on Android');
    }
  }
  
  Stream<List<ChatMessage>> getSmsStream() async* {
    if (!Platform.isAndroid || !_isSmsEnabled) {
      yield [];
      return;
    }

    // Initial fetch
    yield await getSmsMessages();

    // Poll periodically (simple solution for now, Telephony has listenIncomingSms but that's for new messages, merging is complex)
    // For a robust stream, we'd listen to incoming and merge, but polling every 30s is safer for MVP
    // Or better: use telephony.listenIncomingSms to trigger a refresh
    
    // We'll return a periodic stream that refreshes SMS
    // In production, we would use ContentObserver via method channel
    final StreamController<List<ChatMessage>> controller = StreamController();
    
    // Initial add
    controller.add(await getSmsMessages());

    // Listen for new SMS (foreground)
    _telephony.listenIncomingSms(
      onNewMessage: (SmsMessage message) async {
        controller.add(await getSmsMessages());
      },
      listenInBackground: false, // Background requires specific static callback setup
    );

    yield* controller.stream;
  }
}
