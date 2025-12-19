import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';

class MigrationScreen extends StatefulWidget {
  const MigrationScreen({super.key});

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  final AuthService _authService = AuthService();
  final TaskService _taskService = TaskService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String _status = 'Ready';
  List<String> _logs = [];
  bool _isRunning = false;
  int _tasksUpdated = 0;
  int _tasksSkipped = 0;
  int _tasksWithErrors = 0;

  Future<void> _runMigration() async {
    setState(() {
      _isRunning = true;
      _status = 'Running migration...';
      _logs.clear();
      _tasksUpdated = 0;
      _tasksSkipped = 0;
      _tasksWithErrors = 0;
    });

    try {
      final userModel = await _authService.getCurrentUserModel();
      if (userModel == null || userModel.familyId == null) {
        _addLog('Error: User not authenticated or not part of a family');
        setState(() {
          _status = 'Error: Not authenticated';
          _isRunning = false;
        });
        return;
      }

      final familyId = userModel.familyId!;
      final collectionPath = 'families/$familyId/tasks';
      
      _addLog('Starting migration for family: $familyId');
      _addLog('Collection path: $collectionPath');
      
      // Get all tasks
      final snapshot = await _firestore
          .collection(collectionPath)
          .get();
      
      _addLog('Found ${snapshot.docs.length} tasks');
      
      // Process each task
      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final isCompleted = data['isCompleted'] == true;
          final rewardValue = (data['reward'] as num?)?.toDouble() ?? 0.0;
          final hasReward = rewardValue > 0;
          
          // Only process completed tasks with rewards
          if (!isCompleted || !hasReward) {
            continue;
          }
          
          final assignedTo = data['assignedTo'] as String? ?? '';
          final claimedBy = data['claimedBy'] as String?;
          final needsApproval = data['needsApproval'] == true;
          final approvedBy = data['approvedBy'] as String?;
          final isAwaitingApproval = needsApproval && approvedBy == null;
          
          // Skip if already awaiting approval (not fully completed)
          if (isAwaitingApproval) {
            _addLog('Skipping task ${doc.id}: awaiting approval');
            _tasksSkipped++;
            continue;
          }
          
          // Check if we need to update this task
          bool needsUpdate = false;
          Map<String, dynamic> updateData = {};
          
          // If assignedTo is empty but claimedBy is set, use claimedBy
          if (assignedTo.isEmpty && claimedBy != null && claimedBy.isNotEmpty) {
            updateData['assignedTo'] = claimedBy;
            needsUpdate = true;
            _addLog('Task ${doc.id}: Setting assignedTo to claimedBy ($claimedBy)');
          }
          
          // If neither assignedTo nor claimedBy is set, we can't determine who completed it
          // In this case, we'll skip it (can't assign to unknown user)
          if (assignedTo.isEmpty && (claimedBy == null || claimedBy.isEmpty)) {
            _addLog('Task ${doc.id}: No completer info available, skipping');
            _tasksSkipped++;
            continue;
          }
          
          // Ensure claimedBy is set if assignedTo is set but claimedBy is not
          if (assignedTo.isNotEmpty && (claimedBy == null || claimedBy.isEmpty)) {
            updateData['claimedBy'] = assignedTo;
            needsUpdate = true;
            _addLog('Task ${doc.id}: Setting claimedBy to assignedTo ($assignedTo)');
          }
          
          // Update if needed
          if (needsUpdate) {
            await doc.reference.set(updateData, SetOptions(merge: true));
            _addLog('Task ${doc.id}: Updated successfully');
            _tasksUpdated++;
          } else {
            _addLog('Task ${doc.id}: Already has completer info, skipping');
            _tasksSkipped++;
          }
        } catch (e) {
          _addLog('Error processing task ${doc.id}: $e');
          _tasksWithErrors++;
        }
      }
      
      _addLog('');
      _addLog('Migration completed!');
      _addLog('Updated: $_tasksUpdated');
      _addLog('Skipped: $_tasksSkipped');
      _addLog('Errors: $_tasksWithErrors');
      
      setState(() {
        _status = 'Completed';
        _isRunning = false;
      });
    } catch (e) {
      _addLog('Migration error: $e');
      setState(() {
        _status = 'Error: $e';
        _isRunning = false;
      });
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add('${DateTime.now().toString().substring(11, 19)}: $message');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Migration Tool'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Task Migration Tool',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This tool will update existing completed tasks to ensure they have '
                      'proper completer information (assignedTo/claimedBy) for wallet transactions.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isRunning ? null : _runMigration,
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Run Migration'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          _status,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _isRunning 
                                ? Colors.orange 
                                : (_status == 'Completed' ? Colors.green : Colors.blue),
                          ),
                        ),
                      ],
                    ),
                    if (_tasksUpdated > 0 || _tasksSkipped > 0 || _tasksWithErrors > 0) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _buildStat('Updated', _tasksUpdated, Colors.green),
                          const SizedBox(width: 16),
                          _buildStat('Skipped', _tasksSkipped, Colors.orange),
                          const SizedBox(width: 16),
                          _buildStat('Errors', _tasksWithErrors, Colors.red),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Migration Log',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Card(
                child: _logs.isEmpty
                    ? const Center(
                        child: Text(
                          'No logs yet. Click "Run Migration" to start.',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              _logs[index],
                              style: const TextStyle(
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

