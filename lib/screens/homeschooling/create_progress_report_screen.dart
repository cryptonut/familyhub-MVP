import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/homeschooling_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';

class CreateProgressReportScreen extends StatefulWidget {
  final String hubId;
  final String studentId;
  final String studentName;

  const CreateProgressReportScreen({
    super.key,
    required this.hubId,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<CreateProgressReportScreen> createState() =>
      _CreateProgressReportScreenState();
}

class _CreateProgressReportScreenState
    extends State<CreateProgressReportScreen> {
  final HomeschoolingService _service = HomeschoolingService();
  final _formKey = GlobalKey<FormState>();
  final _reportPeriodController = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isGenerating = false;

  @override
  void dispose() {
    _reportPeriodController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _selectEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate ?? DateTime.now(),
      firstDate: _startDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _endDate = picked);
    }
  }

  Future<void> _generateReport() async {
    if (!_formKey.currentState!.validate()) return;
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end dates')),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      await _service.generateProgressReport(
        hubId: widget.hubId,
        studentId: widget.studentId,
        reportPeriod: _reportPeriodController.text.trim(),
        startDate: _startDate!,
        endDate: _endDate!,
      );

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Progress Report'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Student: ${widget.studentName}',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: AppTheme.spacingLG),
              TextFormField(
                controller: _reportPeriodController,
                decoration: const InputDecoration(
                  labelText: 'Report Period *',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Q1 2025, Semester 1, Week 1-4',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Report period is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingMD),
              ListTile(
                title: const Text('Start Date *'),
                subtitle: Text(
                  _startDate != null
                      ? DateFormat('MMM dd, yyyy').format(_startDate!)
                      : 'Select start date',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectStartDate,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              ListTile(
                title: const Text('End Date *'),
                subtitle: Text(
                  _endDate != null
                      ? DateFormat('MMM dd, yyyy').format(_endDate!)
                      : 'Select end date',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectEndDate,
              ),
              const SizedBox(height: AppTheme.spacingLG),
              const Text(
                'The report will be automatically generated based on assignments and lessons completed during this period.',
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : _generateReport,
            icon: _isGenerating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.assessment),
            label: Text(_isGenerating ? 'Generating...' : 'Generate Report'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              backgroundColor: Colors.green,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

