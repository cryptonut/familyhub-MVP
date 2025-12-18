import 'dart:io';
import 'package:contacts_service/contacts_service.dart';
import '../models/sms_contact.dart';
import '../utils/phone_number_utils.dart';
import '../core/services/logger_service.dart';
import 'sms_permission_service.dart';
import 'auth_service.dart';
import '../models/user_model.dart';
import '../utils/firestore_path_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for syncing device contacts (Android only)
class ContactSyncService {
  static const String _tag = 'ContactSyncService';
  
  final SmsPermissionService _permissionService = SmsPermissionService();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  /// Check if running on Android
  bool get isAndroid => Platform.isAndroid;
  
  /// Sync all device contacts
  /// Returns list of synced contacts
  Future<List<SmsContact>> syncDeviceContacts({
    Function(int current, int total)? onProgress,
  }) async {
    if (!isAndroid) {
      Logger.warning('Contact sync only available on Android', tag: _tag);
      return [];
    }
    
    try {
      // Check permissions
      if (!await _permissionService.hasContactPermissions()) {
        Logger.warning('Contact permissions not granted', tag: _tag);
        throw Exception('Contact permissions not granted');
      }
      
      // Get all contacts
      final contacts = await ContactsService.getContacts();
      final smsContacts = <SmsContact>[];
      
      int current = 0;
      final total = contacts.length;
      
      for (final contact in contacts) {
        // Get phone numbers for this contact
        if (contact.phones != null && contact.phones!.isNotEmpty) {
          for (final phone in contact.phones!) {
            final phoneNumber = phone.value ?? '';
            if (phoneNumber.isEmpty) continue;
            
            final normalizedPhone = PhoneNumberUtils.normalizePhoneNumber(phoneNumber);
            if (normalizedPhone == null) {
              Logger.debug('Could not normalize phone number: $phoneNumber', tag: _tag);
              continue;
            }
            
            final smsContact = SmsContact(
              phoneNumber: phoneNumber,
              normalizedPhoneNumber: normalizedPhone,
              displayName: contact.displayName ?? phoneNumber,
              photoUrl: null, // contact.avatar is Uint8List?, not String? - would need base64 conversion
              contactId: contact.identifier,
              lastSyncedAt: DateTime.now(),
            );
            
            smsContacts.add(smsContact);
          }
        }
        
        current++;
        onProgress?.call(current, total);
      }
      
      // Match app users
      await matchAppUsers(smsContacts);
      
      Logger.info('Synced ${smsContacts.length} contacts', tag: _tag);
      return smsContacts;
    } catch (e) {
      Logger.error('Error syncing contacts', error: e, tag: _tag);
      rethrow;
    }
  }
  
  /// Get contact by phone number
  Future<SmsContact?> getContactByPhoneNumber(String phoneNumber) async {
    if (!isAndroid) return null;
    
    try {
      final normalizedPhone = PhoneNumberUtils.normalizePhoneNumber(phoneNumber);
      if (normalizedPhone == null) return null;
      
      // Search contacts
      final contacts = await ContactsService.getContacts(
        query: phoneNumber,
      );
      
      for (final contact in contacts) {
        if (contact.phones != null) {
          for (final phone in contact.phones!) {
            final contactPhone = phone.value ?? '';
            final contactNormalized = PhoneNumberUtils.normalizePhoneNumber(contactPhone);
            
            if (contactNormalized == normalizedPhone) {
              return SmsContact(
                phoneNumber: contactPhone,
                normalizedPhoneNumber: contactNormalized,
                displayName: contact.displayName ?? contactPhone,
                photoUrl: null, // contact.avatar is Uint8List?, not String? - would need base64 conversion
                contactId: contact.identifier,
                lastSyncedAt: DateTime.now(),
              );
            }
          }
        }
      }
      
      return null;
    } catch (e) {
      Logger.error('Error getting contact by phone number', error: e, tag: _tag);
      return null;
    }
  }
  
  /// Match contacts to app users
  Future<void> matchAppUsers(List<SmsContact> contacts) async {
    try {
      final currentUser = await _authService.getCurrentUserModel();
      if (currentUser == null) return;
      
      // Get all users from Firestore
      final usersSnapshot = await _firestore
          .collection(FirestorePathUtils.getUsersCollection())
          .get();
      
      // Create a map of phone numbers to user IDs
      final phoneToUserId = <String, String>{};
      
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        // Note: UserModel doesn't have phone number field yet
        // This would need to be added if we want to match by phone
        // For now, we'll match by email domain or other criteria if needed
      }
      
      // Match contacts
      for (final contact in contacts) {
        // TODO: Implement matching logic when phone numbers are added to UserModel
        // For now, contacts won't be marked as app users
      }
      
      Logger.debug('Matched ${contacts.where((c) => c.isAppUser).length} app users', tag: _tag);
    } catch (e) {
      Logger.error('Error matching app users', error: e, tag: _tag);
    }
  }
  
  /// Get contact photo
  Future<String?> getContactPhoto(String contactId) async {
    if (!isAndroid) return null;
    
    try {
      // ContactsService doesn't have getContact method, need to search
      final contacts = await ContactsService.getContacts();
      final contact = contacts.firstWhere(
        (c) => c.identifier == contactId,
        orElse: () => throw Exception('Contact not found'),
      );
      // contact.avatar is Uint8List?, not String? - would need base64 conversion
      return null;
    } catch (e) {
      Logger.error('Error getting contact photo', error: e, tag: _tag);
      return null;
    }
  }
  
  /// Request contact permissions
  Future<bool> requestContactPermissions() async {
    return await _permissionService.requestContactPermissions();
  }
}

