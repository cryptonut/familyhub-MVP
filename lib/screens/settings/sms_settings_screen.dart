import 'dart:io';
import 'package:flutter/material.dart';
import '../../services/sms_permission_service.dart';
import '../../services/contact_sync_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';
import '../../utils/firestore_path_utils.dart';
import '../../utils/app_theme.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// SMS settings screen (Android only)
class SmsSettingsScreen extends StatefulWidget {
  const SmsSettingsScreen({super.key});

  @override
  State<SmsSettingsScreen> createState() => _SmsSettingsScreenState();
}

class _SmsSettingsScreenState extends State<SmsSettingsScreen> {
  final SmsPermissionService _permissionService = SmsPermissionService();
  final ContactSyncService _contactService = ContactSyncService();
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _smsEnabled = false;
  bool _hasSmsPermissions = false;
  bool _hasContactPermissions = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (Platform.isAndroid) {
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await _authService.getCurrentUserModel();
      if (user != null) {
        setState(() {
          _smsEnabled = user.smsEnabled;
        });
      }

      final smsPerms = await _permissionService.hasSmsPermissions();
      final contactPerms = await _permissionService.hasContactPermissions();

      setState(() {
        _hasSmsPermissions = smsPerms;
        _hasContactPermissions = contactPerms;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleSmsEnabled(bool value) async {
    try {
      final user = await _authService.getCurrentUserModel();
      if (user == null) return;

      final userPath = FirestorePathUtils.getUserPath(user.uid);
      await _firestore.doc(userPath).update({
        'smsEnabled': value,
      });

      setState(() {
        _smsEnabled = value;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'SMS feature enabled' : 'SMS feature disabled'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating settings: $e')),
        );
      }
    }
  }

  Future<void> _requestSmsPermissions() async {
    final granted = await _permissionService.requestSmsPermissions();
    if (granted && mounted) {
      await _loadSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SMS permissions granted')),
      );
    }
  }

  Future<void> _requestContactPermissions() async {
    final granted = await _permissionService.requestContactPermissions();
    if (granted && mounted) {
      await _loadSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact permissions granted')),
      );
    }
  }

  Future<void> _syncContacts() async {
    try {
      await _contactService.syncDeviceContacts(
        onProgress: (current, total) {
          // Could show progress dialog here
        },
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contacts synced successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing contacts: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!Platform.isAndroid) {
      return Scaffold(
        appBar: AppBar(title: const Text('SMS Settings')),
        body: const Center(
          child: Text('SMS feature is only available on Android devices'),
        ),
      );
    }

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('SMS Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('SMS Settings')),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        children: [
          // SMS Feature Toggle
          Card(
            child: SwitchListTile(
              title: const Text('Enable SMS Feature'),
              subtitle: const Text('Send and receive SMS from within the app'),
              value: _smsEnabled,
              onChanged: _toggleSmsEnabled,
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingMD),
          
          // Permissions Section
          const Text(
            'Permissions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          
          // SMS Permissions
          Card(
            child: ListTile(
              title: const Text('SMS Permissions'),
              subtitle: Text(_hasSmsPermissions ? 'Granted' : 'Not granted'),
              trailing: _hasSmsPermissions
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : ElevatedButton(
                      onPressed: _requestSmsPermissions,
                      child: const Text('Grant'),
                    ),
            ),
          ),
          
          // Contact Permissions
          Card(
            child: ListTile(
              title: const Text('Contact Permissions'),
              subtitle: Text(_hasContactPermissions ? 'Granted' : 'Not granted'),
              trailing: _hasContactPermissions
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : ElevatedButton(
                      onPressed: _requestContactPermissions,
                      child: const Text('Grant'),
                    ),
            ),
          ),
          
          const SizedBox(height: AppTheme.spacingMD),
          
          // Contact Sync Section
          const Text(
            'Contact Sync',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSM),
          
          Card(
            child: ListTile(
              title: const Text('Sync Device Contacts'),
              subtitle: const Text('Sync your device contacts to match phone numbers'),
              trailing: ElevatedButton.icon(
                onPressed: _syncContacts,
                icon: const Icon(Icons.sync),
                label: const Text('Sync Now'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

