import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/coparenting_schedule.dart';
import '../../models/user_model.dart';
import '../../services/coparenting_service.dart';
import '../../services/auth_service.dart';
import '../../services/hub_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'create_edit_custody_schedule_screen.dart';

/// Screen for managing custody schedules
class CustodySchedulesScreen extends StatefulWidget {
  final String hubId;

  const CustodySchedulesScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<CustodySchedulesScreen> createState() => _CustodySchedulesScreenState();
}

class _CustodySchedulesScreenState extends State<CustodySchedulesScreen> {
  final CoparentingService _service = CoparentingService();
  final HubService _hubService = HubService();
  final AuthService _authService = AuthService();
  List<CustodySchedule> _schedules = [];
  List<UserModel> _members = [];
  bool _isLoading = true;

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
      final hub = await _hubService.getHub(widget.hubId);
      final schedules = await _service.getCustodySchedules(widget.hubId);
      
      // Load hub members
      final members = <UserModel>[];
      if (hub != null) {
        for (var memberId in hub.memberIds) {
          final user = await _authService.getUserModel(memberId);
          if (user != null) {
            members.add(user);
          }
        }
      }

      if (mounted) {
        setState(() {
          _schedules = schedules;
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
          SnackBar(content: Text('Error loading schedules: $e')),
        );
      }
    }
  }

  UserModel? _getMember(String userId) {
    try {
      return _members.firstWhere((m) => m.uid == userId);
    } catch (e) {
      return null;
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

  Future<void> _deleteSchedule(CustodySchedule schedule) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text('Are you sure you want to delete this custody schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _service.deleteCustodySchedule(
          hubId: widget.hubId,
          scheduleId: schedule.id,
        );
        if (mounted) {
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Schedule deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting schedule: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custody Schedules'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _schedules.isEmpty
                  ? Center(
                      child: EmptyState(
                        icon: Icons.calendar_today_outlined,
                        title: 'No Custody Schedules',
                        message: 'Create a schedule to manage custody arrangements',
                        action: ElevatedButton.icon(
                          onPressed: () => _showCreateScheduleDialog(),
                          icon: const Icon(Icons.add),
                          label: const Text('Create Schedule'),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      itemCount: _schedules.length,
                      itemBuilder: (context, index) {
                        final schedule = _schedules[index];
                        final child = _getMember(schedule.childId);
                        return Card(
                          margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(AppTheme.spacingMD),
                            leading: CircleAvatar(
                              child: Icon(Icons.calendar_today),
                            ),
                            title: Text(
                              child?.displayName ?? 'Unknown Child',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_getScheduleTypeLabel(schedule.type)),
                                if (schedule.startDate != null)
                                  Text(
                                    'Start: ${DateFormat('MMM d, y').format(schedule.startDate!)}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                if (schedule.exceptions.isNotEmpty)
                                  Text(
                                    '${schedule.exceptions.length} exception${schedule.exceptions.length == 1 ? '' : 's'}',
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                              ],
                            ),
                            trailing: PopupMenuButton(
                              itemBuilder: (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 20),
                                      SizedBox(width: 8),
                                      Text('Edit'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, size: 20, color: Colors.red),
                                      SizedBox(width: 8),
                                      Text('Delete', style: TextStyle(color: Colors.red)),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _showEditScheduleDialog(schedule);
                                } else if (value == 'delete') {
                                  _deleteSchedule(schedule);
                                }
                              },
                            ),
                            onTap: () => _showScheduleDetails(schedule),
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateScheduleDialog,
        icon: const Icon(Icons.add),
        label: const Text('Create Schedule'),
      ),
    );
  }

  void _showCreateScheduleDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEditCustodyScheduleScreen(
          hubId: widget.hubId,
        ),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  void _showEditScheduleDialog(CustodySchedule schedule) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateEditCustodyScheduleScreen(
          hubId: widget.hubId,
          schedule: schedule,
        ),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }

  void _showScheduleDetails(CustodySchedule schedule) {
    // TODO: Show schedule details dialog or navigate to detail screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Schedule details - Coming soon')),
    );
  }
}
