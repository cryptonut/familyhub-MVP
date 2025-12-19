import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../utils/app_theme.dart';
import '../../widgets/ui_components.dart';
import 'package:intl/intl.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _authService = AuthService();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  
  UserModel? _currentUser;
  DateTime? _selectedBirthday;
  bool _birthdayNotificationsEnabled = true;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    try {
      _currentUser = await _authService.getCurrentUserModel();
      if (_currentUser != null) {
        _displayNameController.text = _currentUser!.displayName;
        _selectedBirthday = _currentUser!.birthday;
        _birthdayNotificationsEnabled = _currentUser!.birthdayNotificationsEnabled;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _selectBirthday() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthday ?? DateTime.now().subtract(const Duration(days: 365 * 18)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select your birthday',
    );
    
    if (picked != null && mounted) {
      setState(() {
        _selectedBirthday = DateTime(picked.year, picked.month, picked.day);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to update your profile'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // Update display name in Firestore
      await _firestore.collection('users').doc(user.uid).update({
        'displayName': _displayNameController.text.trim(),
        if (_selectedBirthday != null) 
          'birthday': _selectedBirthday!.toIso8601String(),
        'birthdayNotificationsEnabled': _birthdayNotificationsEnabled,
      });

      // Update Firebase Auth display name if changed
      if (user.displayName != _displayNameController.text.trim()) {
        await user.updateDisplayName(_displayNameController.text.trim());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Display Name
            TextFormField(
              controller: _displayNameController,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a display name';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            // Birthday Section
            const Text(
              'Birthday',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your birthday helps us remind your family members',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Birthday'),
              subtitle: Text(
                _selectedBirthday != null
                    ? DateFormat('MMMM d').format(_selectedBirthday!)
                    : 'Not set',
                style: TextStyle(
                  color: _selectedBirthday != null 
                      ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.87)
                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _selectBirthday,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerHighest),
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _selectedBirthday != null
                  ? () {
                      setState(() {
                        _selectedBirthday = null;
                      });
                    }
                  : null,
              icon: const Icon(Icons.clear, size: 18),
              label: const Text('Clear birthday'),
            ),
            const SizedBox(height: 24),
            
            // Birthday Notifications Toggle
            SwitchListTile(
              title: const Text('Birthday Reminders'),
              subtitle: const Text(
                'Send notifications to family members 1 day before birthdays',
              ),
              value: _birthdayNotificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _birthdayNotificationsEnabled = value;
                });
              },
              secondary: const Icon(Icons.notifications),
            ),
          ],
        ),
      ),
    );
  }
}

