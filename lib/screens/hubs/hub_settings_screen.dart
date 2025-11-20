import 'package:flutter/material.dart';
import '../../models/hub.dart';
import '../../services/hub_service.dart';
import '../../services/auth_service.dart';

class HubSettingsScreen extends StatefulWidget {
  final Hub hub;

  const HubSettingsScreen({super.key, required this.hub});

  @override
  State<HubSettingsScreen> createState() => _HubSettingsScreenState();
}

class _HubSettingsScreenState extends State<HubSettingsScreen> {
  final HubService _hubService = HubService();
  final AuthService _authService = AuthService();

  bool _videoCallsEnabled = true;
  bool _isLoading = false;
  bool _isCreator = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final user = _authService.currentUser;
    setState(() {
      _isCreator = user?.uid == widget.hub.creatorId;
      _videoCallsEnabled = widget.hub.videoCallsEnabled;
    });
  }

  Future<void> _updateVideoCallsEnabled(bool value) async {
    if (!_isCreator) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only the hub creator can change this setting'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _hubService.updateHub(
        widget.hub.id,
        {'videoCallsEnabled': value},
      );
      setState(() {
        _videoCallsEnabled = value;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'Video calls enabled' : 'Video calls disabled'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.hub.name} Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              title: const Text('Allow Video Calls'),
              subtitle: const Text('Enable video calling in this hub'),
              value: _videoCallsEnabled,
              onChanged: _isCreator && !_isLoading ? _updateVideoCallsEnabled : null,
              secondary: const Icon(Icons.videocam),
            ),
          ),
          if (!_isCreator)
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Only the hub creator can change these settings',
                        style: TextStyle(color: Colors.orange[900]),
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
}

