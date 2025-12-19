import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/logger_service.dart';
import '../../models/hub.dart';
import '../../models/user_model.dart';
import '../../services/hub_service.dart';
import '../../services/auth_service.dart';

class InviteMembersDialog extends StatefulWidget {
  final Hub hub;
  final List<UserModel> currentMembers;

  const InviteMembersDialog({
    super.key,
    required this.hub,
    required this.currentMembers,
  });

  @override
  State<InviteMembersDialog> createState() => _InviteMembersDialogState();
}

class _InviteMembersDialogState extends State<InviteMembersDialog> with TickerProviderStateMixin {
  final HubService _hubService = HubService();
  final AuthService _authService = AuthService();
  
  late TabController _tabController;
  List<UserModel> _availableMembers = [];
  Set<String> _selectedMemberIds = {};
  bool _isLoading = true;
  bool _isInviting = false;
  
  // Email/SMS invite fields
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailFormKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild when tab changes to update button text
    });
    _loadAvailableMembers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableMembers() async {
    setState(() => _isLoading = true);
    try {
      // Get all family members
      final allFamilyMembers = await _authService.getFamilyMembers();
      
      // Get current member IDs
      final currentMemberIds = widget.currentMembers.map((m) => m.uid).toSet();
      
      // Filter out members who are already in the hub
      final available = allFamilyMembers
          .where((member) => !currentMemberIds.contains(member.uid))
          .toList();
      
      setState(() {
        _availableMembers = available;
        _isLoading = false;
      });
    } catch (e) {
      Logger.error('Error loading available members', error: e, tag: 'InviteMembersDialog');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _inviteFamilyMembers() async {
    if (_selectedMemberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one member to invite'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isInviting = true);

    try {
      for (var memberId in _selectedMemberIds) {
        await _hubService.addMember(widget.hub.id, memberId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_selectedMemberIds.length} member${_selectedMemberIds.length == 1 ? '' : 's'} invited successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error inviting members: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isInviting = false);
      }
    }
  }

  Future<void> _sendEmailOrSmsInvite() async {
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();

    if (email.isEmpty && phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an email address or phone number'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (email.isNotEmpty && !_emailFormKey.currentState!.validate()) {
      return;
    }

    setState(() => _isInviting = true);

    try {
      final invite = await _hubService.createInvite(
        hubId: widget.hub.id,
        email: email.isNotEmpty ? email : null,
        phoneNumber: phone.isNotEmpty ? phone : null,
      );

      // Generate invite link using current app URL (works for web)
      String inviteLink;
      if (kIsWeb) {
        final uri = Uri.base;
        inviteLink = '${uri.scheme}://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/?hub-invite=${invite.id}';
      } else {
        // For mobile, you can use a custom URL scheme or web link
        // Replace with your actual production URL when deployed
        inviteLink = 'https://familyhub.app/?hub-invite=${invite.id}';
      }
      
      if (mounted) {
        // Show dialog with invite link and options to share
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Invite Created!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Share this invite link:'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    inviteLink,
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
                if (email.isNotEmpty)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final emailUri = Uri(
                        scheme: 'mailto',
                        path: email,
                        queryParameters: {
                          'subject': 'Invitation to join ${widget.hub.name}',
                          'body': 'You\'ve been invited to join ${widget.hub.name}!\n\nClick this link to accept: $inviteLink',
                        },
                      );
                      if (await canLaunchUrl(emailUri)) {
                        await launchUrl(emailUri);
                      }
                    },
                    icon: const Icon(Icons.email),
                    label: Text('Open Email to $email'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                if (phone.isNotEmpty) ...[
                  if (email.isNotEmpty) const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final smsUri = Uri(
                        scheme: 'sms',
                        path: phone,
                        queryParameters: {
                          'body': 'You\'ve been invited to join ${widget.hub.name}! Click here: $inviteLink',
                        },
                      );
                      if (await canLaunchUrl(smsUri)) {
                        await launchUrl(smsUri);
                      }
                    },
                    icon: const Icon(Icons.sms),
                    label: Text('Open SMS to $phone'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 40),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteLink));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Link copied to clipboard!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy Link'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
        );
        
        // Clear fields
        _emailController.clear();
        _phoneController.clear();
        
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending invite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isInviting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.person_add, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          const Text('Invite New Members'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Family Members'),
                Tab(text: 'Email / SMS'),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Family Members Tab
                  _buildFamilyMembersTab(),
                  // Email/SMS Tab
                  _buildEmailSmsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isInviting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isInviting ? null : () {
            if (_tabController.index == 0) {
              _inviteFamilyMembers();
            } else {
              _sendEmailOrSmsInvite();
            }
          },
          child: _isInviting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_tabController.index == 0
                  ? 'Invite ${_selectedMemberIds.isEmpty ? '' : '(${_selectedMemberIds.length})'}'
                  : 'Send Invite'),
        ),
      ],
    );
  }

  Widget _buildFamilyMembersTab() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_availableMembers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16.0),
        child: Text(
          'All family members are already in this hub.',
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select members to invite to ${widget.hub.name}:',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _availableMembers.length,
            itemBuilder: (context, index) {
              final member = _availableMembers[index];
              final isSelected = _selectedMemberIds.contains(member.uid);
              
              return CheckboxListTile(
                title: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Theme.of(context).primaryColor,
                      radius: 16,
                      child: Text(
                        member.displayName.isNotEmpty
                            ? member.displayName[0].toUpperCase()
                            : member.email[0].toUpperCase(),
                        style: const TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.displayName.isNotEmpty
                                ? member.displayName
                                : member.email.split('@')[0],
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (member.displayName.isNotEmpty)
                            Text(
                              member.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedMemberIds.add(member.uid);
                    } else {
                      _selectedMemberIds.remove(member.uid);
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmailSmsTab() {
    return Form(
      key: _emailFormKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Invite someone outside your family:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email Address',
              hintText: 'friend@example.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value != null && value.isNotEmpty) {
                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(value)) {
                  return 'Please enter a valid email address';
                }
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'OR',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: '+1234567890',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.phone),
            ),
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'An invite link will be generated that you can share via email or SMS.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

