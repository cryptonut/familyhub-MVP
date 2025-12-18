import 'dart:io';
import '../models/sms_message.dart';
import '../core/services/logger_service.dart';
import 'sms_service.dart';
import 'sms_metadata_service.dart';
import 'contact_sync_service.dart';

/// Background service for handling incoming SMS (Android only)
class SmsBackgroundService {
  static const String _tag = 'SmsBackgroundService';
  
  final SmsService _smsService = SmsService();
  final SmsMetadataService _metadataService = SmsMetadataService();
  final ContactSyncService _contactService = ContactSyncService();
  
  bool _isInitialized = false;
  
  /// Check if running on Android
  bool get isAndroid => Platform.isAndroid;
  
  /// Initialize background SMS listener
  Future<void> initialize() async {
    if (!isAndroid) {
      Logger.warning('Background SMS service only available on Android', tag: _tag);
      return;
    }
    
    if (_isInitialized) {
      Logger.debug('Background SMS service already initialized', tag: _tag);
      return;
    }
    
    try {
      // Set up SMS received callback
      _smsService.setOnSmsReceived((message) {
        _handleIncomingSms(message);
      });
      
      // Initialize SMS service
      await _smsService.initialize();
      
      _isInitialized = true;
      Logger.info('Background SMS service initialized', tag: _tag);
    } catch (e) {
      Logger.error('Error initializing background SMS service', error: e, tag: _tag);
    }
  }
  
  /// Handle incoming SMS
  Future<void> _handleIncomingSms(SmsMessage message) async {
    try {
      Logger.debug('Received SMS from ${message.phoneNumber}', tag: _tag);
      
      // Get contact info
      final contact = await _contactService.getContactByPhoneNumber(message.phoneNumber);
      if (contact != null) {
        // Update message with contact name
        message = message.copyWith(contactName: contact.displayName);
      }
      
      // Sync metadata to Firestore
      try {
        await _metadataService.syncMessageMetadata(message);
      } catch (e) {
        Logger.warning('Error syncing message metadata', error: e, tag: _tag);
        // Don't fail the whole operation if metadata sync fails
      }
      
      // Update conversation metadata
      try {
        // Get conversation or create new one
        final conversations = await _smsService.getSmsConversations(limit: 1);
        // Find or create conversation for this phone number
        // This is handled by the metadata service when syncing message metadata
      } catch (e) {
        Logger.warning('Error updating conversation metadata', error: e, tag: _tag);
      }
      
      Logger.info('Processed incoming SMS from ${message.phoneNumber}', tag: _tag);
    } catch (e) {
      Logger.error('Error handling incoming SMS', error: e, tag: _tag);
    }
  }
  
  /// Dispose of resources
  void dispose() {
    _isInitialized = false;
  }
}

