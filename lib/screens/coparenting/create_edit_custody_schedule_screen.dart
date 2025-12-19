import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/coparenting_schedule.dart';
import '../../models/child_profile.dart';
import '../../models/user_model.dart';
import '../../services/coparenting_service.dart';
import '../../services/auth_service.dart';
import '../../services/hub_service.dart';
import '../../utils/app_theme.dart';

/// Screen for creating or editing a custody schedule
class CreateEditCustodyScheduleScreen extends StatefulWidget {
  final String hubId;
  final CustodySchedule? schedule;

  const CreateEditCustodyScheduleScreen({
    super.key,
    required this.hubId,
    this.schedule,
  });

  @override
  State<CreateEditCustodyScheduleScreen> createState() => _CreateEditCustodyScheduleScreenState();
}

class _CreateEditCustodyScheduleScreenState extends State<CreateEditCustodyScheduleScreen> {
  final _formKey = GlobalKey<FormState>();
  final CoparentingService _service = CoparentingService();
  final HubService _hubService = HubService();
  final AuthService _authService = AuthService();
  
  List<ChildProfile> _childProfiles = [];
  List<UserModel> _members = []; // Still needed for parent selection in custom schedule
  String? _selectedChildId;
  ScheduleType _selectedType = ScheduleType.weekOnWeekOff;
  DateTime? _startDate;
  DateTime? _endDate;
  Map<String, String> _weeklySchedule = {};
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load child profiles for child dropdown
      final childProfiles = await _service.getChildProfiles(widget.hubId);
      
      // Still load members for parent selection in custom schedule dialog
      final hub = await _hubService.getHub(widget.hubId);
      final members = <UserModel>[];
      if (hub != null) {
        for (final memberId in hub.memberIds) {
          final user = await _authService.getUserModel(memberId);
          if (user != null) {
            members.add(user);
          }
        }
      }

      if (widget.schedule != null) {
        _selectedChildId = widget.schedule!.childId;
        _selectedType = widget.schedule!.type;
        _startDate = widget.schedule!.startDate;
        _endDate = widget.schedule!.endDate;
        _weeklySchedule = Map<String, String>.from(widget.schedule!.weeklySchedule);
      }

      if (mounted) {
        setState(() {
          _childProfiles = childProfiles;
          _members = members;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? (_startDate ?? DateTime.now()).add(const Duration(days: 365)),
      firstDate: _startDate ?? DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  void _buildWeeklySchedule() {
    if (_selectedType != ScheduleType.custom) {
      // For predefined schedules, we'll let the service handle the logic
      _weeklySchedule = {};
      return;
    }

    // For custom schedule, show day assignment dialog
    _showCustomScheduleDialog();
  }

  void _showCustomScheduleDialog() {
    final daysOfWeek = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final parentIds = _members.map((m) => m.uid).toList();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final tempSchedule = Map<String, String>.from(_weeklySchedule);
          
          return AlertDialog(
            title: const Text('Custom Weekly Schedule'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: daysOfWeek.length,
                itemBuilder: (context, index) {
                  final day = daysOfWeek[index];
                  final currentParentId = tempSchedule[day];
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(day)),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: currentParentId,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('None')),
                              ...parentIds.map((id) {
                                final member = _members.firstWhere((m) => m.uid == id);
                                return DropdownMenuItem(
                                  value: id,
                                  child: Text(member.displayName),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setDialogState(() {
                                if (value == null) {
                                  tempSchedule.remove(day);
                                } else {
                                  tempSchedule[day] = value;
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _weeklySchedule = tempSchedule;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_selectedChildId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a child'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.schedule == null) {
        await _service.createCustodySchedule(
          hubId: widget.hubId,
          childId: _selectedChildId!,
          type: _selectedType,
          weeklySchedule: _weeklySchedule.isEmpty ? null : _weeklySchedule,
          startDate: _startDate,
          endDate: _endDate,
        );
      } else {
        await _service.updateCustodySchedule(
          hubId: widget.hubId,
          scheduleId: widget.schedule!.id,
          type: _selectedType,
          weeklySchedule: _weeklySchedule.isEmpty ? null : _weeklySchedule,
          startDate: _startDate,
          endDate: _endDate,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.schedule == null
                ? 'Schedule created successfully'
                : 'Schedule updated successfully'),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving schedule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getScheduleTypeLabel(ScheduleType type) {
    switch (type) {
      case ScheduleType.weekOnWeekOff:
        return 'Week On/Week Off';
      case ScheduleType.twoTwoThree:
        return '2-2-3 Schedule';
      case ScheduleType.everyOtherWeekend:
        return 'Every Other Weekend';
      case ScheduleType.custom:
        return 'Custom Schedule';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.schedule == null ? 'Create Schedule' : 'Edit Schedule'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Child selection
                    DropdownButtonFormField<String>(
                      value: _selectedChildId,
                      decoration: const InputDecoration(
                        labelText: 'Child *',
                        border: OutlineInputBorder(),
                        helperText: 'Select the child for this schedule',
                      ),
                      items: _childProfiles.map((child) {
                        return DropdownMenuItem(
                          value: child.id,
                          child: Text(child.name),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedChildId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'Please select a child';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingMD),

                    // Schedule type
                    DropdownButtonFormField<ScheduleType>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Schedule Type *',
                        border: OutlineInputBorder(),
                      ),
                      items: ScheduleType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(_getScheduleTypeLabel(type)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedType = value;
                            if (value != ScheduleType.custom) {
                              _weeklySchedule = {};
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppTheme.spacingMD),

                    // Start date
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Start Date (optional)',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _startDate != null
                                  ? DateFormat('MMM d, y').format(_startDate!)
                                  : 'Not set',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: _selectStartDate,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),

                    // End date
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'End Date (optional)',
                        border: OutlineInputBorder(),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _endDate != null
                                  ? DateFormat('MMM d, y').format(_endDate!)
                                  : 'Not set',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: _selectEndDate,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMD),

                    // Custom schedule button
                    if (_selectedType == ScheduleType.custom) ...[
                      ElevatedButton.icon(
                        onPressed: _buildWeeklySchedule,
                        icon: const Icon(Icons.edit),
                        label: Text(
                          _weeklySchedule.isEmpty
                              ? 'Set Weekly Schedule'
                              : 'Edit Weekly Schedule (${_weeklySchedule.length} days set)',
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacingMD),
                    ],

                    const SizedBox(height: AppTheme.spacingLG),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(AppTheme.spacingMD),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _saveSchedule,
            icon: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: Text(widget.schedule == null ? 'Create Schedule' : 'Update Schedule'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ),
    );
  }
}

