import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/child_profile.dart';
import '../../services/coparenting_service.dart';
import '../../utils/app_theme.dart';

class CreateEditChildProfileScreen extends StatefulWidget {
  final String hubId;
  final ChildProfile? profile;

  const CreateEditChildProfileScreen({
    super.key,
    required this.hubId,
    this.profile,
  });

  @override
  State<CreateEditChildProfileScreen> createState() =>
      _CreateEditChildProfileScreenState();
}

class _CreateEditChildProfileScreenState
    extends State<CreateEditChildProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _medicalInfoController = TextEditingController();
  final _schoolNameController = TextEditingController();
  final _schoolGradeController = TextEditingController();
  final _schoolContactController = TextEditingController();
  final CoparentingService _service = CoparentingService();
  DateTime? _dateOfBirth;
  final List<String> _activitySchedules = [];

  @override
  void initState() {
    super.initState();
    if (widget.profile != null) {
      _nameController.text = widget.profile!.name;
      _dateOfBirth = widget.profile!.dateOfBirth;
      _medicalInfoController.text = widget.profile!.medicalInfo ?? '';
      _schoolNameController.text = widget.profile!.schoolName ?? '';
      _schoolGradeController.text = widget.profile!.schoolGrade ?? '';
      _schoolContactController.text = widget.profile!.schoolContact ?? '';
      _activitySchedules.addAll(widget.profile!.activitySchedules);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _medicalInfoController.dispose();
    _schoolNameController.dispose();
    _schoolGradeController.dispose();
    _schoolContactController.dispose();
    super.dispose();
  }

  Future<void> _selectDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      if (widget.profile == null) {
        await _service.createChildProfile(
          hubId: widget.hubId,
          name: _nameController.text.trim(),
          dateOfBirth: _dateOfBirth,
          medicalInfo: _medicalInfoController.text.trim().isEmpty
              ? null
              : _medicalInfoController.text.trim(),
          schoolName: _schoolNameController.text.trim().isEmpty
              ? null
              : _schoolNameController.text.trim(),
          schoolGrade: _schoolGradeController.text.trim().isEmpty
              ? null
              : _schoolGradeController.text.trim(),
          schoolContact: _schoolContactController.text.trim().isEmpty
              ? null
              : _schoolContactController.text.trim(),
          activitySchedules: _activitySchedules,
        );
      } else {
        await _service.updateChildProfile(
          hubId: widget.hubId,
          profileId: widget.profile!.id,
          name: _nameController.text.trim(),
          dateOfBirth: _dateOfBirth,
          medicalInfo: _medicalInfoController.text.trim().isEmpty
              ? null
              : _medicalInfoController.text.trim(),
          schoolName: _schoolNameController.text.trim().isEmpty
              ? null
              : _schoolNameController.text.trim(),
          schoolGrade: _schoolGradeController.text.trim().isEmpty
              ? null
              : _schoolGradeController.text.trim(),
          schoolContact: _schoolContactController.text.trim().isEmpty
              ? null
              : _schoolContactController.text.trim(),
          activitySchedules: _activitySchedules,
        );
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.profile == null ? 'Add Child Profile' : 'Edit Child Profile'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Child Name *',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppTheme.spacingMD),
              ListTile(
                title: const Text('Date of Birth'),
                subtitle: Text(
                  _dateOfBirth != null
                      ? DateFormat('MMM dd, yyyy').format(_dateOfBirth!)
                      : 'Select date of birth',
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _selectDateOfBirth,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              const Text(
                'Medical Information',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              TextFormField(
                controller: _medicalInfoController,
                decoration: const InputDecoration(
                  labelText: 'Allergies, Medications, Conditions',
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Peanut allergy, Asthma medication',
                ),
                maxLines: 3,
              ),
              const SizedBox(height: AppTheme.spacingMD),
              const Text(
                'School Information',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppTheme.spacingSM),
              TextFormField(
                controller: _schoolNameController,
                decoration: const InputDecoration(
                  labelText: 'School Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _schoolGradeController,
                decoration: const InputDecoration(
                  labelText: 'Grade',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppTheme.spacingMD),
              TextFormField(
                controller: _schoolContactController,
                decoration: const InputDecoration(
                  labelText: 'School Contact',
                  border: OutlineInputBorder(),
                  hintText: 'Phone or email',
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacingMD),
          child: ElevatedButton.icon(
            onPressed: _saveProfile,
            icon: const Icon(Icons.check),
            label: Text(widget.profile == null ? 'Create Profile' : 'Save Changes'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.all(AppTheme.spacingMD),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

