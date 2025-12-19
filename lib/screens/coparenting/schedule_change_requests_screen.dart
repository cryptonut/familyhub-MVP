import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/schedule_change_request.dart';
import '../../models/user_model.dart';
import '../../services/coparenting_service.dart';
import '../../services/auth_service.dart';
import '../../services/hub_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'create_schedule_change_request_screen.dart';

/// Screen for managing schedule change requests
class ScheduleChangeRequestsScreen extends StatefulWidget {
  final String hubId;

  const ScheduleChangeRequestsScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<ScheduleChangeRequestsScreen> createState() => _ScheduleChangeRequestsScreenState();
}

class _ScheduleChangeRequestsScreenState extends State<ScheduleChangeRequestsScreen> {
  final CoparentingService _service = CoparentingService();
  final HubService _hubService = HubService();
  final AuthService _authService = AuthService();
  List<ScheduleChangeRequest> _requests = [];
  List<UserModel> _members = [];
  String? _selectedChildId;
  ScheduleChangeStatus? _selectedStatus;
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
      final requests = await _service.getScheduleChangeRequests(
        hubId: widget.hubId,
        childId: _selectedChildId,
        status: _selectedStatus,
      );
      
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
          _requests = requests;
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
          SnackBar(content: Text('Error loading requests: $e')),
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

  Color _getStatusColor(ScheduleChangeStatus status) {
    switch (status) {
      case ScheduleChangeStatus.pending:
        return Colors.orange;
      case ScheduleChangeStatus.approved:
        return Colors.green;
      case ScheduleChangeStatus.rejected:
        return Colors.red;
      case ScheduleChangeStatus.cancelled:
        return Colors.grey;
    }
  }

  String _getStatusLabel(ScheduleChangeStatus status) {
    switch (status) {
      case ScheduleChangeStatus.pending:
        return 'Pending';
      case ScheduleChangeStatus.approved:
        return 'Approved';
      case ScheduleChangeStatus.rejected:
        return 'Rejected';
      case ScheduleChangeStatus.cancelled:
        return 'Cancelled';
    }
  }

  Future<void> _respondToRequest(ScheduleChangeRequest request, ScheduleChangeStatus status) async {
    try {
      await _service.respondToScheduleChange(
        hubId: widget.hubId,
        requestId: request.id,
        status: status,
      );
      if (mounted) {
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request ${status == ScheduleChangeStatus.approved ? 'approved' : 'rejected'}'),
            backgroundColor: status == ScheduleChangeStatus.approved ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error responding to request: $e')),
        );
      }
    }
  }

  Future<void> _showApproveDialog(ScheduleChangeRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Request'),
        content: Text('Approve schedule change request for ${DateFormat('MMM d, y').format(request.requestedDate)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
            child: const Text('Approve'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      _respondToRequest(request, ScheduleChangeStatus.approved);
    }
  }

  Future<void> _showRejectDialog(ScheduleChangeRequest request) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Reject schedule change request for ${DateFormat('MMM d, y').format(request.requestedDate)}?'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                hintText: 'Enter rejection reason',
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Note: Current service doesn't support rejection reason, but we can add it later
      _respondToRequest(request, ScheduleChangeStatus.rejected);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Change Requests'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filters
                Container(
                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                  color: Theme.of(context).cardColor,
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedChildId,
                          decoration: const InputDecoration(
                            labelText: 'Child',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Children')),
                            ..._members.map((member) => DropdownMenuItem(
                                  value: member.uid,
                                  child: Text(member.displayName),
                                )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedChildId = value;
                            });
                            _loadData();
                          },
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacingMD),
                      Expanded(
                        child: DropdownButtonFormField<ScheduleChangeStatus>(
                          value: _selectedStatus,
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Statuses')),
                            ...ScheduleChangeStatus.values.map((status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(_getStatusLabel(status)),
                                )),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _selectedStatus = value;
                            });
                            _loadData();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // Requests list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadData,
                    child: _requests.isEmpty
                        ? Center(
                            child: EmptyState(
                              icon: Icons.swap_horiz_outlined,
                              title: 'No Schedule Change Requests',
                              message: 'Create a request to change the custody schedule',
                              action: ElevatedButton.icon(
                                onPressed: () => _showCreateRequestDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Request Change'),
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(AppTheme.spacingMD),
                            itemCount: _requests.length,
                            itemBuilder: (context, index) {
                              final request = _requests[index];
                              final child = _getMember(request.childId);
                              final requester = _getMember(request.requestedBy);
                              final isPending = request.status == ScheduleChangeStatus.pending;
                              final currentUserId = _authService.currentUser?.uid;
                              final canRespond = isPending && currentUserId != null && currentUserId != request.requestedBy;

                              return Card(
                                margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                                child: Padding(
                                  padding: const EdgeInsets.all(AppTheme.spacingMD),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  child?.displayName ?? 'Unknown Child',
                                                  style: Theme.of(context).textTheme.titleMedium,
                                                ),
                                                Text(
                                                  'Requested: ${DateFormat('MMM d, y').format(request.requestedDate)}',
                                                  style: Theme.of(context).textTheme.bodyMedium,
                                                ),
                                                if (request.swapWithDate != null)
                                                  Text(
                                                    'Swap with: ${DateFormat('MMM d, y').format(DateTime.parse(request.swapWithDate!))}',
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                  ),
                                                if (request.reason != null)
                                                  Text(
                                                    'Reason: ${request.reason}',
                                                    style: Theme.of(context).textTheme.bodySmall,
                                                  ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: _getStatusColor(request.status).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              _getStatusLabel(request.status),
                                              style: TextStyle(
                                                color: _getStatusColor(request.status),
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (requester != null) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          'Requested by: ${requester.displayName}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                      if (canRespond) ...[
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            TextButton.icon(
                                              onPressed: () => _showRejectDialog(request),
                                              icon: const Icon(Icons.close, size: 18),
                                              label: const Text('Reject'),
                                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                                            ),
                                            const SizedBox(width: 8),
                                            ElevatedButton.icon(
                                              onPressed: () => _showApproveDialog(request),
                                              icon: const Icon(Icons.check, size: 18),
                                              label: const Text('Approve'),
                                              style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateRequestDialog,
        icon: const Icon(Icons.add),
        label: const Text('Request Change'),
      ),
    );
  }

  void _showCreateRequestDialog() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateScheduleChangeRequestScreen(
          hubId: widget.hubId,
        ),
      ),
    );
    if (result == true) {
      _loadData();
    }
  }
}
