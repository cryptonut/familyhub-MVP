import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/auth_service.dart';
import '../../widgets/ui_components.dart';

class LocationSettingsScreen extends StatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  State<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen> {
  final AuthService _authService = AuthService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool _locationSharingEnabled = false;
  bool _autoUpdateEnabled = false;
  int _updateIntervalMinutes = 15;
  bool _notifyOnRequest = true;
  bool _showOnMap = true;
  
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final familyId = (await _authService.getCurrentUserModel())?.familyId;
      if (familyId == null) return;

      final doc = await _firestore
          .collection('families')
          .doc(familyId)
          .collection('members')
          .doc(currentUser.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _locationSharingEnabled = data['locationSharingEnabled'] as bool? ?? false;
          _autoUpdateEnabled = data['autoUpdateEnabled'] as bool? ?? false;
          _updateIntervalMinutes = data['updateIntervalMinutes'] as int? ?? 15;
          _notifyOnRequest = data['notifyOnRequest'] as bool? ?? true;
          _showOnMap = data['showOnMap'] as bool? ?? true;
          _loading = false;
        });
      } else {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _saving = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      final familyId = (await _authService.getCurrentUserModel())?.familyId;
      if (familyId == null) {
        throw Exception('User not part of a family');
      }

      await _firestore
          .collection('families')
          .doc(familyId)
          .collection('members')
          .doc(currentUser.uid)
          .set({
        'locationSharingEnabled': _locationSharingEnabled,
        'autoUpdateEnabled': _autoUpdateEnabled,
        'updateIntervalMinutes': _updateIntervalMinutes,
        'notifyOnRequest': _notifyOnRequest,
        'showOnMap': _showOnMap,
        'settingsUpdatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Location Settings'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Settings'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveSettings,
              tooltip: 'Save settings',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location Sharing Toggle
            ModernCard(
              child: SwitchListTile(
                title: const Text(
                  'Enable Location Sharing',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Allow family members to see your location',
                ),
                value: _locationSharingEnabled,
                onChanged: (value) {
                  setState(() {
                    _locationSharingEnabled = value;
                  });
                },
                secondary: const Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),

            // Auto Update Toggle
            ModernCard(
              child: SwitchListTile(
                title: const Text(
                  'Auto-Update Location',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Automatically update your location every $_updateIntervalMinutes minutes',
                ),
                value: _autoUpdateEnabled && _locationSharingEnabled,
                onChanged: _locationSharingEnabled
                    ? (value) {
                        setState(() {
                          _autoUpdateEnabled = value;
                        });
                      }
                    : null,
                secondary: const Icon(Icons.refresh),
              ),
            ),
            const SizedBox(height: 16),

            // Update Interval Slider
            if (_autoUpdateEnabled && _locationSharingEnabled) ...[
              ModernCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule),
                          const SizedBox(width: 8),
                          const Text(
                            'Update Interval',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
                          Text(
                            '$_updateIntervalMinutes minutes',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Slider(
                            value: _updateIntervalMinutes.toDouble(),
                            min: 5,
                            max: 60,
                            divisions: 11,
                            label: '$_updateIntervalMinutes minutes',
                            onChanged: (value) {
                              setState(() {
                                _updateIntervalMinutes = value.round();
                              });
                            },
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              Text('5 min', style: TextStyle(fontSize: 12)),
                              Text('60 min', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Notification Preferences
            ModernCard(
              child: SwitchListTile(
                title: const Text(
                  'Notify on Location Request',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Receive notifications when someone requests your location',
                ),
                value: _notifyOnRequest,
                onChanged: (value) {
                  setState(() {
                    _notifyOnRequest = value;
                  });
                },
                secondary: const Icon(Icons.notifications),
              ),
            ),
            const SizedBox(height: 16),

            // Show on Map Toggle
            ModernCard(
              child: SwitchListTile(
                title: const Text(
                  'Show on Family Map',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  'Allow your location to be displayed on the family map view',
                ),
                value: _showOnMap && _locationSharingEnabled,
                onChanged: _locationSharingEnabled
                    ? (value) {
                        setState(() {
                          _showOnMap = value;
                        });
                      }
                    : null,
                secondary: const Icon(Icons.map),
              ),
            ),
            const SizedBox(height: 24),

            // Info Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Privacy & Permissions',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your location is only shared with family members. You can disable sharing at any time. Location data is stored securely and is not shared with third parties.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

