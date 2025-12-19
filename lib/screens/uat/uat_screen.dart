import 'package:flutter/material.dart';
import '../../services/uat_service.dart';
import '../../core/services/logger_service.dart';
import '../../utils/date_utils.dart' as app_date_utils;
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';

class UATScreen extends StatefulWidget {
  const UATScreen({super.key});

  @override
  State<UATScreen> createState() => _UATScreenState();
}

class _UATScreenState extends State<UATScreen> {
  final _uatService = UATService();
  List<UATTestRound> _testRounds = [];
  String? _selectedRoundId;
  List<UATTestCase> _testCases = [];
  Map<String, List<UATSubTestCase>> _subTestCases = {};
  Map<String, bool> _expandedCases = {};
  bool _isLoading = true;
  bool _isTester = false;
  bool _canManageTestCases = false;

  @override
  void initState() {
    super.initState();
    _checkTesterStatus();
  }

  Future<void> _checkTesterStatus() async {
    try {
      final tester = await _uatService.isTester();
      final canManage = await _uatService.canManageTestCases();
      if (mounted) {
        setState(() {
          _isTester = tester;
          _canManageTestCases = canManage;
        });
        if (tester) {
          _loadTestRounds();
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      Logger.error('Error checking tester status', error: e, tag: 'UATScreen');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTestRounds() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final rounds = await _uatService.getTestRounds();
      if (mounted) {
        setState(() {
          _testRounds = rounds;
          if (rounds.isNotEmpty && _selectedRoundId == null) {
            _selectedRoundId = rounds.first.id;
            _loadTestCases(rounds.first.id);
          } else if (_selectedRoundId != null) {
            _loadTestCases(_selectedRoundId!);
          } else {
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      Logger.error('Error loading test rounds', error: e, tag: 'UATScreen');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTestCases(String roundId) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final cases = await _uatService.getTestCases(roundId);
      final subCasesMap = <String, List<UATSubTestCase>>{};

      // Load sub-test cases for each test case
      for (final testCase in cases) {
        final subCases = await _uatService.getSubTestCases(roundId, testCase.id);
        subCasesMap[testCase.id] = subCases;
      }

      if (mounted) {
        setState(() {
          _testCases = cases;
          _subTestCases = subCasesMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      Logger.error('Error loading test cases', error: e, tag: 'UATScreen');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _markAsPassed(String testCaseId, {String? subTestCaseId}) async {
    if (_selectedRoundId == null) return;

    try {
      await _uatService.markAsPassed(
        roundId: _selectedRoundId!,
        testCaseId: testCaseId,
        subTestCaseId: subTestCaseId,
      );
      await _loadTestCases(_selectedRoundId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test marked as passed'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      Logger.error('Error marking test as passed', error: e, tag: 'UATScreen');
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

  Future<void> _markAsFailed(String testCaseId, {String? subTestCaseId}) async {
    if (_selectedRoundId == null) return;

    try {
      await _uatService.markAsFailed(
        roundId: _selectedRoundId!,
        testCaseId: testCaseId,
        subTestCaseId: subTestCaseId,
      );
      await _loadTestCases(_selectedRoundId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Test marked as failed'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      Logger.error('Error marking test as failed', error: e, tag: 'UATScreen');
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

  void _showTestCaseDetails(UATTestCase testCase) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Test Case ${testCase.number}: ${testCase.title}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (testCase.description.isNotEmpty) ...[
                const Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(testCase.description),
                const SizedBox(height: 16),
              ],
              if (testCase.feature != null && testCase.feature!.isNotEmpty) ...[
                const Text(
                  'Feature:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(testCase.feature!),
                const SizedBox(height: 16),
              ],
              if (testCase.test != null && testCase.test!.isNotEmpty) ...[
                const Text(
                  'Test Steps:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(testCase.test!),
                const SizedBox(height: 16),
              ],
              if (testCase.testedBy != null) ...[
                const Divider(),
                Text('Status: ${testCase.status.toUpperCase()}'),
                Text('Tested by: ${testCase.testedBy}'),
                if (testCase.testedAt != null)
                  Text('Tested at: ${app_date_utils.AppDateUtils.formatDateTime(testCase.testedAt!)}'),
              ],
            ],
          ),
        ),
        actions: [
          if (!testCase.isLocked) ...[
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _markAsFailed(testCase.id);
              },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Fail'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: BorderSide(color: AppTheme.errorColor),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _markAsPassed(testCase.id);
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Pass'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSubTestCaseDetails(UATSubTestCase subTestCase, String testCaseId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Sub-Test ${subTestCase.number}: ${subTestCase.title}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (subTestCase.description.isNotEmpty) ...[
                const Text(
                  'Description:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(subTestCase.description),
                const SizedBox(height: 16),
              ],
              if (subTestCase.feature != null && subTestCase.feature!.isNotEmpty) ...[
                const Text(
                  'Feature:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(subTestCase.feature!),
                const SizedBox(height: 16),
              ],
              if (subTestCase.test != null && subTestCase.test!.isNotEmpty) ...[
                const Text(
                  'Test Steps:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(subTestCase.test!),
                const SizedBox(height: 16),
              ],
              if (subTestCase.testedBy != null) ...[
                const Divider(),
                Text('Status: ${subTestCase.status.toUpperCase()}'),
                Text('Tested by: ${subTestCase.testedBy}'),
                if (subTestCase.testedAt != null)
                  Text('Tested at: ${app_date_utils.AppDateUtils.formatDateTime(subTestCase.testedAt!)}'),
              ],
            ],
          ),
        ),
        actions: [
          if (!subTestCase.isLocked) ...[
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _markAsFailed(testCaseId, subTestCaseId: subTestCase.id);
              },
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Fail'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.errorColor,
                side: BorderSide(color: AppTheme.errorColor),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _markAsPassed(testCaseId, subTestCaseId: subTestCase.id);
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Pass'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successColor,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isTester) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('User Acceptance Testing'),
        ),
        body: const Center(
          child: Text(
            'You do not have access to UAT testing.\nPlease contact an administrator to grant tester access.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Acceptance Testing'),
        actions: [
          if (_canManageTestCases && _selectedRoundId != null)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Test Case',
              onPressed: () => _showAddTestCaseDialog(),
            ),
          if (_canManageTestCases)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: 'Add Test Round',
              onPressed: () => _showAddTestRoundDialog(),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              if (_selectedRoundId != null) {
                _loadTestCases(_selectedRoundId!);
              } else {
                _loadTestRounds();
              }
            },
          ),
        ],
      ),
      floatingActionButton: _canManageTestCases && _selectedRoundId != null
          ? FloatingActionButton(
              onPressed: () => _showAddTestCaseDialog(),
              tooltip: 'Add Test Case',
              child: const Icon(Icons.add),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _testRounds.isEmpty
              ? const Center(
                  child: Text('No test rounds available. Please contact an administrator.'),
                )
              : Column(
                  children: [
                    // Test Round Selector
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _selectedRoundId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Test Round',
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surface,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingMD,
                            vertical: AppTheme.spacingMD,
                          ),
                        ),
                        selectedItemBuilder: (BuildContext context) {
                          return _testRounds.map((round) {
                            return Text(
                              round.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            );
                          }).toList();
                        },
                        items: _testRounds.map((round) {
                          return DropdownMenuItem(
                            value: round.id,
                            child: Text(
                              round.name,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedRoundId = value;
                            });
                            _loadTestCases(value);
                          }
                        },
                      ),
                    ),
                    // Test Cases List
                    Expanded(
                      child: _testCases.isEmpty
                          ? EmptyState(
                              icon: Icons.checklist_outlined,
                              title: 'No Test Cases',
                              message: 'No test cases available for this round.\nTest cases will appear here once they are added by administrators.',
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(AppTheme.spacingMD),
                              itemCount: _testCases.length,
                              itemBuilder: (context, index) {
                                final testCase = _testCases[index];
                                final subCases = _subTestCases[testCase.id] ?? [];
                                final isExpanded = _expandedCases[testCase.id] ?? false;

                                return ModernCard(
                                  margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                                  child: ExpansionTile(
                                    tilePadding: EdgeInsets.zero,
                                    childrenPadding: EdgeInsets.zero,
                                    leading: GestureDetector(
                                      onTap: () => _showTestCaseDetails(testCase),
                                      child: Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: _getStatusColor(testCase.status).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                          border: Border.all(
                                            color: _getStatusColor(testCase.status).withValues(alpha: 0.3),
                                            width: 2,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${testCase.number}',
                                            style: TextStyle(
                                              color: _getStatusColor(testCase.status),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    title: GestureDetector(
                                      onTap: () => _showTestCaseDetails(testCase),
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: AppTheme.spacingXS),
                                        child: Text(
                                          testCase.title,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                    ),
                                    subtitle: GestureDetector(
                                      onTap: () => _showTestCaseDetails(testCase),
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: AppTheme.spacingSM),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildStatusChip(testCase.status),
                                            if (testCase.testedBy != null) ...[
                                              const SizedBox(height: AppTheme.spacingXS),
                                              Text(
                                                'Tested by: ${testCase.testedBy}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                            if (subCases.isNotEmpty) ...[
                                              const SizedBox(height: AppTheme.spacingXS),
                                              Chip(
                                                label: Text('${subCases.length} sub-tests'),
                                                labelStyle: const TextStyle(fontSize: 11),
                                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (!testCase.isLocked)
                                          IconButton(
                                            icon: const Icon(Icons.info_outline, size: 20),
                                            tooltip: 'View details',
                                            onPressed: () => _showTestCaseDetails(testCase),
                                          ),
                                        if (testCase.isLocked)
                                          _buildStatusChip(testCase.status),
                                      ],
                                    ),
                                    onExpansionChanged: (expanded) {
                                      setState(() {
                                        _expandedCases[testCase.id] = expanded;
                                      });
                                    },
                                    children: [
                                      if (testCase.description.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.all(AppTheme.spacingMD),
                                          child: Container(
                                            padding: const EdgeInsets.all(AppTheme.spacingMD),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                                            ),
                                            child: Text(
                                              testCase.description,
                                              style: TextStyle(
                                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                height: 1.5,
                                              ),
                                            ),
                                          ),
                                        ),
                                      if (subCases.isNotEmpty || _canManageTestCases) ...[
                                        Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppTheme.spacingMD,
                                            vertical: AppTheme.spacingSM,
                                          ),
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                'Sub-Test Cases',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                ),
                                              ),
                                              if (_canManageTestCases)
                                                TextButton.icon(
                                                  onPressed: () => _showAddSubTestCaseDialog(testCase.id),
                                                  icon: const Icon(Icons.add, size: 18),
                                                  label: const Text('Add'),
                                                  style: TextButton.styleFrom(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: AppTheme.spacingSM,
                                                      vertical: AppTheme.spacingXS,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        ...subCases.map((subCase) {
                                          return Container(
                                            margin: const EdgeInsets.symmetric(
                                              horizontal: AppTheme.spacingMD,
                                              vertical: AppTheme.spacingXS,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                                              border: Border.all(
                                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
                                              ),
                                            ),
                                            child: ListTile(
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: AppTheme.spacingMD,
                                                vertical: AppTheme.spacingXS,
                                              ),
                                              leading: GestureDetector(
                                                onTap: () => _showSubTestCaseDetails(subCase, testCase.id),
                                                child: Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: _getStatusColor(subCase.status).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                                                  ),
                                                  child: Center(
                                                    child: Text(
                                                      '${subCase.number}',
                                                      style: TextStyle(
                                                        color: _getStatusColor(subCase.status),
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              title: GestureDetector(
                                                onTap: () => _showSubTestCaseDetails(subCase, testCase.id),
                                                child: Text(
                                                  subCase.title,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              subtitle: Padding(
                                                padding: const EdgeInsets.only(top: AppTheme.spacingXS),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    _buildStatusChip(subCase.status, small: true),
                                                    if (subCase.testedBy != null) ...[
                                                      const SizedBox(height: AppTheme.spacingXS),
                                                      Text(
                                                        'Tested by: ${subCase.testedBy}',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                              trailing: !subCase.isLocked
                                                  ? IconButton(
                                                      icon: const Icon(Icons.info_outline, size: 18),
                                                      tooltip: 'View details',
                                                      onPressed: () =>
                                                          _showSubTestCaseDetails(subCase, testCase.id),
                                                    )
                                                  : _buildStatusChip(subCase.status, small: true),
                                              onTap: () => _showSubTestCaseDetails(subCase, testCase.id),
                                            ),
                                          );
                                        }),
                                        const SizedBox(height: AppTheme.spacingSM),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'passed':
        return AppTheme.successColor;
      case 'failed':
        return AppTheme.errorColor;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  Widget _buildStatusChip(String status, {bool small = false}) {
    final color = _getStatusColor(status);
    final text = status.toUpperCase();
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: small ? 10 : 11,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Future<void> _showAddTestRoundDialog() async {
    final nameController = TextEditingController();
    final descriptionController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Test Round'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Round Name',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _uatService.createTestRound(
          name: nameController.text.trim(),
          description: descriptionController.text.trim(),
        );
        await _loadTestRounds();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test round created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        Logger.error('Error creating test round', error: e, tag: 'UATScreen');
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

  Future<void> _showAddTestCaseDialog() async {
    if (_selectedRoundId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a test round first'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final numberController = TextEditingController(
      text: '${_testCases.length + 1}',
    );
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final featureController = TextEditingController();
    final testController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Test Case'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberController,
                decoration: const InputDecoration(
                  labelText: 'Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: featureController,
                decoration: const InputDecoration(
                  labelText: 'Feature',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: testController,
                decoration: const InputDecoration(
                  labelText: 'Test Steps',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final number = int.tryParse(numberController.text.trim()) ?? (_testCases.length + 1);
        await _uatService.addTestCase(
          roundId: _selectedRoundId!,
          number: number,
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          feature: featureController.text.trim().isEmpty ? null : featureController.text.trim(),
          test: testController.text.trim().isEmpty ? null : testController.text.trim(),
        );
        await _loadTestCases(_selectedRoundId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Test case added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        Logger.error('Error adding test case', error: e, tag: 'UATScreen');
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

  Future<void> _showAddSubTestCaseDialog(String testCaseId) async {
    if (_selectedRoundId == null) return;

    final subCases = _subTestCases[testCaseId] ?? [];
    final numberController = TextEditingController(
      text: '${subCases.length + 1}',
    );
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final featureController = TextEditingController();
    final testController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Sub-Test Case'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: numberController,
                decoration: const InputDecoration(
                  labelText: 'Number',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title *',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: featureController,
                decoration: const InputDecoration(
                  labelText: 'Feature',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: testController,
                decoration: const InputDecoration(
                  labelText: 'Test Steps',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.trim().isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        final number = int.tryParse(numberController.text.trim()) ?? (subCases.length + 1);
        await _uatService.addSubTestCase(
          roundId: _selectedRoundId!,
          testCaseId: testCaseId,
          number: number,
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
          feature: featureController.text.trim().isEmpty ? null : featureController.text.trim(),
          test: testController.text.trim().isEmpty ? null : testController.text.trim(),
        );
        await _loadTestCases(_selectedRoundId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sub-test case added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        Logger.error('Error adding sub-test case', error: e, tag: 'UATScreen');
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
}

