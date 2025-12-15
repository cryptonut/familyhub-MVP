import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import '../../core/services/logger_service.dart';
import '../../models/calendar_event.dart';
import '../../models/user_model.dart';
import '../../services/calendar_service.dart';
import '../../services/auth_service.dart';
import '../../services/event_template_service.dart';
import '../../models/event_template.dart';
import '../../widgets/toast_notification.dart';
import '../../services/calendar_sync_service.dart';
import '../../services/event_template_service.dart';
import '../../models/event_template.dart';
import '../../widgets/toast_notification.dart';
import '../../utils/date_utils.dart' as app_date_utils;
import '../../services/hub_service.dart';
import '../../models/hub.dart';

class AddEditEventScreen extends StatefulWidget {
  final CalendarEvent? event;
  final DateTime? selectedDate;
  final List<String>? initialHubIds;

  const AddEditEventScreen({
    super.key,
    this.event,
    this.selectedDate,
    this.initialHubIds,
  });

  @override
  State<AddEditEventScreen> createState() => _AddEditEventScreenState();
}

class _AddEditEventScreenState extends State<AddEditEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _calendarService = CalendarService();
  final _authService = AuthService();
  final _syncService = CalendarSyncService();
  final _templateService = EventTemplateService();
  final _hubService = HubService();
  final _auth = FirebaseAuth.instance;
  
  DateTime _startTime = DateTime.now();
  DateTime _endTime = DateTime.now().add(const Duration(hours: 1));
  String _selectedColor = '#2196F3';
  bool _isRecurring = false;
  String? _selectedRecurrenceRule;
  List<String> _selectedInvitees = [];
  List<UserModel> _familyMembers = [];
  bool _addToPersonalCalendar = true;
  bool _calendarSyncEnabled = false;
  List<Hub> _availableHubs = [];
  Set<String> _selectedHubIds = {}; // Set of selected hub IDs
  bool _familyCalendarExplicitlyDeselected = false; // Track if user explicitly deselected family calendar
  List<String> _photoUrls = [];
  List<File> _pendingPhotos = []; // For mobile
  List<Uint8List> _pendingPhotosWeb = []; // For web
  final ImagePicker _imagePicker = ImagePicker();
  bool _isUploadingPhoto = false;
  
  final List<String> _colors = [
    '#2196F3', // Blue
    '#4CAF50', // Green
    '#FF9800', // Orange
    '#F44336', // Red
    '#9C27B0', // Purple
    '#00BCD4', // Cyan
  ];
  
  final List<String> _recurrenceOptions = [
    'daily',
    'weekly',
    'monthly',
    'yearly',
  ];

  @override
  void initState() {
    super.initState();
    _loadFamilyMembers();
    
    if (widget.event != null) {
      _titleController.text = widget.event!.title;
      _descriptionController.text = widget.event!.description;
      _locationController.text = widget.event!.location ?? '';
      _startTime = widget.event!.startTime;
      _endTime = widget.event!.endTime;
      _selectedColor = widget.event!.color;
      _isRecurring = widget.event!.isRecurring;
      _selectedRecurrenceRule = widget.event!.recurrenceRule;
      _selectedInvitees = List<String>.from(widget.event!.invitedMemberIds);
      _photoUrls = List<String>.from(widget.event!.photoUrls ?? []);
    } else if (widget.selectedDate != null) {
      _startTime = DateTime(
        widget.selectedDate!.year,
        widget.selectedDate!.month,
        widget.selectedDate!.day,
        9,
      );
      _endTime = _startTime.add(const Duration(hours: 1));
    }
  }

  Future<void> _loadFamilyMembers() async {
    try {
      final members = await _authService.getFamilyMembers();
      final userModel = await _authService.getCurrentUserModel();
      final hubs = await _hubService.getUserHubs();
      setState(() {
        _familyMembers = members;
        _calendarSyncEnabled = userModel?.calendarSyncEnabled ?? false;
        _addToPersonalCalendar = _calendarSyncEnabled; // Default to true if sync enabled
        _availableHubs = hubs;
        // Load existing hubIds if editing
        if (widget.event != null && widget.event!.hubIds.isNotEmpty) {
          _selectedHubIds = Set<String>.from(widget.event!.hubIds);
          // Reset flag when loading existing event
          _familyCalendarExplicitlyDeselected = false;
        } else if (widget.event != null && widget.event!.hubId != null) {
          // Backward compatibility: if hubId is set, add it to hubIds
          _selectedHubIds = {widget.event!.hubId!};
          // Reset flag when loading existing event
          _familyCalendarExplicitlyDeselected = false;
        } else if (widget.initialHubIds != null && widget.initialHubIds!.isNotEmpty) {
          // New event with initial hub IDs (e.g., from hub screen)
          _selectedHubIds = Set<String>.from(widget.initialHubIds!);
          _familyCalendarExplicitlyDeselected = false;
        } else {
          // New event: default to family calendar selected
          _selectedHubIds.add(''); // Default to family calendar for new events
          _familyCalendarExplicitlyDeselected = false;
        }
      });
    } catch (e) {
      // Handle error silently
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDateTime(bool isStartTime) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStartTime ? _startTime : _endTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pickedDate == null || !mounted) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        isStartTime ? _startTime : _endTime,
      ),
    );
    if (pickedTime == null || !mounted) return;

    final DateTime selected = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (!mounted) return;
    setState(() {
      if (isStartTime) {
        _startTime = selected;
        if (_endTime.isBefore(_startTime) || _endTime == _startTime) {
          _endTime = _startTime.add(const Duration(hours: 1));
        }
      } else {
        if (selected.isAfter(_startTime)) {
          _endTime = selected;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('End time must be after start time'),
            ),
          );
        }
      }
    });
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final event = CalendarEvent(
        id: widget.event?.id ?? const Uuid().v4(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        startTime: _startTime,
        endTime: _endTime,
        location: _locationController.text.trim().isEmpty
            ? null
            : _locationController.text.trim(),
        color: _selectedColor,
        isRecurring: _isRecurring,
        recurrenceRule: _isRecurring ? _selectedRecurrenceRule : null,
        invitedMemberIds: _selectedInvitees,
        rsvpStatus: widget.event?.rsvpStatus ?? {},
        createdBy: widget.event?.createdBy ?? _auth.currentUser?.uid, // Preserve creator when editing, set for new events
        photoUrls: _photoUrls, // Use current photo URLs
        sourceCalendar: widget.event?.sourceCalendar, // Preserve source calendar when editing
        hubIds: _selectedHubIds.where((id) => id.isNotEmpty && id != '').toList(), // Store selected hub IDs (exclude family marker)
      );

      String eventId = event.id;
      if (widget.event != null) {
        await _calendarService.updateEvent(event);
      } else {
        await _calendarService.addEvent(event);
      }

      // Upload pending photos after event is created/updated
      if (_pendingPhotos.isNotEmpty || _pendingPhotosWeb.isNotEmpty) {
        try {
          final uploadedUrls = <String>[];
          for (var photoFile in _pendingPhotos) {
            try {
              final url = await _calendarService.uploadEventPhoto(
                imageFile: photoFile,
                eventId: eventId,
              );
              uploadedUrls.add(url);
            } catch (e) {
              Logger.error('Error uploading pending photo', error: e, tag: 'AddEditEventScreen');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error uploading photo: $e'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          }
          for (var photoBytes in _pendingPhotosWeb) {
            try {
              final url = await _calendarService.uploadEventPhotoWeb(
                imageBytes: photoBytes,
                eventId: eventId,
              );
              uploadedUrls.add(url);
            } catch (e) {
              Logger.error('Error uploading pending photo', error: e, tag: 'AddEditEventScreen');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error uploading photo: $e'),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            }
          }
          // Add uploaded URLs to the event
          if (uploadedUrls.isNotEmpty) {
            final updatedEvent = event.copyWith(
              photoUrls: [...event.photoUrls, ...uploadedUrls],
            );
            await _calendarService.updateEvent(updatedEvent);
            // Don't show SnackBar here - we're about to pop, parent will show success
          }
          // Clear pending photos
          _pendingPhotos.clear();
          _pendingPhotosWeb.clear();
        } catch (e) {
          Logger.error('Error uploading pending photos', error: e, tag: 'AddEditEventScreen');
          // Don't show SnackBar here - widget might be disposed
          // Error is already logged
        }
      }

      // Sync to device calendar if enabled and checkbox is checked
      if (_calendarSyncEnabled && _addToPersonalCalendar) {
        try {
          await _syncService.performSync();
        } catch (e) {
          Logger.warning('Error syncing event to device calendar', error: e, tag: 'AddEditEventScreen');
          // Don't block the user if sync fails
        }
      }

      // Show success message before popping to avoid widget lifecycle errors
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(widget.event != null ? 'Event updated successfully' : 'Event created successfully'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
          // Small delay to ensure SnackBar is displayed before navigation
          await Future.delayed(const Duration(milliseconds: 100));
        } catch (e) {
          // Ignore errors showing SnackBar - widget might be deactivating
          Logger.debug('Could not show success SnackBar: $e', tag: 'AddEditEventScreen');
        }
      }

      // Pop after showing success message
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        String detailedError = 'Error: $errorMessage';
        
        // Check for specific Firestore errors
        if (errorMessage.contains('permission-denied') || 
            errorMessage.contains('PERMISSION_DENIED')) {
          detailedError = 'Permission denied.\n\n'
              'Please check Firestore security rules:\n'
              '1. Go to Firebase Console > Firestore Database > Rules\n'
              '2. Make sure rules allow authenticated users\n'
              '3. Click "Publish" to save rules';
        } else if (errorMessage.contains('not-found') || 
                   errorMessage.contains('NOT_FOUND') ||
                   errorMessage.contains('UNAVAILABLE')) {
          detailedError = 'Firestore database not accessible.\n\n'
              'Please verify:\n'
              '1. Firestore Database is created in Firebase Console\n'
              '2. Security rules are published (not just saved)\n'
              '3. You are logged in\n'
              '4. Check browser console (F12) for details';
        } else if (errorMessage.contains('unavailable') || 
                   errorMessage.contains('UNAVAILABLE')) {
          detailedError = 'Firestore is unavailable.\n\n'
              'This might be a network issue or the database is not set up.\n'
              'Check Firebase Console to verify Firestore exists.';
        }
        
        // Show error message only if widget is still mounted
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(detailedError),
                  const SizedBox(height: 8),
                  Text(
                    'Original error: ${e.toString()}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 8),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event != null ? 'Edit Event' : 'New Event'),
        actions: [
          if (widget.event == null)
            IconButton(
              icon: const Icon(Icons.bookmark),
              tooltip: 'Use Template',
              onPressed: () => _showTemplatePicker(),
            ),
          TextButton(
            onPressed: _saveEvent,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Start Time'),
              subtitle: Text(app_date_utils.AppDateUtils.formatDateTime(_startTime)),
              trailing: const Icon(Icons.access_time),
              onTap: () => _selectDateTime(true),
            ),
            ListTile(
              title: const Text('End Time'),
              subtitle: Text(app_date_utils.AppDateUtils.formatDateTime(_endTime)),
              trailing: const Icon(Icons.access_time),
              onTap: () => _selectDateTime(false),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 24),
            
            // Recurrence Section
            SwitchListTile(
              title: const Text('Recurring Event'),
              subtitle: const Text('Repeat this event'),
              value: _isRecurring,
              onChanged: (value) {
                setState(() {
                  _isRecurring = value;
                  if (!value) {
                    _selectedRecurrenceRule = null;
                  } else if (_selectedRecurrenceRule == null) {
                    _selectedRecurrenceRule = 'weekly';
                  }
                });
              },
              secondary: const Icon(Icons.repeat),
            ),
            if (_isRecurring) ...[
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedRecurrenceRule,
                decoration: const InputDecoration(
                  labelText: 'Repeat Frequency',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.schedule),
                ),
                items: _recurrenceOptions.map((option) {
                  String label;
                  switch (option) {
                    case 'daily':
                      label = 'Daily';
                      break;
                    case 'weekly':
                      label = 'Weekly';
                      break;
                    case 'monthly':
                      label = 'Monthly';
                      break;
                    case 'yearly':
                      label = 'Yearly';
                      break;
                    default:
                      label = option;
                  }
                  return DropdownMenuItem(
                    value: option,
                    child: Text(label),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRecurrenceRule = value;
                  });
                },
                validator: (value) {
                  if (_isRecurring && (value == null || value.isEmpty)) {
                    return 'Please select a recurrence frequency';
                  }
                  return null;
                },
              ),
            ],
            const SizedBox(height: 24),
            
            // RSVP Invitees Section
            const Text(
              'Invite Family Members',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select family members to invite (optional)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (_familyMembers.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No family members available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ..._familyMembers.map((member) {
                final isSelected = _selectedInvitees.contains(member.uid);
                return CheckboxListTile(
                  title: Text(member.displayName.isNotEmpty
                      ? member.displayName
                      : member.email),
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        _selectedInvitees.add(member.uid);
                      } else {
                        _selectedInvitees.remove(member.uid);
                      }
                    });
                  },
                  secondary: CircleAvatar(
                    backgroundColor: Colors.blue,
                    child: Text(
                      member.displayName.isNotEmpty
                          ? member.displayName[0].toUpperCase()
                          : member.email[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              }),
            const SizedBox(height: 24),
            
            // Add to Calendars Section
            const Text(
              'Add to Calendars',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Select which hubs/family calendars this event appears on',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            // Family Calendar (always available, shown as toggle)
            // Family calendar is represented by empty hubIds list
            // If hubIds is empty, event appears only in family calendar
            // If hubIds has values, event appears in those hubs (and optionally family)
            // We'll use a special marker: if _selectedHubIds contains null or empty string, family is selected
            // For simplicity, we'll track family separately
            SwitchListTile(
              title: const Text('Family Calendar'),
              subtitle: const Text('Main family calendar'),
              value: _selectedHubIds.isEmpty || _selectedHubIds.contains(''), // Empty = family only, or contains '' = family + hubs
              onChanged: (value) {
                setState(() {
                  if (value) {
                    // Add family calendar marker (empty string)
                    if (!_selectedHubIds.contains('')) {
                      _selectedHubIds.add('');
                    }
                    // Reset flag when user explicitly selects family calendar
                    _familyCalendarExplicitlyDeselected = false;
                  } else {
                    // Remove family calendar - but ensure at least one selection remains
                    if (_selectedHubIds.length == 1 && _selectedHubIds.contains('')) {
                      // Can't deselect if it's the only selection
                      return;
                    }
                    _selectedHubIds.remove('');
                    // Mark that user explicitly deselected family calendar
                    _familyCalendarExplicitlyDeselected = true;
                  }
                });
              },
              secondary: const Icon(Icons.family_restroom),
            ),
            // Hub calendars
            if (_availableHubs.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No hubs available',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ..._availableHubs.map((hub) {
                final isSelected = _selectedHubIds.contains(hub.id);
                return SwitchListTile(
                  title: Text(hub.name),
                  subtitle: Text(hub.description),
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value) {
                        _selectedHubIds.add(hub.id);
                      } else {
                        _selectedHubIds.remove(hub.id);
                        // Only auto-add family calendar if it wasn't explicitly deselected by user
                        final hasHubs = _selectedHubIds.any((id) => id.isNotEmpty && id != '');
                        if (!hasHubs && !_selectedHubIds.contains('') && !_familyCalendarExplicitlyDeselected) {
                          // If no hubs selected and family calendar wasn't explicitly deselected, ensure family calendar is selected
                          _selectedHubIds.add('');
                        }
                      }
                    });
                  },
                  secondary: Icon(
                    hub.icon != null 
                        ? _getIconFromString(hub.icon!) 
                        : Icons.group,
                  ),
                );
              }),
            const SizedBox(height: 24),
            
            // Add to Personal Calendar Toggle (only show if sync is enabled)
            if (_calendarSyncEnabled) ...[
              SwitchListTile(
                title: const Text('Add to my personal calendar'),
                subtitle: const Text('Sync this event to your device calendar'),
                value: _addToPersonalCalendar,
                onChanged: (value) {
                  setState(() {
                    _addToPersonalCalendar = value;
                  });
                },
                secondary: const Icon(Icons.calendar_today),
              ),
              const SizedBox(height: 16),
            ],
            
            // Photo Attachments
            const Text(
              'Photos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_photoUrls.isNotEmpty || _pendingPhotos.isNotEmpty || _pendingPhotosWeb.isNotEmpty)
              SizedBox(
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _photoUrls.length + _pendingPhotos.length + _pendingPhotosWeb.length,
                  itemBuilder: (context, index) {
                    if (index < _photoUrls.length) {
                      // Display uploaded photo
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _photoUrls[index],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    width: 100,
                                    height: 100,
                                    color: Colors.grey[300],
                                    child: const Icon(Icons.broken_image),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.red,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _photoUrls.removeAt(index);
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    } else if (index < _photoUrls.length + _pendingPhotos.length) {
                      // Display pending photo (mobile)
                      final photoIndex = index - _photoUrls.length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.file(
                                _pendingPhotos[photoIndex],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.red,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _pendingPhotos.removeAt(photoIndex);
                                    });
                                  },
                                ),
                              ),
                            ),
                            const Positioned(
                              bottom: 4,
                              left: 4,
                              child: Chip(
                                label: Text('Pending', style: TextStyle(fontSize: 10)),
                                backgroundColor: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      );
                    } else {
                      // Display pending photo (web)
                      final photoIndex = index - _photoUrls.length - _pendingPhotos.length;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(
                                _pendingPhotosWeb[photoIndex],
                                width: 100,
                                height: 100,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: CircleAvatar(
                                radius: 12,
                                backgroundColor: Colors.red,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                  onPressed: () {
                                    setState(() {
                                      _pendingPhotosWeb.removeAt(photoIndex);
                                    });
                                  },
                                ),
                              ),
                            ),
                            const Positioned(
                              bottom: 4,
                              left: 4,
                              child: Chip(
                                label: Text('Pending', style: TextStyle(fontSize: 10)),
                                backgroundColor: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                ),
              ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isUploadingPhoto ? null : _pickAndUploadPhoto,
              icon: _isUploadingPhoto
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_photo_alternate),
              label: Text(_isUploadingPhoto ? 'Uploading...' : 'Add Photo'),
            ),
            const SizedBox(height: 24),
            
            const Text(
              'Color',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              children: _colors.map((color) {
                final isSelected = color == _selectedColor;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _parseColor(color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? Colors.black : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() {
        _isUploadingPhoto = true;
      });

      if (kIsWeb) {
        final bytes = await pickedFile.readAsBytes();
        if (widget.event != null) {
          // Event exists, upload immediately
          try {
            final photoUrl = await _calendarService.uploadEventPhotoWeb(
              imageBytes: bytes,
              eventId: widget.event!.id,
            );
            // Update local state immediately
            setState(() {
              _photoUrls.add(photoUrl);
              _isUploadingPhoto = false;
            });
            // Update event in Firestore so it shows up immediately
            try {
              final updatedEvent = widget.event!.copyWith(
                photoUrls: [..._photoUrls, photoUrl],
              );
              await _calendarService.updateEvent(updatedEvent);
            } catch (e) {
              Logger.warning('Error updating event with photo URL', error: e, tag: 'AddEditEventScreen');
              // Don't fail the upload if update fails
            }
            if (mounted) {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Photo uploaded successfully!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              } catch (_) {
                // Widget was disposed - ignore silently
              }
            }
          } catch (e) {
            setState(() {
              _isUploadingPhoto = false;
            });
            if (mounted) {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error uploading photo: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              } catch (_) {
                // Widget was disposed - ignore silently
              }
            }
          }
        } else {
          // Event doesn't exist yet, store for later upload
          setState(() {
            _pendingPhotosWeb.add(bytes);
            _isUploadingPhoto = false;
          });
        }
      } else {
        final file = File(pickedFile.path);
        if (widget.event != null) {
          // Event exists, upload immediately
          try {
            final photoUrl = await _calendarService.uploadEventPhoto(
              imageFile: file,
              eventId: widget.event!.id,
            );
            // Update local state immediately
            setState(() {
              _photoUrls.add(photoUrl);
              _isUploadingPhoto = false;
            });
            // Update event in Firestore so it shows up immediately
            try {
              final updatedEvent = widget.event!.copyWith(
                photoUrls: [..._photoUrls, photoUrl],
              );
              await _calendarService.updateEvent(updatedEvent);
            } catch (e) {
              Logger.warning('Error updating event with photo URL', error: e, tag: 'AddEditEventScreen');
              // Don't fail the upload if update fails
            }
            if (mounted) {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Photo uploaded successfully!'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              } catch (_) {
                // Widget was disposed - ignore silently
              }
            }
          } catch (e) {
            setState(() {
              _isUploadingPhoto = false;
            });
            if (mounted) {
              try {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error uploading photo: $e'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              } catch (_) {
                // Widget was disposed - ignore silently
              }
            }
          }
        } else {
          // Event doesn't exist yet, store for later upload
          setState(() {
            _pendingPhotos.add(file);
            _isUploadingPhoto = false;
          });
          if (mounted) {
            try {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Photo will be uploaded when event is saved'),
                  duration: Duration(seconds: 2),
                ),
              );
            } catch (_) {
              // Widget was disposed - ignore silently
            }
          }
        }
      }
    } catch (e) {
      setState(() {
        _isUploadingPhoto = false;
      });
      // Safely show error message - check mounted and wrap in try-catch
      if (mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error uploading photo: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        } catch (_) {
          // Widget was disposed during SnackBar call - ignore silently
          Logger.warning('Could not show SnackBar - widget disposed', tag: 'AddEditEventScreen');
        }
      }
    }
  }

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }

  IconData _getIconFromString(String iconName) {
    switch (iconName.toLowerCase()) {
      case 'people':
      case 'group':
        return Icons.group;
      case 'family':
        return Icons.family_restroom;
      case 'sports':
        return Icons.sports;
      case 'school':
        return Icons.school;
      case 'work':
        return Icons.work;
      case 'home':
        return Icons.home;
      default:
        return Icons.group;
    }
  }

  Future<void> _showTemplatePicker() async {
    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel?.familyId == null) {
        ToastNotification.error(context, 'No family found');
        return;
      }

      final templates = await _templateService.getTemplates();
      
      if (templates.isEmpty) {
        ToastNotification.info(context, 'No templates available');
        return;
      }

      final selected = await showDialog<EventTemplate>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Template'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: templates.length,
              itemBuilder: (context, index) {
                final template = templates[index];
                return ListTile(
                  title: Text(template.name),
                  subtitle: Text(template.title),
                  onTap: () => Navigator.pop(context, template),
                );
              },
            ),
          ),
        ),
      );

      if (selected != null) {
        final event = await _templateService.createEventFromTemplate(
          selected.id,
          _startTime,
        );
        
        // Populate form with template data
        _titleController.text = event.title;
        _descriptionController.text = event.description;
        _locationController.text = event.location ?? '';
        _selectedColor = event.color;
        _isRecurring = event.isRecurring;
        _selectedRecurrenceRule = event.recurrenceRule;
        _selectedInvitees = event.invitedMemberIds;
        
        setState(() {});
        ToastNotification.success(context, 'Template applied');
      }
    } catch (e) {
      ToastNotification.error(context, 'Error loading template: $e');
    }
  }
}

