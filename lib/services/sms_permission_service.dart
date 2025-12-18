import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import '../core/services/logger_service.dart';

/// Service for managing SMS and contact permissions (Android only)
class SmsPermissionService {
  static const String _tag = 'SmsPermissionService';

  /// Check if running on Android
  bool get isAndroid => Platform.isAndroid;

  /// Request all SMS permissions
  /// Returns true if all permissions granted
  Future<bool> requestSmsPermissions() async {
    if (!isAndroid) {
      Logger.warning('SMS permissions only available on Android', tag: _tag);
      return false;
    }

    try {
      final permissions = [
        Permission.sms,
        Permission.phone,
      ];

      final statuses = await permissions.request();

      final allGranted = statuses.values.every((status) => 
        status == PermissionStatus.granted || status == PermissionStatus.limited
      );

      if (allGranted) {
        Logger.info('SMS permissions granted', tag: _tag);
      } else {
        Logger.warning('Some SMS permissions denied', tag: _tag);
      }

      return allGranted;
    } catch (e) {
      Logger.error('Error requesting SMS permissions', error: e, tag: _tag);
      return false;
    }
  }

  /// Request contact read permissions
  /// Returns true if permission granted
  Future<bool> requestContactPermissions() async {
    if (!isAndroid) {
      Logger.warning('Contact permissions only available on Android', tag: _tag);
      return false;
    }

    try {
      final status = await Permission.contacts.request();

      if (status == PermissionStatus.granted || status == PermissionStatus.limited) {
        Logger.info('Contact permissions granted', tag: _tag);
        return true;
      } else {
        Logger.warning('Contact permissions denied', tag: _tag);
        return false;
      }
    } catch (e) {
      Logger.error('Error requesting contact permissions', error: e, tag: _tag);
      return false;
    }
  }

  /// Check if all required permissions are granted
  Future<bool> hasAllPermissions() async {
    if (!isAndroid) return false;

    try {
      final smsGranted = await hasSmsPermissions();
      final contactGranted = await hasContactPermissions();
      return smsGranted && contactGranted;
    } catch (e) {
      Logger.error('Error checking permissions', error: e, tag: _tag);
      return false;
    }
  }

  /// Check if SMS permissions are granted
  Future<bool> hasSmsPermissions() async {
    if (!isAndroid) return false;

    try {
      final smsStatus = await Permission.sms.status;
      final phoneStatus = await Permission.phone.status;

      return (smsStatus == PermissionStatus.granted || smsStatus == PermissionStatus.limited) &&
             (phoneStatus == PermissionStatus.granted || phoneStatus == PermissionStatus.limited);
    } catch (e) {
      Logger.error('Error checking SMS permissions', error: e, tag: _tag);
      return false;
    }
  }

  /// Check if contact permissions are granted
  Future<bool> hasContactPermissions() async {
    if (!isAndroid) return false;

    try {
      final status = await Permission.contacts.status;
      return status == PermissionStatus.granted || status == PermissionStatus.limited;
    } catch (e) {
      Logger.error('Error checking contact permissions', error: e, tag: _tag);
      return false;
    }
  }

  /// Open app settings for manual permission grant
  Future<void> openAppSettings() async {
    await openAppSettings();
  }
}

