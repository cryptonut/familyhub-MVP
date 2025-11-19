import 'package:flutter/material.dart';
import '../../services/hub_service.dart';
import '../../models/hub.dart';
import 'my_friends_hub_screen.dart';
import 'create_hub_dialog.dart';

class MyHubsScreen extends StatefulWidget {
  const MyHubsScreen({super.key});

  @override
  State<MyHubsScreen> createState() => _MyHubsScreenState();
}

class _MyHubsScreenState extends State<MyHubsScreen> {
  final HubService _hubService = HubService();
  List<Hub> _hubs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHubs();
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
    } catch (e) {
      debugPrint('Error loading hubs: $e');
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
                    childAspectRatio: 1.1,
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
    return InkWell(
      onTap: () {
        if (hub.name == 'My Friends') {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyFriendsHubScreen(hub: hub),
            ),
          );
        } else {
          // For now, other hubs also open My Friends view
          // You can create different views for different hub types later
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MyFriendsHubScreen(hub: hub),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _getHubIcon(hub.icon),
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 12),
              Text(
                hub.name,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${hub.memberIds.length} member${hub.memberIds.length == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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

