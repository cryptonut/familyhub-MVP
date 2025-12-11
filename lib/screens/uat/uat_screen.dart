import 'package:flutter/material.dart';
import '../../services/uat_service.dart';
import '../../core/services/logger_service.dart';
import '../../utils/date_utils.dart' as app_date_utils;

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

  @override
  void initState() {
    super.initState();
    _checkTesterStatus();
  }

  Future<void> _checkTesterStatus() async {
    try {
      final tester = await _uatService.isTester();
      if (mounted) {
        setState(() {
          _isTester = tester;
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
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _markAsFailed(testCase.id);
              },
              child: const Text('Fail', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _markAsPassed(testCase.id);
              },
              child: const Text('Pass', style: TextStyle(color: Colors.green)),
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
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _markAsFailed(testCaseId, subTestCaseId: subTestCase.id);
              },
              child: const Text('Fail', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _markAsPassed(testCaseId, subTestCaseId: subTestCase.id);
              },
              child: const Text('Pass', style: TextStyle(color: Colors.green)),
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
          IconButton(
            icon: const Icon(Icons.refresh),
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
                      padding: const EdgeInsets.all(16),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: DropdownButtonFormField<String>(
                        value: _selectedRoundId,
                        decoration: const InputDecoration(
                          labelText: 'Test Round',
                          border: OutlineInputBorder(),
                        ),
                        items: _testRounds.map((round) {
                          return DropdownMenuItem(
                            value: round.id,
                            child: Text(round.name),
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
                          ? const Center(
                              child: Text('No test cases available for this round.'),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _testCases.length,
                              itemBuilder: (context, index) {
                                final testCase = _testCases[index];
                                final subCases = _subTestCases[testCase.id] ?? [];
                                final isExpanded = _expandedCases[testCase.id] ?? false;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: ExpansionTile(
                                    leading: CircleAvatar(
                                      backgroundColor: _getStatusColor(testCase.status),
                                      child: Text(
                                        '${testCase.number}',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    title: Text(testCase.title),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Status: ${testCase.status.toUpperCase()}',
                                          style: TextStyle(
                                            color: _getStatusColor(testCase.status),
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (testCase.testedBy != null)
                                          Text(
                                            'Tested by: ${testCase.testedBy}',
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                      ],
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (subCases.isNotEmpty)
                                          Chip(
                                            label: Text('${subCases.length} sub-tests'),
                                            labelStyle: const TextStyle(fontSize: 10),
                                          ),
                                        if (!testCase.isLocked)
                                          IconButton(
                                            icon: const Icon(Icons.info_outline),
                                            onPressed: () => _showTestCaseDetails(testCase),
                                          ),
                                        if (!testCase.isLocked)
                                          IconButton(
                                            icon: const Icon(Icons.check, color: Colors.green),
                                            onPressed: () => _markAsPassed(testCase.id),
                                          ),
                                        if (!testCase.isLocked)
                                          IconButton(
                                            icon: const Icon(Icons.close, color: Colors.red),
                                            onPressed: () => _markAsFailed(testCase.id),
                                          ),
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
                                          padding: const EdgeInsets.all(16),
                                          child: Text(testCase.description),
                                        ),
                                      if (subCases.isNotEmpty) ...[
                                        const Divider(),
                                        const Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            'Sub-Test Cases:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        ...subCases.map((subCase) {
                                          return ListTile(
                                            leading: CircleAvatar(
                                              radius: 12,
                                              backgroundColor: _getStatusColor(subCase.status),
                                              child: Text(
                                                '${subCase.number}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                ),
                                              ),
                                            ),
                                            title: Text(subCase.title),
                                            subtitle: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Status: ${subCase.status.toUpperCase()}',
                                                  style: TextStyle(
                                                    color: _getStatusColor(subCase.status),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                                if (subCase.testedBy != null)
                                                  Text(
                                                    'Tested by: ${subCase.testedBy}',
                                                    style: const TextStyle(fontSize: 11),
                                                  ),
                                              ],
                                            ),
                                            trailing: !subCase.isLocked
                                                ? Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: const Icon(Icons.info_outline, size: 18),
                                                        onPressed: () =>
                                                            _showSubTestCaseDetails(subCase, testCase.id),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.check, color: Colors.green, size: 18),
                                                        onPressed: () =>
                                                            _markAsPassed(testCase.id, subTestCaseId: subCase.id),
                                                      ),
                                                      IconButton(
                                                        icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                                        onPressed: () =>
                                                            _markAsFailed(testCase.id, subTestCaseId: subCase.id),
                                                      ),
                                                    ],
                                                  )
                                                : null,
                                            onTap: () => _showSubTestCaseDetails(subCase, testCase.id),
                                          );
                                        }),
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
        return Colors.green;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

