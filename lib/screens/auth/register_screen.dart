import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final String? pendingInviteCode;
  
  const RegisterScreen({super.key, this.pendingInviteCode});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _invitationCodeController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _selectedCreatorRole; // Only used when creating a new family (no invitation code)

  @override
  void initState() {
    super.initState();
    // If there's a pending invite code, pre-fill it
    final inviteCode = widget.pendingInviteCode;
    if (inviteCode != null && inviteCode.isNotEmpty) {
      _invitationCodeController.text = inviteCode;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _invitationCodeController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Get invitation code if provided
      // NOTE: Do NOT convert to uppercase - UUIDs are case-sensitive!
      final invitationCode = _invitationCodeController.text.trim();
      final cleanCode = invitationCode.isNotEmpty 
          ? invitationCode  // Keep original case - UUIDs are case-sensitive
          : null;
      
      // Register with optional familyId and creator role
      await _authService.registerWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
        familyId: cleanCode,
        creatorRelationship: cleanCode == null ? _selectedCreatorRole : null,
      );
      
      // Only show success message if registration succeeded (no exception thrown)
      if (cleanCode != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created and joined family successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      if (mounted) {
        // Navigation will be handled by auth state listener
      }
    } catch (e, stackTrace) {
      debugPrint('=== REGISTRATION ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      
      if (mounted) {
        String errorMessage = e.toString();
        // Clean up the error message to be more user-friendly
        if (errorMessage.contains('operation-not-allowed')) {
          errorMessage = 'Email/Password authentication is not enabled.\n\n'
              'Please enable it in Firebase Console:\n'
              '1. Go to Authentication > Sign-in method\n'
              '2. Enable Email/Password\n'
              '3. Save and try again';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() => _obscurePassword = !_obscurePassword);
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() =>
                            _obscureConfirmPassword = !_obscureConfirmPassword);
                      },
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                const Divider(),
                const SizedBox(height: 16),
                if (widget.pendingInviteCode != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Family Invitation Received',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                              Text(
                                'You\'ll join this family when you create your account',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Text(
                  'Optional: Join Existing Family',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'If you have a family invitation code, enter it below to join an existing family.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _invitationCodeController,
                  decoration: const InputDecoration(
                    labelText: 'Family Invitation Code (Optional)',
                    hintText: 'Enter invitation code',
                    prefixIcon: Icon(Icons.vpn_key),
                    border: OutlineInputBorder(),
                    helperText: 'Leave blank to create your own family',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (value) {
                    setState(() {
                      // Clear creator role selection when invitation code is entered
                      if (value.trim().isNotEmpty) {
                        _selectedCreatorRole = null;
                      }
                    });
                  },
                ),
                // Show creator role selection only when creating a new family (no invitation code)
                Builder(
                  builder: (context) {
                    final hasInviteCode = _invitationCodeController.text.trim().isNotEmpty;
                    if (hasInviteCode) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                  const SizedBox(height: 24),
                  const Text(
                    'Your Role in the Family',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select your role in the family (usually Father or Mother)',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedCreatorRole,
                    decoration: const InputDecoration(
                      labelText: 'My Role',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                      helperText: 'Required when creating a new family',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'father', child: Text('Father')),
                      DropdownMenuItem(value: 'mother', child: Text('Mother')),
                      DropdownMenuItem(value: 'husband', child: Text('Husband')),
                      DropdownMenuItem(value: 'wife', child: Text('Wife')),
                      DropdownMenuItem(value: 'son', child: Text('Son')),
                      DropdownMenuItem(value: 'daughter', child: Text('Daughter')),
                      DropdownMenuItem(value: 'brother', child: Text('Brother')),
                      DropdownMenuItem(value: 'sister', child: Text('Sister')),
                      DropdownMenuItem(value: 'grandfather', child: Text('Grandfather')),
                      DropdownMenuItem(value: 'grandmother', child: Text('Grandmother')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedCreatorRole = value;
                      });
                    },
                    validator: (value) {
                      // Only validate if no invitation code is provided
                      if (_invitationCodeController.text.trim().isEmpty && 
                          (value == null || value.isEmpty)) {
                        return 'Please select your role in the family';
                      }
                      return null;
                    },
                  ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Account'),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account? '),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Sign In'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

