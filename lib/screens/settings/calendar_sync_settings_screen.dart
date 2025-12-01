import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:device_calendar/device_calendar.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../services/calendar_sync_service.dart';
import '../../services/auth_service.dart';
import '../../services/background_sync_service.dart';
import '../../models/user_model.dart';
import '../../core/services/logger_service.dart';
import 'package:intl/intl.dart';

class CalendarSyncSettingsScreen extends StatefulWidget {
  const CalendarSyncSettingsScreen({super.key});

  @override
  State<CalendarSyncSettingsScreen> createState() => _CalendarSyncSettingsScreenState();
}

class _CalendarSyncSettingsScreenState extends State<CalendarSyncSettingsScreen> {
  final _syncService = CalendarSyncService();
  final _authService = AuthService();

  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isSyncing = false;
  List<Calendar> _deviceCalendars = [];
  Calendar? _selectedCalendar;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _currentUser = await _authService.getCurrentUserModel();
      
      if (_currentUser?.calendarSyncEnabled == true && _currentUser?.localCalendarId != null) {
        // Load device calendars to find the selected one
        _deviceCalendars = await _syncService.getDeviceCalendars();
        final selectedId = _currentUser!.localCalendarId;
        if (selectedId != null && _deviceCalendars.isNotEmpty) {
          try {
            _selectedCalendar = _deviceCalendars.firstWhere(
              (cal) => cal.id == selectedId,
            );
          } catch (e) {
            // Calendar not found, select first available
            _selectedCalendar = _deviceCalendars.first;
          }
        }
      } else {
        // Load calendars for selection
        _deviceCalendars = await _syncService.getDeviceCalendars();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading settings: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _requestPermissions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final hasPermission = await _syncService.hasPermissions();
      if (hasPermission) {
        await _loadSettings();
        if (mounted) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Calendar permissions already granted'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            // Ignore - widget may be deactivating
          }
        }
        return;
      }

      final granted = await _syncService.requestPermissions();
      if (!granted) {
        setState(() {
          _errorMessage = 'Calendar permissions are required for sync. Please grant permissions in your device settings.';
        });
        if (mounted) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Permission denied. Please enable calendar access in device settings.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 5),
              ),
            );
          } catch (e) {
            // Ignore - widget may be deactivating
          }
        }
      } else {
        await _loadSettings();
        if (mounted) {
          try {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Calendar permissions granted successfully'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            // Ignore - widget may be deactivating
          }
        }
      }
    } catch (e) {
      String errorMsg = e.toString();
      // Extract a cleaner error message
      if (errorMsg.contains('Exception:')) {
        errorMsg = errorMsg.split('Exception:').last.trim();
      }
      // Remove widget lifecycle error messages from display
      if (errorMsg.contains('deactivated widget') || errorMsg.contains('Looking up')) {
        errorMsg = 'An error occurred. Please try again.';
      }
      
      setState(() {
        _errorMessage = errorMsg;
      });
      
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMsg'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        } catch (e) {
          // Ignore - widget may be deactivating
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createFamilyHubCalendar() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final calendarId = await _syncService.findOrCreateFamilyHubCalendar();
      if (calendarId != null) {
        await _selectCalendar(calendarId);
      } else {
        setState(() {
          _errorMessage = 'Failed to create FamilyHub calendar';
        });
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('deactivated widget') || errorMsg.contains('Looking up')) {
        errorMsg = 'Error creating calendar. Please try again.';
      }
      setState(() {
        _errorMessage = 'Error creating calendar: $errorMsg';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectCalendar(String calendarId) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _syncService.updateSyncSettings(
        enabled: true,
        localCalendarId: calendarId,
      );

      // Register background sync
      await BackgroundSyncService.registerPeriodicSync();

      // Perform initial sync
      await _syncService.performSync();

      await _loadSettings();
      
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Calendar sync enabled successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          // Ignore - widget may be deactivating
        }
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('deactivated widget') || errorMsg.contains('Looking up')) {
        errorMsg = 'Error enabling sync. Please try again.';
      }
      setState(() {
        _errorMessage = 'Error enabling sync: $errorMsg';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _disableSync() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable Calendar Sync'),
        content: const Text(
          'This will stop syncing events between FamilyHub and your device calendar. '
          'Your existing calendar events will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Disable'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _syncService.updateSyncSettings(enabled: false);
      
      // Cancel background sync
      await BackgroundSyncService.cancelPeriodicSync();
      
      await _loadSettings();
      
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Calendar sync disabled'),
              backgroundColor: Colors.orange,
            ),
          );
        } catch (e) {
          // Ignore - widget may be deactivating
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error disabling sync: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _performManualSync() async {
    setState(() {
      _isSyncing = true;
      _errorMessage = null;
    });

    try {
      await _syncService.performSync();
      await _loadSettings();
      
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sync completed successfully. Calendar will refresh automatically.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } catch (e) {
          // Ignore - widget may be deactivating
        }
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('deactivated widget') || errorMsg.contains('Looking up')) {
        errorMsg = 'Sync failed. Please try again.';
      }
      setState(() {
        _errorMessage = 'Sync failed: $errorMsg';
      });
      
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sync failed: $errorMsg'),
              backgroundColor: Colors.red,
            ),
          );
        } catch (e) {
          // Ignore - widget may be deactivating
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _cleanSyncedEvents() async {
    // Confirm before deleting
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove All Synced Events'),
        content: const Text(
          'This will permanently delete all events that were imported from your device calendar.\n\n'
          'Events you created manually in FamilyHub will NOT be affected.\n\n'
          'This action cannot be undone. Do you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final deletedCount = await _syncService.removeAllSyncedEvents(resetLastSyncedAt: true);
      
      await _loadSettings();
      
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Successfully removed $deletedCount synced events'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          // Ignore - widget may be deactivating
        }
      }
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('deactivated widget') || errorMsg.contains('Looking up')) {
        errorMsg = 'Failed to remove synced events. Please try again.';
      }
      setState(() {
        _errorMessage = 'Error: $errorMsg';
      });
      
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $errorMsg'),
              backgroundColor: Colors.red,
            ),
          );
        } catch (e) {
          // Ignore - widget may be deactivating
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isEnabled = _currentUser?.calendarSyncEnabled == true;
    final lastSynced = _currentUser?.lastSyncedAt;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar Sync'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isEnabled ? Icons.sync : Icons.sync_disabled,
                        color: isEnabled ? Colors.green : Colors.grey,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEnabled ? 'Sync Enabled' : 'Sync Disabled',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (lastSynced != null)
                              Text(
                                'Last synced: ${_formatLastSynced(lastSynced)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              )
                            else if (isEnabled)
                              Text(
                                'Not synced yet',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (isEnabled)
                        Chip(
                          label: const Text('Active'),
                          backgroundColor: Colors.green.shade100,
                          labelStyle: TextStyle(color: Colors.green.shade900),
                        )
                      else
                        Chip(
                          label: const Text('Inactive'),
                          backgroundColor: Colors.grey.shade200,
                        ),
                    ],
                  ),
                  if (_selectedCalendar != null && _selectedCalendar!.id != null) ...[
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Syncing with:',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _selectedCalendar!.name ?? 'Unknown Calendar',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                              ),
                              if (_selectedCalendar!.accountName != null && _selectedCalendar!.accountName!.isNotEmpty)
                                Text(
                                  _selectedCalendar!.accountName!,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              if (lastSynced != null) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 14,
                                      color: Colors.grey[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Last synced: ${_formatLastSynced(lastSynced)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ] else if (isEnabled) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 14,
                                      color: Colors.orange[600],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Not synced yet',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.orange[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (_errorMessage != null) ...[
            Card(
              color: Colors.red.shade50,
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                        ),
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Setup Section
          if (!isEnabled) ...[
            const Text(
              'Setup Calendar Sync',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Sync your FamilyHub events with your device calendar (Google, Apple, Outlook)',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            
            // Web platform warning
            if (kIsWeb) ...[
              Card(
                color: Colors.orange.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'Web Platform Limitation',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Calendar sync is not available on web browsers. '
                        'Please use the mobile app (Android or iOS) to enable calendar synchronization.',
                        style: TextStyle(color: Colors.orange.shade900),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            
            // Step 1: Permissions
            if (!kIsWeb)
              _buildStepCard(
                step: 1,
                title: 'Grant Calendar Permission',
                description: 'Allow FamilyHub to access your calendar',
                action: 'Grant Permission',
                onAction: _requestPermissions,
              ),
            if (!kIsWeb) const SizedBox(height: 12),

            // Step 2: Select Calendar
            if (_deviceCalendars.isNotEmpty) ...[
              _buildStepCard(
                step: 2,
                title: 'Choose Calendar',
                description: 'Select an existing calendar or create a new FamilyHub calendar',
                action: 'Select Calendar',
                onAction: () => _showCalendarSelectionDialog(),
              ),
              const SizedBox(height: 12),
            ],

            // Create FamilyHub Calendar Option
            if (!kIsWeb)
              ElevatedButton.icon(
                onPressed: _createFamilyHubCalendar,
                icon: const Icon(Icons.add),
                label: const Text('Create FamilyHub Calendar'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
          ],

          // Management Section
          if (isEnabled) ...[
            const Text(
              'Sync Management',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Manual Sync Button
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _performManualSync,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              label: Text(_isSyncing ? 'Syncing...' : 'Sync Now'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // Disable Sync
            OutlinedButton.icon(
              onPressed: _disableSync,
              icon: const Icon(Icons.sync_disabled),
              label: const Text('Disable Sync'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: Colors.red,
              ),
            ),
            const SizedBox(height: 16),

            // Clean Synced Events (for testing)
            OutlinedButton.icon(
              onPressed: _cleanSyncedEvents,
              icon: const Icon(Icons.delete_sweep),
              label: const Text('Remove All Synced Events'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                foregroundColor: Colors.orange,
              ),
            ),
          ],

          const SizedBox(height: 24),
          
          // Info Section
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'How it works',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• FamilyHub events are synced to your device calendar\n'
                    '• Events from your device calendar can be imported to FamilyHub\n'
                    '• Changes in FamilyHub take priority in case of conflicts\n'
                    '• Sync runs automatically in the background',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCard({
    required int step,
    required String title,
    required String description,
    required String action,
    required VoidCallback onAction,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  radius: 20,
                  child: Text(
                    '$step',
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAction,
                child: Text(action),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCalendarSelectionDialog() async {
    if (_deviceCalendars.isEmpty) {
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No calendars available. Please grant calendar permissions first.'),
            ),
          );
        } catch (e) {
          // Ignore - widget may be deactivating
        }
      }
      return;
    }

    // Check event counts for each calendar (async, so show loading state)
    final Map<String, int> eventCounts = {};
    
    // Show dialog with loading state first
    final dialogContext = context;
    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Select Calendar'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking calendars for events...'),
          ],
        ),
      ),
    );

    // Check event counts in background
    try {
      final now = DateTime.now();
      final deviceCalendar = DeviceCalendarPlugin();
      
      // Log calendar details for debugging (especially in release builds)
      for (var calendar in _deviceCalendars) {
        Logger.debug(
          'Calendar for event count: name="${calendar.name}", accountName="${calendar.accountName}", id="${calendar.id}"',
          tag: 'CalendarSyncSettingsScreen',
        );
      }
      
      for (var calendar in _deviceCalendars) {
        if (calendar.id == null) {
          Logger.warning(
            'Calendar has null ID: name="${calendar.name}", accountName="${calendar.accountName}"',
            tag: 'CalendarSyncSettingsScreen',
          );
          continue;
        }
        try {
          final result = await deviceCalendar.retrieveEvents(
            calendar.id!,
            RetrieveEventsParams(
              startDate: tz.TZDateTime.from(now.subtract(const Duration(days: 90)), tz.local),
              endDate: tz.TZDateTime.from(now.add(const Duration(days: 180)), tz.local),
            ),
          );
          if (result.isSuccess && result.data != null) {
            eventCounts[calendar.id!] = result.data!.length;
            Logger.debug(
              'Calendar "${calendar.name}" (${calendar.accountName}): ${result.data!.length} events',
              tag: 'CalendarSyncSettingsScreen',
            );
          } else {
            Logger.warning(
              'Failed to retrieve events for calendar "${calendar.name}": ${result.errors.map((e) => e.toString()).join(", ")}',
              tag: 'CalendarSyncSettingsScreen',
            );
          }
        } catch (e, st) {
          Logger.error(
            'Error retrieving events for calendar "${calendar.name}" (ID: ${calendar.id})',
            error: e,
            stackTrace: st,
            tag: 'CalendarSyncSettingsScreen',
          );
        }
      }
    } catch (e, st) {
      Logger.error(
        'Error checking event counts for calendars',
        error: e,
        stackTrace: st,
        tag: 'CalendarSyncSettingsScreen',
      );
    }

    // Close loading dialog
    if (mounted) {
      Navigator.pop(dialogContext);
    }

    // Show selection dialog with event counts
    final selected = await showDialog<Calendar>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: const Text('Select Calendar'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _deviceCalendars.length,
            itemBuilder: (context, index) {
              final calendar = _deviceCalendars[index];
              final eventCount = calendar.id != null ? eventCounts[calendar.id!] : null;
              final hasEvents = eventCount != null && eventCount > 0;
              
              // Build display name with fallback
              final displayName = calendar.name?.isNotEmpty == true
                  ? calendar.name!
                  : (calendar.accountName?.isNotEmpty == true
                      ? calendar.accountName!
                      : 'Unnamed Calendar');
              
              // Build subtitle with account info if different from name
              final subtitle = calendar.accountName != null && 
                              calendar.accountName!.isNotEmpty &&
                              calendar.name != calendar.accountName
                  ? calendar.accountName!
                  : null;
              
              return ListTile(
                title: Row(
                  children: [
                    Expanded(
                      child: Text(displayName),
                    ),
                    if (eventCount != null) ...[
                      const SizedBox(width: 8),
                      Chip(
                        label: Text('$eventCount events'),
                        backgroundColor: hasEvents ? Colors.green.shade100 : Colors.grey.shade200,
                        labelStyle: TextStyle(
                          fontSize: 11,
                          color: hasEvents ? Colors.green.shade900 : Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: subtitle != null ? Text(subtitle) : null,
                trailing: hasEvents
                    ? Icon(Icons.check_circle, color: Colors.green.shade700, size: 20)
                    : Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                onTap: () => Navigator.pop(context, calendar),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selected != null && selected.id != null) {
      final eventCount = eventCounts[selected.id!];
      if (eventCount == null || eventCount == 0) {
        // Warn user if they selected an empty calendar
        final confirmed = await showDialog<bool>(
          context: dialogContext,
          builder: (context) => AlertDialog(
            title: const Text('Empty Calendar Selected'),
            content: Text(
              'The calendar "${selected.name}" appears to have no events in the next 6 months. '
              'You may want to select a different calendar that contains events.\n\n'
              'Do you want to continue with this calendar anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
      }
      await _selectCalendar(selected.id!);
    }
  }

  String _formatLastSynced(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return DateFormat('MMM d, yyyy').format(dateTime);
    }
  }
}

