import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/progress_report.dart';
import '../../models/student_profile.dart';
import '../../services/homeschooling_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'create_progress_report_screen.dart';

class ProgressReportsScreen extends StatefulWidget {
  final String hubId;

  const ProgressReportsScreen({
    super.key,
    required this.hubId,
  });

  @override
  State<ProgressReportsScreen> createState() => _ProgressReportsScreenState();
}

class _ProgressReportsScreenState extends State<ProgressReportsScreen> {
  final HomeschoolingService _service = HomeschoolingService();
  List<StudentProfile> _students = [];
  Map<String, List<ProgressReport>> _reportsByStudent = {};
  bool _isLoading = true;
  String? _selectedStudentId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final students = await _service.getStudentProfiles(widget.hubId);
      final reportsByStudent = <String, List<ProgressReport>>{};

      for (var student in students) {
        final reports = await _service.getProgressReports(
          hubId: widget.hubId,
          studentId: student.id,
        );
        reportsByStudent[student.id] = reports;
      }

      setState(() {
        _students = students;
        _reportsByStudent = reportsByStudent;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Reports'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _students.isEmpty
                  ? EmptyState(
                      icon: Icons.assessment,
                      title: 'No Students Yet',
                      message: 'Add students to generate progress reports',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppTheme.spacingMD),
                      itemCount: _students.length,
                      itemBuilder: (context, index) {
                        final student = _students[index];
                        final reports = _reportsByStudent[student.id] ?? [];
                        return ModernCard(
                          padding: const EdgeInsets.all(AppTheme.spacingMD),
                          margin: const EdgeInsets.only(bottom: AppTheme.spacingMD),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    child: Text(
                                      student.name.isNotEmpty
                                          ? student.name[0].toUpperCase()
                                          : '?',
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacingMD),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          student.name,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        if (student.gradeLevel != null)
                                          Text(
                                            student.gradeLevel!,
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                      ],
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: () => _generateReport(student),
                                    icon: const Icon(Icons.add, size: 16),
                                    label: const Text('Generate'),
                                  ),
                                ],
                              ),
                              if (reports.isEmpty) ...[
                                const SizedBox(height: AppTheme.spacingMD),
                                const Text('No reports yet'),
                              ] else ...[
                                const SizedBox(height: AppTheme.spacingMD),
                                const Divider(),
                                const SizedBox(height: AppTheme.spacingMD),
                                ...reports.map((report) => ListTile(
                                      leading: const Icon(Icons.assessment),
                                      title: Text(report.reportPeriod),
                                      subtitle: Text(
                                        '${DateFormat('MMM dd').format(report.startDate)} - ${DateFormat('MMM dd, yyyy').format(report.endDate)}',
                                      ),
                                      trailing: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            '${report.overallAverage.toStringAsFixed(1)}%',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: _getGradeColor(
                                                    report.overallAverage,
                                                  ),
                                                ),
                                          ),
                                        ],
                                      ),
                                      onTap: () => _viewReport(report),
                                    )),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Color _getGradeColor(double grade) {
    if (grade >= 90) return Colors.green;
    if (grade >= 80) return Colors.blue;
    if (grade >= 70) return Colors.orange;
    return Colors.red;
  }

  Future<void> _generateReport(StudentProfile student) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateProgressReportScreen(
          hubId: widget.hubId,
          studentId: student.id,
          studentName: student.name,
        ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _viewReport(ProgressReport report) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report.reportPeriod),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Overall Average: ${report.overallAverage.toStringAsFixed(1)}%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              if (report.subjectProgress.isNotEmpty) ...[
                const Text(
                  'Subject Progress:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: AppTheme.spacingSM),
                ...report.subjectProgress.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spacingXS),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(entry.key),
                          Text(
                            '${entry.value.averageGrade.toStringAsFixed(1)}%',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    )),
              ],
              if (report.strengths.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingMD),
                const Text(
                  'Strengths:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...report.strengths.map((s) => Text('• $s')),
              ],
              if (report.areasForImprovement.isNotEmpty) ...[
                const SizedBox(height: AppTheme.spacingMD),
                const Text(
                  'Areas for Improvement:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                ...report.areasForImprovement.map((a) => Text('• $a')),
              ],
            ],
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
}

