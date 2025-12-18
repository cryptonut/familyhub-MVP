import 'package:flutter_contacts/flutter_contacts.dart';
import '../core/services/logger_service.dart';

class ContactService {
  static final ContactService _instance = ContactService._internal();
  factory ContactService() => _instance;
  ContactService._internal();

  final Map<String, String> _nameCache = {};
  bool _initialized = false;

  Future<bool> requestPermission() async {
    try {
      if (await FlutterContacts.requestPermission()) {
        _initialized = true;
        return true;
      }
    } catch (e) {
      Logger.error('Error requesting contacts permission', error: e, tag: 'ContactService');
    }
    return false;
  }

  Future<String?> getContactName(String phoneNumber) async {
    if (!_initialized) {
      if (!await requestPermission()) return null;
    }

    // Normalize phone number for cache key (simple strip)
    final key = phoneNumber.replaceAll(RegExp(r'\D'), '');
    
    if (_nameCache.containsKey(key)) {
      return _nameCache[key];
    }

    try {
      // Allow partial match since formats vary (+1, etc)
      // fetchContacts is heavy, better to use getContact (by ID) if we had it, but here we search
      // FlutterContacts.getContacts(withProperties: true) is expensive.
      // Better: getContacts once and cache all map.
      
      if (_nameCache.isEmpty) {
        await _refreshCache();
      }
      
      // Try exact or partial match
      if (_nameCache.containsKey(key)) return _nameCache[key];
      
      // If not found, might be format mismatch. Return null or formatted number.
      return null;
    } catch (e) {
      Logger.warning('Error fetching contact for $phoneNumber', error: e, tag: 'ContactService');
      return null;
    }
  }

  Future<void> _refreshCache() async {
    try {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      for (var contact in contacts) {
        for (var phone in contact.phones) {
          final normalized = phone.number.replaceAll(RegExp(r'\D'), '');
          if (normalized.isNotEmpty) {
            _nameCache[normalized] = contact.displayName;
          }
        }
      }
    } catch (e) {
      Logger.error('Error refreshing contacts cache', error: e, tag: 'ContactService');
    }
  }
}
