import 'package:flutter/material.dart';
import '../../models/hub_invite.dart';
import '../../services/hub_service.dart';
import '../../services/auth_service.dart';
import 'my_friends_hub_screen.dart';

class HubInviteScreen extends StatefulWidget {
  final String inviteId;

  const HubInviteScreen({
    super.key,
    required this.inviteId,
  });

  @override
  State<HubInviteScreen> createState() => _HubInviteScreenState();
}

class _HubInviteScreenState extends State<HubInviteScreen> {
  final HubService _hubService = HubService();
  final AuthService _authService = AuthService();
  
  HubInvite? _invite;
  bool _isLoading = true;
  bool _isAccepting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInvite();
  }

  Future<void> _loadInvite() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final invite = await _hubService.getInvite(widget.inviteId);
      
      if (invite == null) {
        setState(() {
          _error = 'Invite not found';
          _isLoading = false;
        });
        return;
      }

      if (invite.isExpired) {
        setState(() {
          _error = 'This invite has expired';
          _isLoading = false;
        });
        return;
      }

      if (invite.status != 'pending') {
        setState(() {
          _error = 'This invite has already been ${invite.status}';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _invite = invite;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading invite: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptInvite() async {
    // Check if user is logged in
    final currentUser = await _authService.getCurrentUserModel();
    if (currentUser == null) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Login Required'),
            content: const Text(
              'You need to be logged in to accept this invite. '
              'Please log in or create an account first.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
      return;
    }

    setState(() => _isAccepting = true);

    try {
      await _hubService.acceptInvite(widget.inviteId);
      
      // Get the hub to navigate to it
      final hub = await _hubService.getHub(_invite!.hubId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully joined the hub!'),
            backgroundColor: Colors.green,
          ),
        );

        // Navigate to the hub
        if (hub != null) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MyFriendsHubScreen(hub: hub),
            ),
          );
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAccepting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting invite: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hub Invitation'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              : _invite == null
                  ? const Center(child: Text('Invite not found'))
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Icon(
                            Icons.group_add,
                            size: 80,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'You\'ve been invited!',
                            style: Theme.of(context).textTheme.headlineSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.group,
                                        color: Theme.of(context).primaryColor,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _invite!.hubName,
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.person,
                                        size: 16,
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Invited by ${_invite!.inviterName}',
                                        style: TextStyle(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_invite!.email != null) ...[
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.email,
                                          size: 16,
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _invite!.email!,
                                          style: TextStyle(
                                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          ElevatedButton(
                            onPressed: _isAccepting ? null : _acceptInvite,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _isAccepting
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Theme.of(context).colorScheme.onPrimary,
                                    ),
                                  )
                                : const Text(
                                    'Accept Invitation',
                                    style: TextStyle(fontSize: 16),
                                  ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ),
    );
  }
}

