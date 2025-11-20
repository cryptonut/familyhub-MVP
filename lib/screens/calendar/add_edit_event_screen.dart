import 'package:flutter/material.dart';
import '../../models/calendar_event.dart';
import '../../models/user_model.dart';
import '../../services/calendar_service.dart';
import '../../services/auth_service.dart';
import '../../services/calendar_sync_service.dart';
import '../../utils/date_utils.dart' as app_date_utils;
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddEditEventScreen extends StatefulWidget {
  final CalendarEvent? event;
  final DateTime? selectedDate;

  const AddEditEventScreen({
    super.key,
    this.event,
    this.selectedDate,
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
      setState(() {
        _familyMembers = members;
        _calendarSyncEnabled = userModel?.calendarSyncEnabled ?? false;
        _addToPersonalCalendar = _calendarSyncEnabled; // Default to true if sync enabled
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
      );

      if (widget.event != null) {
        await _calendarService.updateEvent(event);
      } else {
        await _calendarService.addEvent(event);
      }

      // Sync to device calendar if enabled and checkbox is checked
      if (_calendarSyncEnabled && _addToPersonalCalendar) {
        try {
          await _syncService.performSync();
        } catch (e) {
          debugPrint('Error syncing event to device calendar: $e');
          // Don't block the user if sync fails
        }
      }

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
        
        // Show both detailed message and original error for debugging
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event != null ? 'Edit Event' : 'New Event'),
        actions: [
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

  Color _parseColor(String colorString) {
    try {
      return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
    } catch (e) {
      return Colors.blue;
    }
  }
}

