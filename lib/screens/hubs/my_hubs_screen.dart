import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/logger_service.dart';
import '../../services/hub_service.dart';
import '../../models/hub.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import '../../providers/user_data_provider.dart';
import '../../models/user_model.dart';
import '../../services/ios_widget_data_service.dart';
import 'my_friends_hub_screen.dart';
import 'create_hub_dialog.dart';
import '../homeschooling/homeschooling_hub_screen.dart';
import '../extended_family/extended_family_hub_screen.dart';
import '../coparenting/coparenting_hub_screen.dart';

class MyHubsScreen extends StatefulWidget {
  const MyHubsScreen({super.key});

  @override
  State<MyHubsScreen> createState() => _MyHubsScreenState();
}

class _MyHubsScreenState extends State<MyHubsScreen> {
  final HubService _hubService = HubService();
  List<Hub> _hubs = [];
  bool _isLoading = true;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadHubs();
    _getCurrentUserId();
  }

  Future<void> _getCurrentUserId() async {
    final authService = _hubService.currentUserId;
    setState(() {
      _currentUserId = authService;
    });
  }

  Future<void> _loadHubs() async {
    setState(() => _isLoading = true);
    try {
      // Ensure "My Friends" hub exists
      await _hubService.ensureMyFriendsHub();
      
      // Load all user hubs
      final hubs = await _hubService.getUserHubs();
      setState(() {
        _hubs = hubs;
        _isLoading = false;
      });
      
      // Sync hubs to iOS App Group for widget configuration
      if (Platform.isIOS && hubs.isNotEmpty) {
        final hubsList = hubs.map((hub) => {
          'id': hub.id,
          'name': hub.name,
        }).toList();
        IOSWidgetDataService.writeAvailableHubsToAppGroup(hubsList);
      }
    } catch (e) {
      Logger.error('Error loading hubs', error: e, tag: 'MyHubsScreen');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createHub() async {
    final result = await showDialog<Hub>(
      context: context,
      builder: (context) => CreateHubDialog(),
    );

    if (result != null) {
      _loadHubs();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Hubs'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _hubs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hubs yet',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a hub to get started',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: _hubs.length,
                  itemBuilder: (context, index) {
                    final hub = _hubs[index];
                    return _buildHubCard(hub);
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createHub,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHubCard(Hub hub) {
    final isOwner = _currentUserId != null && hub.creatorId == _currentUserId;
    final otherMembers = hub.memberIds.where((id) => id != hub.creatorId).toList();
    final hasOtherMembers = otherMembers.isNotEmpty;

    return ModernCard(
      onTap: () {
        // Navigate based on hub type
        if (hub.hubType == HubType.homeschooling) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => HomeschoolingHubScreen(hubId: hub.id),
            ),
          );
        } else if (hub.hubType == HubType.extendedFamily) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExtendedFamilyHubScreen(hubId: hub.id),
            ),
          );
        } else if (hub.hubType == HubType.coparenting) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CoparentingHubScreen(hubId: hub.id),
            ),
          );
        } else {
          // Default to My Friends view for other hub types
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyFriendsHubScreen(hub: hub),
            ),
          );
        }
      },
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      child: Stack(
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                _getHubIcon(hub.icon),
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  hub.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${hub.memberIds.length} member${hub.memberIds.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          if (isOwner)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.more_vert, size: 20),
                onPressed: () => _showDeleteOptions(hub, hasOtherMembers, otherMembers),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showDeleteOptions(Hub hub, bool hasOtherMembers, List<String> otherMemberIds) async {
    if (!hasOtherMembers) {
      // No other members - simple delete confirmation
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Hub'),
          content: Text('Are you sure you want to delete "${hub.name}"? This action cannot be undone.'),
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
        await _deleteHub(hub);
      }
    } else {
      // Has other members - show warning with transfer option
      await _showDeleteWithMembersDialog(hub, otherMemberIds);
    }
  }

  Future<void> _showDeleteWithMembersDialog(Hub hub, List<String> otherMemberIds) async {
    // Fetch member names
    final userProvider = Provider.of<UserDataProvider>(context, listen: false);
    final memberNames = <String, String>{};
    
    for (var memberId in otherMemberIds) {
      try {
        final userModel = await userProvider.getUserModel(memberId);
        if (userModel != null) {
          memberNames[memberId] = userModel.displayName.isNotEmpty
              ? userModel.displayName
              : (userModel.email.isNotEmpty ? userModel.email.split('@').first : 'Unknown User');
        } else {
          memberNames[memberId] = 'Unknown User';
        }
      } catch (e) {
        Logger.warning('Error fetching member name', error: e, tag: 'MyHubsScreen');
        memberNames[memberId] = 'Unknown User';
      }
    }

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Hub?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This hub has other members. Deleting it will permanently remove all content and data.',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text('Members who will lose access:'),
              const SizedBox(height: 8),
              ...otherMemberIds.map((id) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('• ${memberNames[id] ?? "Unknown User"}'),
                  )),
              const SizedBox(height: 16),
              const Text(
                'Would you like to:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'transfer'),
            child: const Text('Transfer Ownership'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'delete'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete Anyway'),
          ),
        ],
      ),
    );

    if (result == 'transfer') {
      await _showTransferOwnershipDialog(hub, otherMemberIds, memberNames);
    } else if (result == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text(
            'Are you absolutely sure? This will permanently delete the hub and all its content. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete Permanently'),
            ),
          ],
        ),
      );

      if (confirmed == true) {
        await _deleteHub(hub);
      }
    }
  }

  Future<void> _showTransferOwnershipDialog(
    Hub hub,
    List<String> otherMemberIds,
    Map<String, String> memberNames,
  ) async {
    String? selectedMemberId;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Transfer Ownership'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select a member to transfer ownership to:'),
              const SizedBox(height: 16),
              ...otherMemberIds.map((id) => RadioListTile<String>(
                    title: Text(memberNames[id] ?? 'Unknown User'),
                    value: id,
                    groupValue: selectedMemberId,
                    onChanged: (value) => setState(() => selectedMemberId = value),
                  )),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: selectedMemberId != null
                  ? () => Navigator.pop(context, selectedMemberId)
                  : null,
              child: const Text('Transfer & Leave'),
            ),
          ],
        ),
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _transferOwnershipAndLeave(hub, result);
    }
  }

  Future<void> _transferOwnershipAndLeave(Hub hub, String newOwnerId) async {
    try {
      // Transfer ownership
      await _hubService.transferOwnership(hub.id, newOwnerId);
      
      // Leave the hub (now that we're no longer the owner)
      await _hubService.leaveHub(hub.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ownership transferred and you have left the hub'),
            backgroundColor: Colors.green,
          ),
        );
        _loadHubs();
      }
    } catch (e) {
      Logger.error('Error transferring ownership', error: e, tag: 'MyHubsScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteHub(Hub hub) async {
    try {
      await _hubService.deleteHub(hub.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hub deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _loadHubs();
      }
    } catch (e) {
      Logger.error('Error deleting hub', error: e, tag: 'MyHubsScreen');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting hub: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  IconData _getHubIcon(String? icon) {
    switch (icon) {
      case 'people':
        return Icons.people;
      case 'sports':
        return Icons.sports_soccer;
      case 'work':
        return Icons.work;
      case 'school':
        return Icons.school;
      default:
        return Icons.group;
    }
  }
}

