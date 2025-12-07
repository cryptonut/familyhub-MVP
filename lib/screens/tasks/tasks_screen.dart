import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../../core/services/logger_service.dart';
import '../../models/task.dart';
import '../../models/user_model.dart';
import '../../services/task_service.dart';
import '../../services/app_state.dart';
import '../../providers/user_data_provider.dart';
import '../../utils/date_utils.dart' as app_date_utils;
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import '../../widgets/skeletons/skeleton_widgets.dart';
import '../../widgets/toast_notification.dart';
import '../../widgets/swipeable_list_item.dart';
import '../../widgets/context_menu.dart';
import '../../services/undo_service.dart';
import '../../services/task_dependency_service.dart';
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
  final UndoService _undoService = UndoService();
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
  bool _completedFiltersExpanded = false; // Collapsible state for completed filters

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    final initialIndex = widget.initialTabIndex ?? appState.tasksTabIndex ?? 0;
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialIndex);
    Logger.debug('initState: Initializing, loading tasks... (initialTabIndex: $initialIndex)', tag: 'TasksScreen');
    // Use post-frame callback to avoid setState during build
    // This prevents "setState() or markNeedsBuild() called during build" errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Clear the tasksTabIndex after using it - deferred to post-frame
      appState.clearTasksTabIndex();
      _loadTasks(forceRefresh: false); // Use cache for faster load
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
      // Defer clearTasksTabIndex to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        appState.clearTasksTabIndex();
      });
    }
    // Only reload if data is stale (older than 30 seconds)
    // This prevents unnecessary refreshes when navigating back to the screen
    if (appState.currentIndex == 2) {
      _loadTasks(forceRefresh: false); // Use cache, refresh in background if needed
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
      Logger.debug('_loadTasks: Loading tasks (forceRefresh: $forceRefresh)', tag: 'TasksScreen');
      final allTasks = await _taskService.getTasks(forceRefresh: forceRefresh);
      
      // Collect all unique user IDs (creators)
      final userIds = <String>{};
      Logger.debug('_loadTasks: Processing ${allTasks.length} tasks', tag: 'TasksScreen');
      for (var task in allTasks) {
        Logger.debug('  - Task "${task.title}" (${task.id}): createdBy=${task.createdBy}', tag: 'TasksScreen');
        if (task.createdBy != null && task.createdBy!.isNotEmpty) {
          userIds.add(task.createdBy!);
        } else {
          Logger.warning('    WARNING: Task has no createdBy field!', tag: 'TasksScreen');
        }
      }
      Logger.debug('_loadTasks: Found ${userIds.length} unique creator IDs: $userIds', tag: 'TasksScreen');
      
      // Fetch user names - use UserDataProvider first (cached family members), then batch fetch remaining
      final userNames = <String, String>{};
      Logger.debug('_loadTasks: Fetching names for ${userIds.length} unique creators', tag: 'TasksScreen');
      
      // Try to get names from UserDataProvider first (family members are cached)
      final userProvider = Provider.of<UserDataProvider>(context, listen: false);
      final familyMembers = userProvider.familyMembers;
      
      // Batch fetch remaining users not in family
      final usersToFetch = <String>[];
      for (var userId in userIds) {
        if (!_userNames.containsKey(userId)) {
          // Check family members first (most common case, already cached)
          final familyMember = familyMembers.firstWhere(
            (m) => m.uid == userId,
            orElse: () => UserModel(
              uid: '', 
              email: '', 
              displayName: '',
              createdAt: DateTime.now(),
              familyId: '',
            ),
          );
          
          if (familyMember.uid.isNotEmpty) {
            // Use cached family member name
            final name = familyMember.displayName.isNotEmpty 
                ? familyMember.displayName 
                : (familyMember.email.isNotEmpty 
                    ? familyMember.email.split('@').first 
                    : 'Unknown User');
            userNames[userId] = name;
          } else {
            usersToFetch.add(userId);
          }
        } else {
          // Use cached name
          userNames[userId] = _userNames[userId]!;
        }
      }
      
      // Batch fetch remaining users (parallel)
      if (usersToFetch.isNotEmpty) {
        final futures = usersToFetch.map((userId) async {
          try {
            final userModel = await userProvider.getUserModel(userId);
            if (userModel != null) {
              final name = userModel.displayName.isNotEmpty 
                  ? userModel.displayName 
                  : (userModel.email.isNotEmpty 
                      ? userModel.email.split('@').first 
                      : 'Unknown User');
              return MapEntry(userId, name);
            }
            return MapEntry(userId, 'Unknown User');
          } catch (e) {
            Logger.warning('_loadTasks: Error fetching user $userId', error: e, tag: 'TasksScreen');
            return MapEntry(userId, 'Unknown User');
          }
        });
        
        final results = await Future.wait(futures);
        for (var entry in results) {
          userNames[entry.key] = entry.value;
        }
      }
      
      Logger.debug('_loadTasks: Final user names map: $userNames', tag: 'TasksScreen');
      
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
      
      Logger.info('_loadTasks: Loaded ${active.length} active, ${completed.length} completed', tag: 'TasksScreen');
      
      if (mounted) {
        setState(() {
          _activeTasks = active;
          _completedTasks = completed;
        });
        Logger.debug('_loadTasks: State updated', tag: 'TasksScreen');
      } else {
        Logger.debug('_loadTasks: Widget not mounted, skipping setState', tag: 'TasksScreen');
      }
    } catch (e) {
      Logger.error('_loadTasks error', error: e, tag: 'TasksScreen');
      if (mounted) {
        ToastNotification.error(context, 'Error loading tasks: $e');
      }
    }
  }

  Future<void> _toggleTask(Task task) async {
    // Prevent multiple clicks on the same task
    if (_completingTaskIds.contains(task.id)) {
      Logger.debug('Task ${task.id} is already being completed, ignoring duplicate click', tag: 'TasksScreen');
      return;
    }
    
    // Check if job requires claim and hasn't been claimed
    if (task.requiresClaim && !task.isClaimed && !task.hasPendingClaim) {
      if (mounted) {
        ToastNotification.warning(context, 'This job must be claimed before it can be completed');
      }
      return;
    }
    
    // Special handling for the stuck task
    final isStuckTask = task.id == 'e237c1e4-90a6-4154-aaf9-eb4c4375663a';
    if (isStuckTask) {
      Logger.warning('Attempting to complete stuck task: ${task.id}', tag: 'TasksScreen');
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
        Logger.info('Using forceCompleteTask for stuck task ${task.id}', tag: 'TasksScreen');
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
          Logger.debug('Task ${task.id} completed and awaiting approval - correctly staying in active list', tag: 'TasksScreen');
          success = true;
          break;
        }
        
        // If task doesn't need approval or is approved, it should be in completed
        if (!updatedTask.isAwaitingApproval && updatedTask.isCompleted) {
          final stillActive = _activeTasks.any((t) => t.id == task.id);
          if (!stillActive) {
            Logger.info('Task ${task.id} successfully moved to completed after ${i + 1} refresh(es)', tag: 'TasksScreen');
            success = true;
            break;
          }
        }
        
        if (i == 4) {
          Logger.warning('Warning: Task ${task.id} still appears in active list after 5 refreshes', tag: 'TasksScreen');
        }
      }
      
      if (!success && mounted) {
        // If still not updated after retries, try force complete one more time
        if (isStuckTask) {
          Logger.warning('Retrying forceCompleteTask for stuck task ${task.id}', tag: 'TasksScreen');
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
        title: const SizedBox.shrink(), // Remove title - redundant with bottom navigation
        actions: [
          // Refresh button only - other items moved to Admin > Jobs menu
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () async {
              Logger.debug('Manual refresh triggered', tag: 'TasksScreen');
              await _loadTasks(forceRefresh: true);
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
            Logger.info('Task saved, refreshing list', tag: 'TasksScreen');
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search bar - improved contrast and submit icon
          SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'Search jobs...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                suffixIcon: _searchQuery.isNotEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.search,
                              size: 20,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            tooltip: 'Search',
                            onPressed: () {
                              // Trigger search (already handled by onChanged, but can add explicit search here)
                              setState(() {
                                // Search is already active via onChanged
                              });
                            },
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.clear,
                              size: 18,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _searchQuery = '';
                              });
                            },
                          ),
                        ],
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              onSubmitted: (value) {
                // Explicitly trigger search on submit
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(height: 6),
          // Filter chips - more compact
          Row(
            children: [
              Expanded(
                child: FilterChip(
                  label: Text(
                    'Priority: $_priorityFilter',
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: _priorityFilter != 'All',
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
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
              const SizedBox(width: 6),
              Expanded(
                child: FilterChip(
                  label: Text(
                    'Status: $_statusFilter',
                    style: const TextStyle(fontSize: 12),
                  ),
                  selected: _statusFilter != 'All',
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
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
        // Compact filter controls - collapsible
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: Colors.grey[50],
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Collapsible header
              InkWell(
                onTap: () {
                  setState(() {
                    _completedFiltersExpanded = !_completedFiltersExpanded;
                  });
                },
                child: Row(
                  children: [
                    Icon(
                      _completedFiltersExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: Colors.grey[700],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Filters',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: Colors.grey[700],
                      ),
                    ),
                    const Spacer(),
                    if (_completedFilter != 'Anyone' || _timePeriodFilter != 'All')
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Active',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // Expandable filter content
              if (_completedFiltersExpanded) ...[
                    const SizedBox(height: 8),
                    // Completer filter - more compact
                    Row(
                      children: [
                        Text(
                          'Completed by:',
                          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'Anyone',
                                label: Text('Anyone', style: TextStyle(fontSize: 11)),
                              ),
                              ButtonSegment(
                                value: 'Me',
                                label: Text('Me', style: TextStyle(fontSize: 11)),
                              ),
                            ],
                            selected: {_completedFilter},
                            style: const ButtonStyle(
                              padding: MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                              visualDensity: VisualDensity.compact,
                            ),
                            onSelectionChanged: (Set<String> newSelection) {
                              setState(() {
                                _completedFilter = newSelection.first;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Time period filter - more compact
                    Row(
                      children: [
                        Text(
                          'Time period:',
                          style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'Week',
                                label: Text('Week', style: TextStyle(fontSize: 10)),
                              ),
                              ButtonSegment(
                                value: 'Month',
                                label: Text('Month', style: TextStyle(fontSize: 10)),
                              ),
                              ButtonSegment(
                                value: '3 Months',
                                label: Text('3M', style: TextStyle(fontSize: 10)),
                              ),
                              ButtonSegment(
                                value: '1yr',
                                label: Text('1yr', style: TextStyle(fontSize: 10)),
                              ),
                              ButtonSegment(
                                value: 'All',
                                label: Text('All', style: TextStyle(fontSize: 10)),
                              ),
                            ],
                            selected: {_timePeriodFilter},
                            style: const ButtonStyle(
                              padding: MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 4, vertical: 4)),
                              visualDensity: VisualDensity.compact,
                            ),
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
    Logger.debug('_buildTasksList: Building list with ${tasks.length} tasks (isCompleted: $isCompleted)', tag: 'TasksScreen');
    
    if (tasks.isEmpty) {
      return EmptyState(
        icon: isCompleted ? Icons.check_circle_outline : Icons.assignment_outlined,
        title: isCompleted ? 'No completed jobs' : 'No active jobs',
        action: TextButton.icon(
          onPressed: () async {
            Logger.debug('Manual refresh from empty state', tag: 'TasksScreen');
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
        
        // Determine swipe actions based on task state
        final List<SwipeAction> leftActions = [];
        final List<SwipeAction> rightActions = [];
        
        if (!isCompleted && !task.requiresClaim) {
          // Swipe right to complete
          rightActions.add(
            SwipeAction(
              label: 'Complete',
              icon: Icons.check_circle,
              color: Colors.green,
              onTap: () => _toggleTask(task),
            ),
          );
        }
        
        if (isCreator) {
          // Swipe left to delete
          leftActions.add(
            SwipeAction(
              label: 'Delete',
              icon: Icons.delete,
              color: Colors.red,
              onTap: () => _deleteTask(task.id),
            ),
          );
        }
        
        return ContextMenu(
          actions: [
            if (!isCompleted)
              ContextMenuAction(
                label: 'Edit',
                icon: Icons.edit,
                onTap: () => _editTask(task),
              ),
            if (isCreator)
              ContextMenuAction(
                label: 'Delete',
                icon: Icons.delete,
                color: Colors.red,
                onTap: () => _deleteTaskWithUndo(task),
              ),
            ContextMenuAction(
              label: 'View Details',
              icon: Icons.info,
              onTap: () => _viewTaskDetails(task),
            ),
          ],
          child: SwipeableListItem(
            leftActions: leftActions,
            rightActions: rightActions,
            onTap: isCompleted
                ? () => _viewTaskDetails(task)
                : () => _editTask(task),
            child: ModernCard(
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
                      Logger.debug('_buildTasksList: Task ${task.id} createdBy=${task.createdBy}, name=$creatorName', tag: 'TasksScreen');
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
                Logger.debug('Building task menu for task ${task.id} (isStuckTask: $isStuckTask, isCompleted: $isCompleted)', tag: 'TasksScreen');
                
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
                
                Logger.debug('Task menu built with ${items.length} items', tag: 'TasksScreen');
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
                  Logger.debug('Task debug info: $info', tag: 'TasksScreen');
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
          ),
          ),
          ),
        );
      },
    );
  }

  Future<void> _editTask(Task task) async {
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
  }

  Future<void> _viewTaskDetails(Task task) async {
    await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            AddEditTaskScreen(task: task, readOnly: true),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  Future<void> _deleteTaskWithUndo(Task task) async {
    try {
      // Store task data for undo
      final taskData = task;
      
      // Delete the task
      await _taskService.deleteTask(task.id);
      await _loadTasks();
      
      // Register undo action
      _undoService.registerUndoableAction(
        'delete_task_${task.id}',
        () async {
          try {
            // Recreate task - would need a method to add task from Task object
            // For now, just show error
            ToastNotification.warning(context, 'Task restore not yet implemented');
          } catch (e) {
            ToastNotification.error(context, 'Error restoring task: $e');
          }
        },
      );
      
      // Show undo snackbar
      _undoService.showUndoSnackbar(
        context,
        message: 'Task deleted',
        actionId: 'delete_task_${task.id}',
      );
      
      ToastNotification.success(context, 'Task deleted');
    } catch (e) {
      ToastNotification.error(context, 'Error deleting task: $e');
    }
  }

  Future<bool> _isTaskBlocked(Task task) async {
    if (task.dependencies == null || task.dependencies!.isEmpty) {
      return false;
    }
    
    try {
      // Check if any dependency is incomplete
      final allTasks = await _taskService.getTasks();
      for (final depId in task.dependencies!) {
        final depTask = allTasks.firstWhere(
          (t) => t.id == depId,
          orElse: () => Task(
            id: depId,
            title: 'Unknown',
            description: '',
            createdAt: DateTime.now(),
            isCompleted: false,
          ),
        );
        if (!depTask.isCompleted) {
          return true; // Task is blocked
        }
      }
      return false; // All dependencies completed
    } catch (e) {
      Logger.error('Error checking task dependencies', error: e, tag: 'TasksScreen');
      return false;
    }
  }
}
