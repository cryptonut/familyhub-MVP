import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../services/app_state.dart';
import '../../utils/date_utils.dart' as app_date_utils;
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'add_edit_task_screen.dart';

class TasksScreen extends StatefulWidget {
  final int? initialTabIndex;
  
  const TasksScreen({super.key, this.initialTabIndex});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with TickerProviderStateMixin {
  final TaskService _taskService = TaskService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;
  List<Task> _activeTasks = [];
  List<Task> _completedTasks = [];
  final Set<String> _completingTaskIds = {}; // Track tasks being completed
  final Set<String> _claimingTaskIds = {}; // Track tasks being claimed
  final Set<String> _approvingTaskIds = {}; // Track tasks being approved
  Map<String, String> _userNames = {}; // Cache of user ID to display name
  
  // Search and filters
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _priorityFilter = 'All'; // 'All', 'High', 'Medium', 'Low'
  String _statusFilter = 'All'; // 'All', 'Open', 'Claimed', 'Completed'
  
  // Filters for completed jobs
  String _completedFilter = 'Anyone'; // 'Me' or 'Anyone'
  String _timePeriodFilter = 'All'; // 'Week', 'Month', '3 Months', '1yr', 'All'

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    final initialIndex = widget.initialTabIndex ?? appState.tasksTabIndex ?? 0;
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialIndex);
    debugPrint('TasksScreen.initState: Initializing, loading tasks... (initialTabIndex: $initialIndex)');
    // Clear familyId cache to ensure we have the latest value
    _taskService.clearFamilyIdCache();
    // Clear the tasksTabIndex after using it
    appState.clearTasksTabIndex();
    // Use a small delay to ensure widget is fully mounted
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTasks(forceRefresh: true);
      // Switch to the desired tab if specified
      if (initialIndex != 0 && _tabController.index != initialIndex) {
        _tabController.animateTo(initialIndex);
      }
    });
    
    // Listen to AppState changes to switch tabs when requested
    appState.addListener(_onAppStateChanged);
  }
  
  void _onAppStateChanged() {
    final appState = Provider.of<AppState>(context, listen: false);
    if (appState.tasksTabIndex != null && _tabController.index != appState.tasksTabIndex) {
      _tabController.animateTo(appState.tasksTabIndex!);
      appState.clearTasksTabIndex();
    }
    // Reload tasks when navigating to this screen (when currentIndex becomes 2)
    if (appState.currentIndex == 2) {
      _loadTasks(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    final appState = Provider.of<AppState>(context, listen: false);
    appState.removeListener(_onAppStateChanged);
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTasks({bool forceRefresh = false}) async {
    try {
      debugPrint('TasksScreen._loadTasks: Loading tasks (forceRefresh: $forceRefresh)');
      final allTasks = await _taskService.getTasks(forceRefresh: forceRefresh);
      
      // Collect all unique user IDs (creators)
      final userIds = <String>{};
      debugPrint('TasksScreen._loadTasks: Processing ${allTasks.length} tasks');
      for (var task in allTasks) {
        debugPrint('  - Task "${task.title}" (${task.id}): createdBy=${task.createdBy}');
        if (task.createdBy != null && task.createdBy!.isNotEmpty) {
          userIds.add(task.createdBy!);
        } else {
          debugPrint('    WARNING: Task has no createdBy field!');
        }
      }
      debugPrint('TasksScreen._loadTasks: Found ${userIds.length} unique creator IDs: $userIds');
      
      // Fetch user names for all creators
      final userNames = <String, String>{};
      debugPrint('TasksScreen._loadTasks: Fetching names for ${userIds.length} unique creators');
      for (var userId in userIds) {
        if (!_userNames.containsKey(userId)) {
          try {
            final userDoc = await _firestore.collection('users').doc(userId).get();
            if (userDoc.exists) {
              final userData = userDoc.data();
              debugPrint('TasksScreen._loadTasks: User document for $userId:');
              debugPrint('  - displayName: ${userData?['displayName']}');
              debugPrint('  - email: ${userData?['email']}');
              debugPrint('  - All fields: ${userData?.keys.toList()}');
              
              final displayName = userData?['displayName'] as String?;
              final email = userData?['email'] as String?;
              
              // Try displayName first (but skip if it's the default "User"), then email, then fallback
              String userName;
              if (displayName != null && 
                  displayName.isNotEmpty && 
                  displayName.toLowerCase() != 'user') {
                // Use displayName if it's not empty and not the default "User"
                userName = displayName;
                debugPrint('  - Using displayName: $userName');
              } else if (email != null && email.isNotEmpty) {
                // Extract name from email (part before @) and capitalize first letter
                final emailName = email.split('@').first;
                userName = emailName.isNotEmpty 
                    ? emailName[0].toUpperCase() + emailName.substring(1)
                    : 'Unknown User';
                debugPrint('  - Using email-derived name: $userName (from $email)');
              } else {
                userName = 'Unknown User';
                debugPrint('  - No valid name found, using fallback');
              }
              
              userNames[userId] = userName;
              debugPrint('  - Selected name: $userName');
            } else {
              debugPrint('TasksScreen._loadTasks: User document does not exist for $userId');
              userNames[userId] = 'Unknown User';
            }
          } catch (e) {
            debugPrint('TasksScreen._loadTasks: Error fetching user name for $userId: $e');
            userNames[userId] = 'Unknown User';
          }
        } else {
          // Use cached name
          userNames[userId] = _userNames[userId]!;
          debugPrint('TasksScreen._loadTasks: Using cached name for $userId: ${_userNames[userId]}');
        }
      }
      
      debugPrint('TasksScreen._loadTasks: Final user names map: $userNames');
      
      // Update cache
      _userNames.addAll(userNames);
      
      // Filter tasks: active includes incomplete tasks AND completed tasks awaiting approval
      final active = allTasks.where((task) {
        if (!task.isCompleted) return true;
        // Include completed tasks that need approval but haven't been approved yet
        return task.isAwaitingApproval;
      }).toList();
      
      // Completed tasks are those that are completed and either don't need approval or have been approved
      final completed = allTasks.where((task) {
        if (!task.isCompleted) return false;
        // Exclude tasks awaiting approval
        return !task.isAwaitingApproval;
      }).toList();
      
      debugPrint('TasksScreen._loadTasks: Loaded ${active.length} active, ${completed.length} completed');
      
      if (mounted) {
        setState(() {
          _activeTasks = active;
          _completedTasks = completed;
        });
        debugPrint('TasksScreen._loadTasks: State updated');
      } else {
        debugPrint('TasksScreen._loadTasks: Widget not mounted, skipping setState');
      }
    } catch (e) {
      debugPrint('TasksScreen._loadTasks error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading tasks: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleTask(Task task) async {
    // Prevent multiple clicks on the same task
    if (_completingTaskIds.contains(task.id)) {
      debugPrint('Task ${task.id} is already being completed, ignoring duplicate click');
      return;
    }
    
    // Check if job requires claim and hasn't been claimed
    if (task.requiresClaim && !task.isClaimed && !task.hasPendingClaim) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This job must be claimed before it can be completed'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    // Special handling for the stuck task
    final isStuckTask = task.id == 'e237c1e4-90a6-4154-aaf9-eb4c4375663a';
    if (isStuckTask) {
      debugPrint('Attempting to complete stuck task: ${task.id}');
    }
    
    // Mark task as being completed
    setState(() {
      _completingTaskIds.add(task.id);
      // Optimistically update UI - only remove from active if it doesn't need approval
      // Jobs needing approval should stay in active list until approved
      if (!task.needsApproval) {
        _activeTasks = _activeTasks.where((t) => t.id != task.id).toList();
      }
    });
    
    try {
      // For stuck tasks, try force complete first
      if (isStuckTask) {
        debugPrint('Using forceCompleteTask for stuck task ${task.id}');
        await _taskService.forceCompleteTask(task.id);
      } else {
        // Use completeTask instead of toggleTaskCompletion to avoid race conditions
        // Since "Job Done!" button only appears on active tasks, we always set to completed
        await _taskService.completeTask(task.id);
      }
      
      // Retry mechanism: wait and refresh multiple times to ensure we get the update
      bool success = false;
      for (int i = 0; i < 5; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        await _loadTasks(forceRefresh: true);
        
        // Check if the task is no longer in active list (meaning it's now completed and approved, or doesn't need approval)
        // OR if it's awaiting approval (which is fine - it should stay in active)
        final updatedTask = _activeTasks.firstWhere(
          (t) => t.id == task.id,
          orElse: () => _completedTasks.firstWhere(
            (t) => t.id == task.id,
            orElse: () => task,
          ),
        );
        
        // If task needs approval and is completed, it should stay in active (awaiting approval)
        if (task.needsApproval && updatedTask.isCompleted && updatedTask.isAwaitingApproval) {
          debugPrint('Task ${task.id} completed and awaiting approval - correctly staying in active list');
          success = true;
          break;
        }
        
        // If task doesn't need approval or is approved, it should be in completed
        if (!updatedTask.isAwaitingApproval && updatedTask.isCompleted) {
          final stillActive = _activeTasks.any((t) => t.id == task.id);
          if (!stillActive) {
            debugPrint('Task ${task.id} successfully moved to completed after ${i + 1} refresh(es)');
            success = true;
            break;
          }
        }
        
        if (i == 4) {
          debugPrint('Warning: Task ${task.id} still appears in active list after 5 refreshes');
        }
      }
      
      if (!success && mounted) {
        // If still not updated after retries, try force complete one more time
        if (isStuckTask) {
          debugPrint('Retrying forceCompleteTask for stuck task ${task.id}');
          await _taskService.forceCompleteTask(task.id);
          await Future.delayed(const Duration(milliseconds: 500));
          await _loadTasks(forceRefresh: true);
        } else {
          // If still not updated after retries, force one more refresh
          await Future.delayed(const Duration(milliseconds: 500));
          await _loadTasks(forceRefresh: true);
        }
      }
    } catch (e) {
      // If update fails, restore the task to the active list
      if (mounted) {
        setState(() {
          _activeTasks = [..._activeTasks, task];
          _activeTasks.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        });
        // Show error to user
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error completing job: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      // Remove from completing set
      if (mounted) {
        setState(() {
          _completingTaskIds.remove(task.id);
        });
      }
    }
  }

  Future<void> _deleteTask(String taskId) async {
    await _taskService.deleteTask(taskId);
    _loadTasks();
  }
  
  Future<void> _claimJob(Task task) async {
    if (_claimingTaskIds.contains(task.id)) return;
    
    setState(() {
      _claimingTaskIds.add(task.id);
    });
    
    try {
      await _taskService.claimJob(task.id);
      await _loadTasks(forceRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job claim submitted. Waiting for approval.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error claiming job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _claimingTaskIds.remove(task.id);
        });
      }
    }
  }
  
  Future<void> _approveClaim(Task task) async {
    if (task.claimedBy == null) return;
    
    try {
      await _taskService.approveClaim(task.id, task.claimedBy!);
      await _loadTasks(forceRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim approved'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving claim: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _rejectClaim(Task task) async {
    try {
      await _taskService.rejectClaim(task.id);
      await _loadTasks(forceRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Claim rejected'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error rejecting claim: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Future<void> _approveJob(Task task) async {
    if (_approvingTaskIds.contains(task.id)) return;
    
    setState(() {
      _approvingTaskIds.add(task.id);
    });
    
    try {
      await _taskService.approveJob(task.id);
      await _loadTasks(forceRefresh: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Job approved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error approving job: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _approvingTaskIds.remove(task.id);
        });
      }
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
  
  Widget _buildLeadingWidget(Task task, bool isCompleted) {
    final currentUserId = _auth.currentUser?.uid;
    final isCreator = task.createdBy == currentUserId;
    final isClaimer = task.claimedBy == currentUserId;
    
    // If completed and approved, show checkmark
    if (isCompleted && !task.isAwaitingApproval) {
      return const Icon(Icons.check_circle, color: Colors.green, size: 28);
    }
    
    // If awaiting approval
    if (task.isAwaitingApproval) {
      if (isCreator) {
        // Creator sees "Approve Job?" button
        if (_approvingTaskIds.contains(task.id)) {
          return const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }
        return ElevatedButton.icon(
          onPressed: () => _approveJob(task),
          icon: const Icon(Icons.thumb_up, size: 18),
          label: const Text('Approve Job?'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        );
      } else {
        // Others see "Awaiting Approval"
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Awaiting\nApproval',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
            textAlign: TextAlign.center,
          ),
        );
      }
    }
    
    // If completing, show loading
    if (_completingTaskIds.contains(task.id)) {
      return const SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    
    // If not completed, show appropriate button based on claim status
    if (task.hasPendingClaim && isCreator) {
      // Creator sees approve/reject claim buttons - show in menu instead
      return ElevatedButton.icon(
        onPressed: () => _toggleTask(task),
        icon: const Icon(Icons.check_circle, size: 18),
        label: const Text('Job Done!'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      );
    } else if (!task.isClaimed && !task.hasPendingClaim) {
      // Not claimed - check if claim is required
      if (task.requiresClaim && !isCreator) {
        // Job requires claim but hasn't been claimed - don't show "Job Done!" button (unless creator)
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Text(
            'Must Claim\nFirst',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
            textAlign: TextAlign.center,
          ),
        );
      }
      // Not claimed and doesn't require claim - anyone (including creator) can complete
      return ElevatedButton.icon(
        onPressed: () => _toggleTask(task),
        icon: const Icon(Icons.check_circle, size: 18),
        label: const Text('Job Done!'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      );
    } else {
      // Claimed or other status - can complete
      return ElevatedButton.icon(
        onPressed: () => _toggleTask(task),
        icon: const Icon(Icons.check_circle, size: 18),
        label: const Text('Job Done!'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobs'),
        actions: [
          PopupMenuButton(
            icon: const Icon(Icons.more_vert),
            itemBuilder: (context) {
              debugPrint('TasksScreen: Building AppBar menu with 4 items');
              return [
                const PopupMenuItem(
                  value: 'refresh',
                  child: Row(
                    children: [
                      Icon(Icons.refresh),
                      SizedBox(width: 8),
                      Text('Refresh'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'cleanup',
                  child: Row(
                    children: [
                      Icon(Icons.cleaning_services, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Cleanup Duplicates', style: TextStyle(color: Colors.orange)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete_duplicate',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Duplicate Document', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete_duplicate_by_id',
                  child: Row(
                    children: [
                      Icon(Icons.delete_sweep, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete Duplicates by Task ID', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ];
            },
            onSelected: (value) async {
              debugPrint('TasksScreen: AppBar menu selected: $value');
              if (value == 'refresh') {
                debugPrint('TasksScreen: Manual refresh triggered');
                await _loadTasks(forceRefresh: true);
              } else if (value == 'cleanup') {
                try {
                  await _taskService.cleanupDuplicates();
                  await Future.delayed(const Duration(milliseconds: 500));
                  await _loadTasks(forceRefresh: true);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Duplicates cleaned up'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } else if (value == 'delete_duplicate') {
                // Delete the specific duplicate document by document ID
                if (mounted) {
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
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirm == true) {
                    try {
                      await _taskService.deleteDocumentByDocId('WpIg6mn4ZGQvVpSFGLcX');
                      await Future.delayed(const Duration(milliseconds: 1000));
                      await _loadTasks(forceRefresh: true);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Duplicate document deleted'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error deleting: $e'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  }
                }
              } else if (value == 'delete_duplicate_by_id') {
                // Delete duplicates by querying for the task ID
                if (mounted) {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Duplicates by Task ID?'),
                      content: const Text(
                        'This will find and delete all duplicate documents for task ID '
                        '"e237c1e4-90a6-4154-aaf9-eb4c4375663a" (keeping only the one where '
                        'document ID matches task ID). This action cannot be undone.'
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  
                  if (confirm == true) {
                    try {
                      await _taskService.deleteDuplicateByTaskId('e237c1e4-90a6-4154-aaf9-eb4c4375663a');
                      await Future.delayed(const Duration(milliseconds: 1000));
                      await _loadTasks(forceRefresh: true);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Duplicates deleted'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error deleting: $e'),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 5),
                          ),
                        );
                      }
                    }
                  }
                }
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Active', icon: Icon(Icons.assignment)),
            Tab(text: 'Completed', icon: Icon(Icons.check_circle)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search and filter bar
          _buildSearchAndFilterBar(),
          // Tasks list
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTasksList(_getFilteredActiveTasks(), false),
                _buildCompletedTasksList(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'tasks-fab',
        onPressed: () async {
          final result = await Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  const AddEditTaskScreen(),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
          if (result == true) {
            debugPrint('TasksScreen: Task saved, refreshing list');
            // Wait a moment for Firestore to process, then force refresh
            await Future.delayed(const Duration(milliseconds: 500));
            await _loadTasks(forceRefresh: true);
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Job created successfully!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search jobs...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey.shade100,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          // Filter chips
          Row(
            children: [
              Expanded(
                child: FilterChip(
                  label: Text('Priority: $_priorityFilter'),
                  selected: _priorityFilter != 'All',
                  onSelected: (selected) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Filter by Priority'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: ['All', 'High', 'Medium', 'Low']
                              .map((priority) => ListTile(
                                    title: Text(priority),
                                    trailing: _priorityFilter == priority
                                        ? const Icon(Icons.check)
                                        : null,
                                    onTap: () {
                                      setState(() {
                                        _priorityFilter = priority;
                                      });
                                      Navigator.pop(context);
                                    },
                                  ))
                              .toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilterChip(
                  label: Text('Status: $_statusFilter'),
                  selected: _statusFilter != 'All',
                  onSelected: (selected) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Filter by Status'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: ['All', 'Open', 'Claimed', 'Completed']
                              .map((status) => ListTile(
                                    title: Text(status),
                                    trailing: _statusFilter == status
                                        ? const Icon(Icons.check)
                                        : null,
                                    onTap: () {
                                      setState(() {
                                        _statusFilter = status;
                                      });
                                      Navigator.pop(context);
                                    },
                                  ))
                              .toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Task> _getFilteredActiveTasks() {
    var filtered = List<Task>.from(_activeTasks);
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((task) {
        final titleMatch = task.title.toLowerCase().contains(query);
        final descMatch = task.description.toLowerCase().contains(query);
        final creatorName = _userNames[task.createdBy] ?? '';
        final creatorMatch = creatorName.toLowerCase().contains(query);
        return titleMatch || descMatch || creatorMatch;
      }).toList();
    }
    
    // Filter by priority
    if (_priorityFilter != 'All') {
      filtered = filtered.where((task) {
        return task.priority.toLowerCase() == _priorityFilter.toLowerCase();
      }).toList();
    }
    
    // Filter by status
    if (_statusFilter != 'All') {
      filtered = filtered.where((task) {
        switch (_statusFilter) {
          case 'Open':
            return !task.isClaimed && !task.hasPendingClaim;
          case 'Claimed':
            return task.isClaimed || task.hasPendingClaim;
          case 'Completed':
            return task.isCompleted;
          default:
            return true;
        }
      }).toList();
    }
    
    return filtered;
  }

  List<Task> _getFilteredCompletedTasks() {
    final currentUserId = _auth.currentUser?.uid;
    var filtered = List<Task>.from(_completedTasks);
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filtered = filtered.where((task) {
        final titleMatch = task.title.toLowerCase().contains(query);
        final descMatch = task.description.toLowerCase().contains(query);
        final creatorName = _userNames[task.createdBy] ?? '';
        final creatorMatch = creatorName.toLowerCase().contains(query);
        return titleMatch || descMatch || creatorMatch;
      }).toList();
    }
    
    // Filter by priority
    if (_priorityFilter != 'All') {
      filtered = filtered.where((task) {
        return task.priority.toLowerCase() == _priorityFilter.toLowerCase();
      }).toList();
    }
    
    // Filter by completer
    if (_completedFilter == 'Me' && currentUserId != null) {
      filtered = filtered.where((task) {
        return (task.claimedBy == currentUserId || task.assignedTo == currentUserId);
      }).toList();
    }
    
    // Filter by time period
    final now = DateTime.now();
    DateTime? cutoffDate;
    switch (_timePeriodFilter) {
      case 'Week':
        cutoffDate = now.subtract(const Duration(days: 7));
        break;
      case 'Month':
        cutoffDate = now.subtract(const Duration(days: 30));
        break;
      case '3 Months':
        cutoffDate = now.subtract(const Duration(days: 90));
        break;
      case '1yr':
        cutoffDate = now.subtract(const Duration(days: 365));
        break;
      case 'All':
      default:
        cutoffDate = null;
        break;
    }
    
    if (cutoffDate != null) {
      filtered = filtered.where((task) {
        final taskDate = task.completedAt ?? task.createdAt;
        return taskDate.isAfter(cutoffDate!);
      }).toList();
    }
    
    return filtered;
  }

  Widget _buildCompletedTasksList() {
    final filteredTasks = _getFilteredCompletedTasks();
    
    return Column(
      children: [
        // Filter controls
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.grey[100],
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.filter_list, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Filters:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Completer filter
              Row(
                children: [
                  const Text('Completed by: '),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Anyone', label: Text('Anyone')),
                        ButtonSegment(value: 'Me', label: Text('Me')),
                      ],
                      selected: {_completedFilter},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _completedFilter = newSelection.first;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Time period filter
              Row(
                children: [
                  const Text('Time period: '),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Week', label: Text('Week')),
                        ButtonSegment(value: 'Month', label: Text('Month')),
                        ButtonSegment(value: '3 Months', label: Text('3M')),
                        ButtonSegment(value: '1yr', label: Text('1yr')),
                        ButtonSegment(value: 'All', label: Text('All')),
                      ],
                      selected: {_timePeriodFilter},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _timePeriodFilter = newSelection.first;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Tasks list
        Expanded(
          child: _buildTasksList(filteredTasks, true),
        ),
      ],
    );
  }

  Widget _buildTasksList(List<Task> tasks, bool isCompleted) {
    debugPrint('_buildTasksList: Building list with ${tasks.length} tasks (isCompleted: $isCompleted)');
    
    if (tasks.isEmpty) {
      return EmptyState(
        icon: isCompleted ? Icons.check_circle_outline : Icons.assignment_outlined,
        title: isCompleted ? 'No completed jobs' : 'No active jobs',
        action: TextButton.icon(
          onPressed: () async {
            debugPrint('Manual refresh from empty state');
            await _loadTasks(forceRefresh: true);
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final currentUserId = _auth.currentUser?.uid;
        final isCreator = task.createdBy == currentUserId;
        final isClaimer = task.claimedBy == currentUserId;
        final canClaim = !isCreator && !task.isClaimed && !task.hasPendingClaim;
        
        return ModernCard(
          margin: const EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: _buildLeadingWidget(task, isCompleted),
            title: Text(
              task.title,
              style: TextStyle(
                decoration: task.isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Creator name
                if (task.createdBy != null && task.createdBy!.isNotEmpty) ...[
                  Builder(
                    builder: (context) {
                      final creatorName = _userNames[task.createdBy] ?? 'Unknown';
                      debugPrint('TasksScreen._buildTasksList: Task ${task.id} createdBy=${task.createdBy}, name=$creatorName');
                      return Row(
                        children: [
                          Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Created by: $creatorName',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 4),
                ],
                if (task.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(task.description),
                ],
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    // Reward badge
                    if (task.reward != null && task.reward! > 0) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.attach_money, size: 14, color: Colors.green),
                            const SizedBox(width: 4),
                            Text(
                              '${task.reward!.toStringAsFixed(2)} AUD',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Priority badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getPriorityColor(task.priority).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        task.priority.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _getPriorityColor(task.priority),
                        ),
                      ),
                    ),
                    // Due date
                    if (task.dueDate != null) ...[
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            app_date_utils.AppDateUtils.formatDate(task.dueDate!),
                            style: TextStyle(
                              fontSize: 12,
                              color: task.dueDate!.isBefore(DateTime.now()) &&
                                      !task.isCompleted
                                  ? Colors.red
                                  : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                    // Claim status
                    if (task.hasPendingClaim) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pending, size: 14, color: Colors.blue),
                            SizedBox(width: 4),
                            Text(
                              'Claim Pending',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue),
                            ),
                          ],
                        ),
                      ),
                    ] else if (task.isClaimed) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.purple.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person, size: 14, color: Colors.purple),
                            SizedBox(width: 4),
                            Text(
                              'Claimed',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                // Claim button for non-creators
                if (canClaim && !isCompleted) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: _claimingTaskIds.contains(task.id)
                        ? const Center(child: CircularProgressIndicator())
                        : OutlinedButton.icon(
                            onPressed: () => _claimJob(task),
                            icon: const Icon(Icons.handshake, size: 18),
                            label: const Text('Claim Job'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.blue,
                            ),
                          ),
                  ),
                ],
              ],
            ),
            trailing: PopupMenuButton(
              itemBuilder: (context) {
                final items = <PopupMenuItem>[];
                final isStuckTask = task.id == 'e237c1e4-90a6-4154-aaf9-eb4c4375663a';
                debugPrint('TasksScreen: Building task menu for task ${task.id} (isStuckTask: $isStuckTask, isCompleted: $isCompleted)');
                
                if (!isCompleted) {
                  items.add(
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
                  );
                }
                
                // Approve/Reject claim options (only for creator)
                if (isCreator && task.hasPendingClaim && !isCompleted) {
                  items.add(
                    const PopupMenuItem(
                      value: 'approve_claim',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, size: 20, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Approve Claim', style: TextStyle(color: Colors.green)),
                        ],
                      ),
                    ),
                  );
                  items.add(
                    const PopupMenuItem(
                      value: 'reject_claim',
                      child: Row(
                        children: [
                          Icon(Icons.cancel, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Reject Claim', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  );
                }
                
                // Special option for stuck task
                if (isStuckTask && !isCompleted) {
                  items.add(
                    const PopupMenuItem(
                      value: 'force_complete',
                      child: Row(
                        children: [
                          Icon(Icons.build, size: 20, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Force Complete', style: TextStyle(color: Colors.orange)),
                        ],
                      ),
                    ),
                  );
                }
                
                if (isStuckTask) {
                  items.add(
                    const PopupMenuItem(
                      value: 'debug',
                      child: Row(
                        children: [
                          Icon(Icons.bug_report, size: 20, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('Debug Info', style: TextStyle(color: Colors.blue)),
                        ],
                      ),
                    ),
                  );
                }
                
                if (isStuckTask) {
                  items.add(
                    const PopupMenuItem(
                      value: 'delete_stuck',
                      child: Row(
                        children: [
                          Icon(Icons.delete_forever, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Stuck Task', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  );
                }
                
                if (isStuckTask) {
                  items.add(
                    const PopupMenuItem(
                      value: 'delete_duplicate_doc',
                      child: Row(
                        children: [
                          Icon(Icons.delete_sweep, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete Duplicate Doc', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  );
                }
                
                if (isStuckTask) {
                  items.add(
                    const PopupMenuItem(
                      value: 'delete_duplicates_by_id',
                      child: Row(
                        children: [
                          Icon(Icons.cleaning_services, size: 20, color: Colors.orange),
                          SizedBox(width: 8),
                          Text('Delete All Duplicates', style: TextStyle(color: Colors.orange)),
                        ],
                      ),
                    ),
                  );
                }
                
                items.add(
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
                );
                
                debugPrint('TasksScreen: Task menu built with ${items.length} items');
                return items;
              },
              onSelected: (value) async {
                if (value == 'edit') {
                  final result = await Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          AddEditTaskScreen(task: task),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                    ),
                  );
                  if (result == true) {
                    _loadTasks();
                  }
                } else if (value == 'approve_claim') {
                  _approveClaim(task);
                } else if (value == 'reject_claim') {
                  _rejectClaim(task);
                } else if (value == 'force_complete') {
                  // Force complete the stuck task
                  try {
                    await _taskService.forceCompleteTask(task.id);
                    await Future.delayed(const Duration(milliseconds: 500));
                    await _loadTasks(forceRefresh: true);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Force complete attempted. Check console for details.'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else if (value == 'debug') {
                  // Show debug info
                  final info = await _taskService.getTaskInfo(task.id);
                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Task Debug Info'),
                        content: SingleChildScrollView(
                          child: Text(
                            info?.toString() ?? 'No info available',
                            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  }
                  debugPrint('Task debug info: $info');
                } else if (value == 'delete_stuck') {
                  // Delete the stuck task
                  if (mounted) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Stuck Task?'),
                        content: const Text('This will permanently delete the stuck task. This action cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      try {
                        await _taskService.deleteStuckTask(task.id);
                        await _loadTasks(forceRefresh: true);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Stuck task deleted'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error deleting: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  }
                } else if (value == 'delete_duplicate_doc') {
                  // Delete the specific duplicate document
                  if (mounted) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete Duplicate Document?'),
                        content: const Text(
                          'This will delete the duplicate document "WpIg6mn4ZGQvVpSFGLcX". '
                          'This action cannot be undone.'
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      try {
                        await _taskService.deleteDocumentByDocId('WpIg6mn4ZGQvVpSFGLcX');
                        await Future.delayed(const Duration(milliseconds: 1000));
                        await _loadTasks(forceRefresh: true);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Duplicate document deleted'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  }
                } else if (value == 'delete_duplicates_by_id') {
                  // Delete all duplicates for this task ID
                  if (mounted) {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete All Duplicates?'),
                        content: const Text(
                          'This will find and delete all duplicate documents for this task ID '
                          '(keeping only the one where document ID matches task ID). '
                          'This action cannot be undone.'
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                    
                    if (confirm == true) {
                      try {
                        await _taskService.deleteDuplicateByTaskId(task.id);
                        await Future.delayed(const Duration(milliseconds: 1000));
                        await _loadTasks(forceRefresh: true);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Duplicates deleted'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  }
                } else if (value == 'delete') {
                  _deleteTask(task.id);
                }
              },
            ),
            onTap: isCompleted
                ? null
                : () async {
                    final result = await Navigator.push(
                      context,
                      PageRouteBuilder(
                        pageBuilder: (context, animation, secondaryAnimation) =>
                            AddEditTaskScreen(task: task),
                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                          return FadeTransition(opacity: animation, child: child);
                        },
                      ),
                    );
                    if (result == true) {
                      _loadTasks();
                    }
                  },
          ),
        );
      },
    );
  }
}
