import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/logger_service.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class MergeUsersScreen extends StatefulWidget {
  const MergeUsersScreen({super.key});

  @override
  State<MergeUsersScreen> createState() => _MergeUsersScreenState();
}

class _MergeUsersScreenState extends State<MergeUsersScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _uid1Controller = TextEditingController();
  final TextEditingController _uid2Controller = TextEditingController();
  
  UserModel? _user1;
  UserModel? _user2;
  bool _isLoading = false;
  bool _isMerging = false;
  String? _selectedUid; // Which UID to keep
  final Map<String, String> _fieldSelections = {}; // Field name -> selected UID
  final List<String> _logs = [];

  void _addLog(String message) {
    if (mounted) {
      setState(() {
        _logs.add('${DateTime.now().toIso8601String()} - $message');
      });
    }
    Logger.info('MergeUsers: $message', tag: 'MergeUsersScreen');
  }

  Future<void> _loadUsers() async {
    final uid1 = _uid1Controller.text.trim();
    final uid2 = _uid2Controller.text.trim();

    if (uid1.isEmpty || uid2.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter both user IDs'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    if (uid1 == uid2) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User IDs must be different'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _user1 = null;
      _user2 = null;
      _selectedUid = null;
      _fieldSelections.clear();
      _logs.clear();
    });

    try {
      _addLog('Loading user 1: $uid1');
      final doc1 = await _firestore.collection('users').doc(uid1).get();
      if (!doc1.exists) {
        throw Exception('User 1 not found: $uid1');
      }
      _user1 = UserModel.fromJson({...doc1.data()!, 'uid': uid1});
      _addLog('✓ User 1 loaded: ${_user1!.displayName} (${_user1!.email})');

      _addLog('Loading user 2: $uid2');
      final doc2 = await _firestore.collection('users').doc(uid2).get();
      if (!doc2.exists) {
        throw Exception('User 2 not found: $uid2');
      }
      _user2 = UserModel.fromJson({...doc2.data()!, 'uid': uid2});
      _addLog('✓ User 2 loaded: ${_user2!.displayName} (${_user2!.email})');

      // Auto-select UID 1 as default
      _selectedUid = uid1;
      
      // Auto-select field sources (prefer user1, but use user2 if user1 is null/empty)
      _initializeFieldSelections();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _addLog('❌ Error loading users: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading users: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _initializeFieldSelections() {
    if (_user1 == null || _user2 == null) return;

    // For each field, prefer user1 if it has a value, otherwise use user2
    final fields = [
      'email', 'displayName', 'photoUrl', 'familyId', 'relationship',
      'birthday', 'birthdayNotificationsEnabled', 'calendarSyncEnabled',
      'localCalendarId', 'googleCalendarId', 'lastSyncedAt', 'locationPermissionGranted'
    ];

    for (final field in fields) {
      final user1Value = _getFieldValue(_user1!, field);
      final user2Value = _getFieldValue(_user2!, field);
      
      // Prefer user1 if it has a non-null/non-empty value
      if (user1Value != null && user1Value.toString().isNotEmpty) {
        _fieldSelections[field] = _user1!.uid;
      } else if (user2Value != null && user2Value.toString().isNotEmpty) {
        _fieldSelections[field] = _user2!.uid;
      } else {
        // Both null/empty, default to user1
        _fieldSelections[field] = _user1!.uid;
      }
    }

    // For roles, merge them (union)
    final allRoles = <String>{..._user1!.roles, ..._user2!.roles};
    _fieldSelections['roles'] = 'merged'; // Special marker for merged roles
  }

  dynamic _getFieldValue(UserModel user, String field) {
    switch (field) {
      case 'email': return user.email;
      case 'displayName': return user.displayName;
      case 'photoUrl': return user.photoUrl;
      case 'familyId': return user.familyId;
      case 'relationship': return user.relationship;
      case 'birthday': return user.birthday;
      case 'birthdayNotificationsEnabled': return user.birthdayNotificationsEnabled;
      case 'calendarSyncEnabled': return user.calendarSyncEnabled;
      case 'localCalendarId': return user.localCalendarId;
      case 'googleCalendarId': return user.googleCalendarId;
      case 'lastSyncedAt': return user.lastSyncedAt;
      case 'locationPermissionGranted': return user.locationPermissionGranted;
      default: return null;
    }
  }

  Future<void> _mergeUsers() async {
    if (_user1 == null || _user2 == null || _selectedUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please load both users first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red.shade700, size: 28),
            const SizedBox(width: 8),
            const Expanded(child: Text('⚠️ Confirm Merge ⚠️')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will PERMANENTLY:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('• Merge user data into: ${_selectedUid}'),
              Text('• Delete user: ${_selectedUid == _user1!.uid ? _user2!.uid : _user1!.uid}'),
              const SizedBox(height: 16),
              const Text(
                '⚠️ This action CANNOT be undone! ⚠️',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Merge Users'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isMerging = true;
      _logs.clear();
    });

    try {
      final keepUid = _selectedUid!;
      final deleteUid = keepUid == _user1!.uid ? _user2!.uid : _user1!.uid;
      
      _addLog('Starting merge: Keep $keepUid, Delete $deleteUid');

      // Build merged user data
      final mergedData = <String, dynamic>{};
      
      // Handle each field
      for (final entry in _fieldSelections.entries) {
        final field = entry.key;
        final sourceUid = entry.value;
        
        if (field == 'roles') {
          // Merge roles from both users
          final allRoles = <String>{..._user1!.roles, ..._user2!.roles};
          mergedData['roles'] = allRoles.toList();
          _addLog('Merged roles: ${allRoles.join(", ")}');
        } else {
          final sourceUser = sourceUid == _user1!.uid ? _user1! : _user2!;
          final value = _getFieldValue(sourceUser, field);
          
          if (value != null) {
            if (value is DateTime) {
              mergedData[field] = value.toIso8601String();
            } else {
              mergedData[field] = value;
            }
            _addLog('Field $field: Using ${sourceUser.displayName}');
          }
        }
      }

      // Always keep the selected UID
      mergedData['uid'] = keepUid;
      
      // Use the earlier createdAt
      if (_user1!.createdAt.isBefore(_user2!.createdAt)) {
        mergedData['createdAt'] = _user1!.createdAt.toIso8601String();
      } else {
        mergedData['createdAt'] = _user2!.createdAt.toIso8601String();
      }

      _addLog('Updating merged user document...');
      await _firestore.collection('users').doc(keepUid).update(mergedData);
      _addLog('✓ Merged user document updated');

      // Update notifications to point to kept user
      _addLog('Updating notifications...');
      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('userId', isEqualTo: deleteUid)
          .get();
      
      if (notificationsSnapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in notificationsSnapshot.docs) {
          batch.update(doc.reference, {'userId': keepUid});
        }
        await batch.commit();
        _addLog('✓ Updated ${notificationsSnapshot.docs.length} notifications');
      }

      // Delete the old user document
      _addLog('Deleting old user document...');
      await _firestore.collection('users').doc(deleteUid).delete();
      _addLog('✓ Old user document deleted');

      _addLog('✅ Merge completed successfully!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Users merged successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        
        // Clear the form
        _uid1Controller.clear();
        _uid2Controller.clear();
        setState(() {
          _user1 = null;
          _user2 = null;
          _selectedUid = null;
          _fieldSelections.clear();
        });
      }
    } catch (e, st) {
      _addLog('❌ Error merging users: $e');
      Logger.error('Error merging users', error: e, stackTrace: st, tag: 'MergeUsersScreen');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error merging users: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMerging = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _uid1Controller.dispose();
    _uid2Controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merge Users'),
        backgroundColor: Colors.orange.shade700,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Input section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Enter User IDs to Merge',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _uid1Controller,
                      decoration: const InputDecoration(
                        labelText: 'User ID 1',
                        hintText: 'Enter first user ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      enabled: !_isLoading && !_isMerging,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _uid2Controller,
                      decoration: const InputDecoration(
                        labelText: 'User ID 2',
                        hintText: 'Enter second user ID',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      enabled: !_isLoading && !_isMerging,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: (_isLoading || _isMerging) ? null : _loadUsers,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.search),
                        label: Text(_isLoading ? 'Loading...' : 'Load Users'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Users comparison and selection
            if (_user1 != null && _user2 != null) ...[
              const SizedBox(height: 24),
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select UID to Keep',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      RadioListTile<String>(
                        title: Text('${_user1!.uid} (${_user1!.displayName})'),
                        subtitle: Text(_user1!.email),
                        value: _user1!.uid,
                        groupValue: _selectedUid,
                        onChanged: (value) {
                          setState(() {
                            _selectedUid = value;
                          });
                        },
                      ),
                      RadioListTile<String>(
                        title: Text('${_user2!.uid} (${_user2!.displayName})'),
                        subtitle: Text(_user2!.email),
                        value: _user2!.uid,
                        groupValue: _selectedUid,
                        onChanged: (value) {
                          setState(() {
                            _selectedUid = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select Field Values',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Choose which user\'s value to use for each field:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: ListView(
                            children: [
                              ..._buildFieldSelectionList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isMerging ? null : _mergeUsers,
                  icon: _isMerging
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.merge_type),
                  label: Text(_isMerging ? 'Merging Users...' : 'Merge Users'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    disabledBackgroundColor: Colors.grey,
                  ),
                ),
              ),
            ],
            
            // Logs
            if (_logs.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Merge Log:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                height: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        _logs[index],
                        style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFieldSelectionList() {
    if (_user1 == null || _user2 == null) return [];

    // Roles info card (always merged)
    final rolesCard = Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Roles (Auto-merged)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('${_user1!.displayName}: ${_user1!.roles.isEmpty ? "none" : _user1!.roles.join(", ")}'),
            Text('${_user2!.displayName}: ${_user2!.roles.isEmpty ? "none" : _user2!.roles.join(", ")}'),
            const SizedBox(height: 8),
            Builder(
              builder: (context) {
                final mergedRoles = <String>{..._user1!.roles, ..._user2!.roles};
                return Text(
                  'Merged: ${mergedRoles.isEmpty ? "none" : mergedRoles.join(", ")}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                );
              },
            ),
          ],
        ),
      ),
    );

    final fields = [
      {'name': 'email', 'label': 'Email'},
      {'name': 'displayName', 'label': 'Display Name'},
      {'name': 'photoUrl', 'label': 'Photo URL'},
      {'name': 'familyId', 'label': 'Family ID'},
      {'name': 'relationship', 'label': 'Relationship'},
      {'name': 'birthday', 'label': 'Birthday'},
      {'name': 'birthdayNotificationsEnabled', 'label': 'Birthday Notifications'},
      {'name': 'calendarSyncEnabled', 'label': 'Calendar Sync'},
      {'name': 'localCalendarId', 'label': 'Local Calendar ID'},
      {'name': 'googleCalendarId', 'label': 'Google Calendar ID'},
      {'name': 'locationPermissionGranted', 'label': 'Location Permission'},
    ];

    return [
      rolesCard,
      ...fields.map((field) {
      final fieldName = field['name'] as String;
      final fieldLabel = field['label'] as String;
      final selectedUid = _fieldSelections[fieldName] ?? _user1!.uid;
      
      final user1Value = _getFieldValue(_user1!, fieldName);
      final user2Value = _getFieldValue(_user2!, fieldName);
      
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                fieldLabel,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              RadioListTile<String>(
                title: Text('${_user1!.displayName}: ${_formatValue(user1Value)}'),
                value: _user1!.uid,
                groupValue: selectedUid,
                onChanged: (value) {
                  setState(() {
                    _fieldSelections[fieldName] = value!;
                  });
                },
                dense: true,
              ),
              RadioListTile<String>(
                title: Text('${_user2!.displayName}: ${_formatValue(user2Value)}'),
                value: _user2!.uid,
                groupValue: selectedUid,
                onChanged: (value) {
                  setState(() {
                    _fieldSelections[fieldName] = value!;
                  });
                },
                dense: true,
              ),
            ],
          ),
        ),
      );
    }),
    ];
  }

  String _formatValue(dynamic value) {
    if (value == null) return 'null';
    if (value is DateTime) return value.toIso8601String().split('T')[0];
    if (value is bool) return value.toString();
    return value.toString();
  }
}

