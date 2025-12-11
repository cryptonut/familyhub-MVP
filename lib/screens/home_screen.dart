import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added
import 'package:geolocator/geolocator.dart'; // Added
import 'dart:async';
import '../core/services/logger_service.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../services/location_service.dart'; // Added
import '../models/user_model.dart';
import '../games/chess/services/chess_service.dart';
import '../games/chess/models/chess_game.dart';
import '../services/badge_service.dart';
import '../widgets/ui_components.dart' hide Badge;
import '../widgets/quick_actions_fab.dart';
import '../providers/user_data_provider.dart';
import '../services/hub_service.dart';
import '../models/hub.dart';
import 'dashboard/dashboard_screen.dart';
import 'calendar/calendar_screen.dart';
import 'tasks/tasks_screen.dart';
import 'chat/chat_tabs_screen.dart';
import 'location/location_screen.dart';
import 'family/family_invitation_screen.dart';
import 'family/join_family_screen.dart';
import 'admin/role_management_screen.dart';
import 'admin/migration_screen.dart';
import 'admin/database_reset_screen.dart';
import 'profile/edit_profile_screen.dart';
import 'settings/calendar_sync_settings_screen.dart';
import 'settings/privacy_center_screen.dart';
import 'games/games_home_screen.dart';
import 'photos/photos_home_screen.dart';
import 'shopping/shopping_home_screen.dart';
import 'hubs/my_hubs_screen.dart';
import 'hubs/my_friends_hub_screen.dart';
import 'uat/uat_screen.dart';
import '../services/task_service.dart';
import '../services/navigation_order_service.dart';
import '../widgets/reorderable_navigation_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ChessService _chessService = ChessService();
  final BadgeService _badgeService = BadgeService();
  final HubService _hubService = HubService();
  final LocationService _locationService = LocationService(); // Added
  final NavigationOrderService _navigationOrderService = NavigationOrderService();
  late PageController _pageController;
  List<int> _navigationOrder = [0, 1, 2, 3, 4, 5, 6]; // Default order
  
  int _waitingChessChallenges = 0;
  StreamSubscription<List<ChessGame>>? _waitingGamesSubscription;
  StreamSubscription<BadgeCounts>? _badgeCountsSubscription;
  StreamSubscription<QuerySnapshot>? _locationRequestSubscription; // Added
  
  BadgeCounts _badgeCounts = BadgeCounts(
    unreadMessages: 0,
    pendingTasks: 0,
    waitingGames: 0,
    pendingApprovals: 0,
  );
  String? _currentFamilyId;
  String? _currentUserId;
  bool _isDeveloper = false;
  bool _isAdmin = false;
  bool _isTester = false;
  List<Hub> _availableHubs = [];
  String? _selectedHubId;
  String? _currentFamilyName;
  bool _hubsLoaded = false;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _pageController = PageController(initialPage: appState.currentIndex);
    
    // Listen to appState changes to sync PageController
    appState.addListener(_onAppStateChanged);
    
    _loadNavigationOrder();
    _loadWaitingGames();
    _checkUserPermissions();
    _loadBadgeCounts();
    _loadHubsAndFamily();
    _listenForLocationRequests(); // Added
  }

  Future<void> _loadNavigationOrder() async {
    try {
      final order = await _navigationOrderService.getNavigationOrder();
      if (mounted) {
        setState(() {
          _navigationOrder = order;
        });
      }
    } catch (e) {
      Logger.error('Error loading navigation order', error: e, tag: 'HomeScreen');
    }
  }

  void _onAppStateChanged() {
    final appState = Provider.of<AppState>(context, listen: false);
    if (_pageController.hasClients && _pageController.page?.round() != appState.currentIndex) {
      _pageController.jumpToPage(appState.currentIndex);
    }
  }

  @override
  void dispose() {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.removeListener(_onAppStateChanged);
    _pageController.dispose();
    _waitingGamesSubscription?.cancel();
    _badgeCountsSubscription?.cancel();
    _locationRequestSubscription?.cancel();
    super.dispose();
  }

  void _listenForLocationRequests() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUser?.uid;
    if (userId == null) return;

    _locationRequestSubscription?.cancel();
    _locationRequestSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: userId)
        .where('type', isEqualTo: 'location_request')
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          _showLocationRequestDialog(change.doc.id, data);
        }
      }
    });
  }

  Future<void> _showLocationRequestDialog(String notificationId, Map<String, dynamic> data) async {
    final senderName = data['senderName'] ?? 'Someone';
    
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.share_location, color: Colors.blue),
            const SizedBox(width: 8),
            const Text('Location Request'),
          ],
        ),
        content: Text('$senderName is requesting your location. Do you want to share it?'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await FirebaseFirestore.instance.collection('notifications').doc(notificationId).update({
                  'read': true,
                  'status': 'declined',
                });
              } catch (e) {
                Logger.warning('Error updating notification', error: e, tag: 'HomeScreen');
              }
            },
            child: const Text('Deny'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              // Show sharing indicator
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sharing location...')),
                );
              }
              
              // Share location
              final success = await _shareLocation();
              
              // Mark as read/accepted
              try {
                await FirebaseFirestore.instance.collection('notifications').doc(notificationId).update({
                  'read': true,
                  'status': success ? 'accepted' : 'failed',
                });
              } catch (e) {
                Logger.warning('Error updating notification', error: e, tag: 'HomeScreen');
              }
              
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Location shared successfully'), backgroundColor: Colors.green),
                );
              }
            },
            child: const Text('Share Location'),
          ),
        ],
      ),
    );
  }

  Future<bool> _shareLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) return false;
      }
      
      if (permission == LocationPermission.deniedForever) return false;

      final position = await Geolocator.getCurrentPosition();
      final authService = Provider.of<AuthService>(context, listen: false);
      final userId = authService.currentUser?.uid;
      
      if (userId != null) {
        await _locationService.updateMemberLocation(
          userId,
          position.latitude,
          position.longitude,
        );
        return true;
      }
      return false;
    } catch (e) {
      Logger.error('Error sharing location', error: e, tag: 'HomeScreen');
      return false;
    }
  }

  void _loadBadgeCounts() {
    _badgeCountsSubscription = _badgeService.getAllBadgeCounts().listen(
      (counts) {
        if (mounted) {
          setState(() {
            _badgeCounts = counts;
            _waitingChessChallenges = counts.waitingGames;
          });
        }
      },
      onError: (error) {
        Logger.warning('Error loading badge counts', error: error, tag: 'HomeScreen');
      },
    );
  }

  Future<void> _checkUserPermissions() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final userModel = await authService.getCurrentUserModel();
    
    if (mounted) {
      setState(() {
        _isDeveloper = currentUser?.email == 'simoncase78@gmail.com';
        _isAdmin = userModel?.isAdmin() ?? false;
        _isTester = userModel?.hasRole('tester') ?? false;
      });
    }
  }

  Future<void> _loadHubsAndFamily() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userModel = await authService.getCurrentUserModel();
      _currentFamilyId = userModel?.familyId;
      
      // Get family name - default to "Case Family" or derive from familyId
      if (_currentFamilyId != null) {
        // Try to get family name from hubs first, otherwise use default
        _currentFamilyName = 'Case Family'; // Default name
      }
      
      // Load all hubs
      final hubs = await _hubService.getUserHubs();
      
      // Add current family as a hub option if not already in hubs
      if (_currentFamilyId != null && !hubs.any((h) => h.id == _currentFamilyId)) {
        // Create a virtual hub for the current family
        final familyHub = Hub(
          id: _currentFamilyId!,
          name: _currentFamilyName ?? 'Case Family',
          description: 'Your family hub',
          creatorId: userModel?.uid ?? '',
          memberIds: [],
          createdAt: DateTime.now(),
        );
        hubs.insert(0, familyHub);
      }
      
      if (mounted) {
        setState(() {
          _availableHubs = hubs;
          _selectedHubId = _currentFamilyId; // Default to current family
          _hubsLoaded = true;
        });
      }
    } catch (e) {
      Logger.error('Error loading hubs and family', error: e, tag: 'HomeScreen');
      if (mounted) {
        setState(() {
          _hubsLoaded = true;
        });
      }
    }
  }

  Future<void> _loadWaitingGames() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final userModel = await authService.getCurrentUserModel();
      final user = authService.currentUser;
      _currentFamilyId = userModel?.familyId;
      _currentUserId = user?.uid;

      if (_currentFamilyId != null && _currentUserId != null) {
        _waitingGamesSubscription?.cancel();
        _waitingGamesSubscription = _chessService
            .streamWaitingFamilyGames(_currentFamilyId!)
            .listen((games) {
          if (mounted) {
            setState(() {
              // Count games where current user is invited
              _waitingChessChallenges = games
                  .where((g) => g.invitedPlayerId == _currentUserId)
                  .length;
            });
          }
        });
      }
    } catch (e) {
      Logger.error('Error loading waiting chess games', error: e, tag: 'HomeScreen');
    }
  }

  Widget _buildGamesIcon(IconData icon) {
    if (_badgeCounts.waitingGames > 0) {
      return Badge(
        label: Text(
          _badgeCounts.waitingGames > 9 ? '9+' : '${_badgeCounts.waitingGames}',
          style: const TextStyle(fontSize: 10),
        ),
        child: Icon(icon),
      );
    }
    return Icon(icon);
  }

  Widget _buildChatIcon(IconData icon) {
    if (_badgeCounts.unreadMessages > 0) {
      return Badge(
        label: Text(
          _badgeCounts.unreadMessages > 9 ? '9+' : '${_badgeCounts.unreadMessages}',
          style: const TextStyle(fontSize: 10),
        ),
        child: Icon(icon),
      );
    }
    return Icon(icon);
  }

  Widget _buildHubDropdown() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    if (_availableHubs.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Family Hub',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    final selectedHub = _availableHubs.firstWhere(
      (hub) => hub.id == _selectedHubId,
      orElse: () => _availableHubs.first,
    );

    return Align(
      alignment: Alignment.center,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 200, minWidth: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[800] : Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.grey[700]! : Colors.grey[400]!,
            width: 1,
          ),
        ),
        child: DropdownButton<Hub>(
          value: selectedHub,
          isDense: true,
          isExpanded: false,
        underline: const SizedBox.shrink(),
        icon: Icon(
          Icons.arrow_drop_down,
          color: theme.colorScheme.onSurface,
          size: 20,
        ),
        dropdownColor: isDark ? Colors.grey[900] : Colors.white,
        menuMaxHeight: 300,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        items: [
          // Add "Add New Hub" option at the top
          DropdownMenuItem<Hub>(
            value: null, // Special value to indicate "Add New Hub"
            child: Row(
              children: [
                Icon(
                  Icons.add,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add New Hub',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Divider - use a disabled item that won't interfere with selection
          DropdownMenuItem<Hub>(
            value: null,
            enabled: false,
            child: Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 4),
              color: isDark ? Colors.grey[700] : Colors.grey[400],
            ),
          ),
          // Existing hubs
          ..._availableHubs.map((hub) {
            return DropdownMenuItem<Hub>(
              value: hub,
              child: Text(
                hub.name,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                ),
              ),
            );
          }).toList(),
        ],
        onChanged: (Hub? newHub) {
          if (newHub == null) {
            // "Add New Hub" was selected - navigate to hubs screen
            // Use a small delay to allow dropdown to close first
            Future.delayed(const Duration(milliseconds: 100), () {
              if (mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const MyHubsScreen(),
                  ),
                ).then((_) {
                  // Reload hubs when returning from hubs screen
                  _loadHubsAndFamily();
                });
              }
            });
            return;
          }
          
          // Hub was selected - navigate to hub screen
          Logger.info('Navigating to hub: ${newHub.name} (${newHub.id})', tag: 'HomeScreen');
          
          // Update selected hub state
          setState(() {
            _selectedHubId = newHub.id;
            _currentFamilyName = newHub.name;
          });
          
          // Navigate to the hub screen
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MyFriendsHubScreen(hub: newHub),
                ),
              ).then((_) {
                // Reload data when returning from hub screen
                if (mounted) {
                  _loadWaitingGames();
                  _loadBadgeCounts();
                }
              });
            }
          });
        },
        ),
      ),
    );
  }

  Widget _buildJobsIcon(IconData icon) {
    final total = _badgeCounts.pendingTasks + _badgeCounts.pendingApprovals;
    if (total > 0) {
      return Badge(
        label: Text(
          total > 9 ? '9+' : '$total',
          style: const TextStyle(fontSize: 10),
        ),
        child: Icon(icon),
      );
    }
    return Icon(icon);
  }

  /// Build ordered screens based on navigation order
  List<Widget> _buildOrderedScreens() {
    // All screens in their default order (by screen index)
    final allScreens = const [
      DashboardScreen(),      // 0
      CalendarScreen(),       // 1
      TasksScreen(),          // 2
      GamesHomeScreen(),      // 3
      PhotosHomeScreen(),     // 4
      ShoppingHomeScreen(),   // 5
      LocationScreen(),       // 6
    ];

    // Reorder based on _navigationOrder
    return _navigationOrder.map((screenIndex) => allScreens[screenIndex]).toList();
  }

  /// Build ordered navigation destinations based on navigation order
  List<NavigationDestination> _buildOrderedDestinations() {
    // All destinations in their default order (by screen index)
    final allDestinations = [
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      const NavigationDestination(
        icon: Icon(Icons.calendar_today_outlined),
        selectedIcon: Icon(Icons.calendar_today),
        label: 'Calendar',
      ),
      NavigationDestination(
        icon: _buildJobsIcon(Icons.task_outlined),
        selectedIcon: _buildJobsIcon(Icons.task),
        label: 'Jobs',
      ),
      NavigationDestination(
        icon: _buildGamesIcon(Icons.sports_esports_outlined),
        selectedIcon: _buildGamesIcon(Icons.sports_esports),
        label: 'Games',
      ),
      const NavigationDestination(
        icon: Icon(Icons.photo_library_outlined),
        selectedIcon: Icon(Icons.photo_library),
        label: 'Photos',
      ),
      const NavigationDestination(
        icon: Icon(Icons.shopping_bag_outlined),
        selectedIcon: Icon(Icons.shopping_bag),
        label: 'Shopping',
      ),
      const NavigationDestination(
        icon: Icon(Icons.location_on_outlined),
        selectedIcon: Icon(Icons.location_on),
        label: 'Location',
      ),
    ];

    // Reorder based on _navigationOrder
    return _navigationOrder.map((screenIndex) => allDestinations[screenIndex]).toList();
  }

  Future<void> _showDeveloperMenu(BuildContext context, AuthService authService) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.code, color: Colors.orange),
            SizedBox(width: 8),
            Text('Developer Menu'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.sync, color: Colors.blue),
              title: const Text('Run Migration'),
              onTap: () => Navigator.pop(context, 'migration'),
            ),
            ListTile(
              leading: const Icon(Icons.family_restroom, color: Colors.orange),
              title: const Text('Fix Family Link'),
              onTap: () => Navigator.pop(context, 'fix_family'),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report, color: Colors.grey),
              title: const Text('Debug User Info'),
              onTap: () => Navigator.pop(context, 'debug'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (result == 'migration') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MigrationScreen(),
        ),
      );
    } else if (result == 'fix_family') {
      await _showFixFamilyDialog(context, authService);
    } else if (result == 'debug') {
      // Show debug information
      final user = authService.currentUser;
      if (user != null) {
        UserModel? userModel;
        try {
          userModel = await authService.getCurrentUserModel();
        } catch (e) {
          Logger.warning('getCurrentUserModel failed (likely orphaned account)', error: e, tag: 'HomeScreen');
        }
        if (context.mounted) {
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('User Debug Info'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('User ID: ${user.uid}'),
                    const SizedBox(height: 8),
                    Text('Email: ${user.email ?? "N/A"}'),
                    const SizedBox(height: 8),
                    Text('Firebase Auth Display Name: ${user.displayName ?? "N/A"}'),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),
                    Text('User Document Exists: ${userModel != null ? "Yes" : "No"}'),
                    if (userModel != null) ...[
                      const SizedBox(height: 8),
                      Text('Firestore Display Name: ${userModel.displayName}'),
                      const SizedBox(height: 8),
                      Text('Family ID: ${userModel.familyId ?? "None"}'),
                      const SizedBox(height: 8),
                      Text('Created At: ${userModel.createdAt}'),
                    ] else ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          '⚠️ Orphaned Account: Auth account exists but Firestore document is missing.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await authService.forceInitializeFamilyId();
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('User document created/updated! Please refresh the app.'),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        final errorMsg = e.toString();
                        final isPermissionError = errorMsg.contains('permission-denied') || 
                                                  errorMsg.contains('permission denied');
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isPermissionError 
                                ? 'Permission denied. Please ensure Firestore rules are published in Firebase Console.'
                                : 'Error: $e'
                            ),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Fix User Document'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> _showJobsMenu(BuildContext context, AuthService authService) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.task, color: Colors.blue),
            SizedBox(width: 8),
            Text('Jobs'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.cleaning_services, color: Colors.orange),
              title: const Text('Cleanup Duplicates', style: TextStyle(color: Colors.orange)),
              onTap: () => Navigator.pop(context, 'cleanup'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Delete Duplicate Document', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, 'delete_duplicate'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep, color: Colors.red),
              title: const Text('Delete Duplicates by Task ID', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, 'delete_duplicate_by_id'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (result == 'cleanup') {
      // Handle cleanup
      final taskService = TaskService();
      try {
        await taskService.cleanupDuplicates();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Duplicates cleaned up'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } else if (result == 'delete_duplicate') {
      // Handle delete duplicate document
      if (context.mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Duplicate Document?'),
            content: const Text(
              'This will delete the duplicate document "WpIg6mn4ZGQvVpSFGLcX" '
              'that is causing the stuck task issue. This action cannot be undone.'
            ),
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
        if (confirm == true) {
          // Implementation would go here - need TaskService
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Delete duplicate document functionality needs to be implemented in TaskService'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } else if (result == 'delete_duplicate_by_id') {
      // Handle delete duplicates by task ID
      if (context.mounted) {
        final taskIdController = TextEditingController();
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Duplicates by Task ID'),
            content: TextField(
              controller: taskIdController,
              decoration: const InputDecoration(
                labelText: 'Task ID',
                hintText: 'Enter task ID to delete duplicates',
                border: OutlineInputBorder(),
              ),
            ),
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
        if (confirm == true && taskIdController.text.isNotEmpty) {
          // Implementation would go here - need TaskService
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Delete duplicates by task ID functionality needs to be implemented in TaskService'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
        taskIdController.dispose();
      }
    }
  }

  Future<void> _showAdminMenu(BuildContext context, AuthService authService) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.purple),
            SizedBox(width: 8),
            Text('Admin Menu'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.admin_panel_settings, color: Colors.blue),
              title: const Text('Manage Roles'),
              onTap: () => Navigator.pop(context, 'roles'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Reset Database', style: TextStyle(color: Colors.red)),
              onTap: () => Navigator.pop(context, 'reset'),
            ),
            ListTile(
              leading: const Icon(Icons.family_restroom, color: Colors.orange),
              title: const Text('Fix Family Link', style: TextStyle(color: Colors.orange)),
              onTap: () => Navigator.pop(context, 'fix_family'),
            ),
            ListTile(
              leading: const Icon(Icons.task, color: Colors.blue),
              title: const Text('Jobs', style: TextStyle(color: Colors.blue)),
              trailing: const Icon(Icons.chevron_right, size: 16),
              onTap: () => Navigator.pop(context, 'jobs'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );

    if (result == 'roles') {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const RoleManagementScreen(),
        ),
      );
    } else if (result == 'jobs') {
      await _showJobsMenu(context, authService);
    } else if (result == 'reset') {
      // Show warning before allowing database reset
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ Warning'),
          content: const Text(
            'Database Reset will permanently delete your account and all data. '
            'This is for development/testing only. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
      
      if (confirm == true && context.mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DatabaseResetScreen(),
          ),
        );
      }
    } else if (result == 'fix_family') {
      await _showFixFamilyDialog(context, authService);
    }
  }

  Future<void> _showFixFamilyDialog(BuildContext context, AuthService authService) async {
    // Capture outer context before showing dialog to avoid using invalid context after pop
    final outerContext = context;
    final emailController = TextEditingController();
    final familyIdController = TextEditingController();
    bool isLoading = false;
    String? kateFamilyId;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.family_restroom, color: Colors.orange),
              SizedBox(width: 8),
              Text('Fix Family Link'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will update your familyId to match Kate\'s family.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: "Kate's Email",
                    hintText: 'Enter Kate\'s email to find her familyId',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  enabled: !isLoading && kateFamilyId == null,
                ),
                const SizedBox(height: 8),
                if (kateFamilyId != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Found Kate\'s Family ID:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          kateFamilyId!,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: familyIdController,
                  decoration: const InputDecoration(
                    labelText: 'Or Enter Family ID Directly',
                    hintText: 'Paste family ID here',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.vpn_key),
                  ),
                  enabled: !isLoading,
                ),
                if (isLoading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: isLoading ? null : () async {
                if (emailController.text.isNotEmpty && kateFamilyId == null) {
                  // Find Kate's familyId by email
                  setState(() => isLoading = true);
                  try {
                    final familyId = await authService.getFamilyIdByEmail(emailController.text.trim());
                    setState(() {
                      isLoading = false;
                      kateFamilyId = familyId;
                    });
                    if (familyId == null) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('No user found with that email'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    } else {
                      familyIdController.text = familyId;
                    }
                  } catch (e) {
                    setState(() => isLoading = false);
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else if (familyIdController.text.isNotEmpty) {
                  // Update familyId directly
                  setState(() => isLoading = true);
                  try {
                    await authService.updateFamilyIdDirectly(familyIdController.text.trim());
                    // Close dialog first, then show snackbar using outer context
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    // Use outer context for snackbar after dialog is closed
                    if (outerContext.mounted) {
                      ScaffoldMessenger.of(outerContext).showSnackBar(
                        const SnackBar(
                          content: Text('Family ID updated! Please restart the app to see changes.'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 5),
                        ),
                      );
                    }
                  } catch (e) {
                    setState(() => isLoading = false);
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text('Error updating family ID: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                } else {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter Kate\'s email or family ID'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check),
              label: Text(kateFamilyId == null && emailController.text.isNotEmpty 
                  ? 'Find Family ID' 
                  : 'Update Family ID'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Dispose controllers when dialog is dismissed
      emailController.dispose();
      familyIdController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Scaffold(
          appBar: AppBar(
            title: const SizedBox.shrink(), // Empty title to make room for flexibleSpace
            centerTitle: true,
            flexibleSpace: SafeArea(
              child: Center(
                child: _hubsLoaded
                    ? _buildHubDropdown()
                    : const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
              ),
            ),
            actions: [
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) {
                  final items = <PopupMenuEntry>[
                    const PopupMenuItem(
                      value: 'invite',
                      child: Row(
                        children: [
                          Icon(Icons.person_add, size: 20),
                          SizedBox(width: 8),
                          Text('Invite Family'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'join',
                      child: Row(
                        children: [
                          Icon(Icons.group_add, size: 20),
                          SizedBox(width: 8),
                          Text('Join Family'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'profile',
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 20),
                          SizedBox(width: 8),
                          Text('Edit Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'calendar_sync',
                      child: Row(
                        children: [
                          Icon(Icons.sync, size: 20),
                          SizedBox(width: 8),
                          Text('Calendar Sync'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'privacy',
                      child: Row(
                        children: [
                          Icon(Icons.privacy_tip, size: 20),
                          SizedBox(width: 8),
                          Text('Privacy Center'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                  ];
                  
                  // Admin Menu
                  if (_isAdmin) {
                    items.add(
                      const PopupMenuItem(
                        value: 'admin_menu',
                        child: Row(
                          children: [
                            Icon(Icons.admin_panel_settings, size: 20, color: Colors.purple),
                            SizedBox(width: 8),
                            Text('Admin Menu', style: TextStyle(color: Colors.purple, fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Icon(Icons.chevron_right, size: 16),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  // Developer Menu
                  if (_isDeveloper) {
                    items.add(
                      const PopupMenuItem(
                        value: 'developer_menu',
                        child: Row(
                          children: [
                            Icon(Icons.code, size: 20, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Developer Menu', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Icon(Icons.chevron_right, size: 16),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  // UAT Testing Menu (for testers)
                  if (_isTester) {
                    items.add(
                      const PopupMenuItem(
                        value: 'uat_testing',
                        child: Row(
                          children: [
                            Icon(Icons.checklist, size: 20, color: Colors.teal),
                            SizedBox(width: 8),
                            Text('User Acceptance Testing', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                            SizedBox(width: 8),
                            Icon(Icons.chevron_right, size: 16),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  items.add(
                    const PopupMenuItem(
                      value: 'force_signout',
                      child: Row(
                        children: [
                          Icon(Icons.refresh, size: 20, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Refresh Session', style: TextStyle(color: Colors.blue)),
                        ],
                      ),
                    ),
                  );
                  
                  items.add(
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Logout', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  );
                  
                  return items;
                },
                onSelected: (value) async {
                  if (value == 'invite') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FamilyInvitationScreen(),
                      ),
                    );
                  } else if (value == 'join') {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const JoinFamilyScreen(),
                      ),
                    );
          // If successfully joined, refresh the app state
          if (result == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please restart the app to see family members'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else if (value == 'profile') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditProfileScreen(),
            ),
          );
        } else if (value == 'calendar_sync') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CalendarSyncSettingsScreen(),
            ),
          );
        } else if (value == 'privacy') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PrivacyCenterScreen(),
            ),
          );
        } else if (value == 'admin_menu') {
          await _showAdminMenu(context, authService);
        } else if (value == 'developer_menu') {
          await _showDeveloperMenu(context, authService);
        } else if (value == 'uat_testing') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const UATScreen(),
            ),
          );
        } else if (value == 'force_signout') {
                        // Force sign out to clear persisted session and refresh
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Refresh Session'),
                            content: const Text(
                              'This will sign you out and clear your session. '
                              'Use this if you\'re seeing an empty dashboard or missing data. '
                              'You\'ll need to sign back in after.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Sign Out & Refresh'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          await authService.signOut();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Signed out. Please sign back in.'),
                                backgroundColor: Colors.blue,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      } else if (value == 'logout') {
                        await authService.signOut();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Signed out successfully'),
                              backgroundColor: Colors.blue,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                  }
                },
              ),
            ],
          ),
          body: PageView(
            controller: _pageController,
            onPageChanged: (navIndex) {
              // navIndex is the navigation position, map to screen index
              if (navIndex >= 0 && navIndex < _navigationOrder.length) {
                final screenIndex = _navigationOrder[navIndex];
                appState.setCurrentIndex(screenIndex);
              }
            },
            children: _buildOrderedScreens(),
          ),
          bottomNavigationBar: ReorderableNavigationBar(
            selectedIndex: _navigationOrder.indexOf(appState.currentIndex), // Map screen index to nav position
            onDestinationSelected: (screenIndex) {
              // screenIndex is the actual screen index (0-6) from ReorderableNavigationBar
              // Find which navigation position this screen is at
              final navIndex = _navigationOrder.indexOf(screenIndex);
              if (navIndex >= 0 && navIndex < _navigationOrder.length) {
                appState.setCurrentIndex(screenIndex);
                if (_pageController.hasClients) {
                  _pageController.animateToPage(
                    navIndex,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                }
              }
            },
            onOrderChanged: (newOrder) {
              // Only update if order actually changed to prevent infinite recursion
              if (newOrder.toString() != _navigationOrder.toString()) {
                setState(() {
                  _navigationOrder = newOrder;
                });
                // PageView will rebuild with new order via _buildOrderedScreens()
              }
            },
            destinations: _buildOrderedDestinations(),
          ),
        );
      },
    );
  }
}

