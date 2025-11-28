import 'package:flutter/material.dart';
import '../../core/services/logger_service.dart';
import '../../services/auth_service.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  final String? pendingInviteCode;
  
  const LoginScreen({super.key, this.pendingInviteCode});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );
      
      // Sign-in succeeded - userModel may be null if document doesn't exist
      // That's okay - the app will handle it gracefully
      Logger.info('Login successful - user: ${_authService.currentUser?.uid}', tag: 'LoginScreen');
      
      // Show success message
      if (mounted && context.mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Login successful!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        } catch (e) {
          // Widget disposed - ignore
          Logger.warning('Could not show success snackbar', error: e, tag: 'LoginScreen');
        }
      }
      
      // If there's a pending invite code, join the family after login
      final inviteCode = widget.pendingInviteCode;
      if (inviteCode != null && inviteCode.isNotEmpty && mounted) {
        try {
          await _authService.joinFamilyByInvitationCode(inviteCode);
          if (mounted && context.mounted) {
            try {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Successfully joined family!'),
                  backgroundColor: Colors.green,
                ),
              );
            } catch (e) {
              Logger.warning('Could not show success snackbar', error: e, tag: 'LoginScreen');
            }
          }
        } catch (e) {
          if (mounted && context.mounted) {
            try {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Logged in, but could not join family: $e'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 5),
                ),
              );
            } catch (snackBarError) {
              Logger.warning('Could not show error snackbar', error: snackBarError, tag: 'LoginScreen');
            }
          }
        }
      }
      
      // Navigation will be handled by auth state listener in AuthWrapper
    } catch (e, stackTrace) {
      Logger.error('=== LOGIN SCREEN: ERROR CAUGHT ===', tag: 'LoginScreen');
      Logger.error('Error type: ${e.runtimeType}', error: e, stackTrace: stackTrace, tag: 'LoginScreen');
      
      // Check if it's a Firebase error
      if (e.toString().contains('FirebaseAuthException')) {
        Logger.warning('This is a Firebase Auth error - check Firebase Console settings', tag: 'LoginScreen');
      } else if (e.toString().contains('Timeout')) {
        Logger.warning('This is a timeout - check network or API key restrictions', tag: 'LoginScreen');
      } else {
        Logger.warning('This is an unexpected error type', tag: 'LoginScreen');
      }
      
      if (mounted) {
        try {
          // Extract error message from Exception
          String errorMessage;
          if (e is Exception) {
            errorMessage = e.toString().replaceFirst('Exception: ', '');
          } else {
            errorMessage = e.toString();
          }
          
          // Clean up error messages to be more user-friendly
          final lowerMessage = errorMessage.toLowerCase();
          if (lowerMessage.contains('user-not-found')) {
            errorMessage = 'No account found with this email address. Please check your email or sign up.';
          } else if (lowerMessage.contains('wrong-password')) {
            errorMessage = 'Incorrect password. Please try again.';
          } else if (lowerMessage.contains('invalid-email')) {
            errorMessage = 'Invalid email address. Please check your email format.';
          } else if (lowerMessage.contains('user-disabled')) {
            errorMessage = 'This account has been disabled. Please contact support.';
          } else if (lowerMessage.contains('too-many-requests')) {
            errorMessage = 'Too many failed login attempts. Please try again later.';
          } else if (lowerMessage.contains('network-request-failed') || lowerMessage.contains('unavailable')) {
            errorMessage = 'Network error. Please check your internet connection and try again.';
          } else if (lowerMessage.contains('account data not found')) {
            errorMessage = 'Your account data is missing. Please contact support or create a new account.';
          } else if (lowerMessage.contains('timeout') || lowerMessage.contains('timed out')) {
            errorMessage = 'Login request timed out.\n\n'
                'If you see "empty reCAPTCHA token" in logs:\n'
                '• Go to Firebase Console > Authentication > Settings\n'
                '• DISABLE reCAPTCHA for email/password\n'
                '• Wait 1-2 minutes, then try again\n\n'
                'Otherwise, check:\n'
                '• Network connectivity\n'
                '• API key restrictions\n'
                '• Firebase configuration';
          } else if (lowerMessage.contains('developer_error') || lowerMessage.contains('oauth')) {
            errorMessage = 'Firebase configuration error. Please verify:\n'
                '• OAuth client is configured in Firebase Console\n'
                '• SHA-1 fingerprint is added\n'
                '• Wait 2-3 minutes after configuration changes';
          } else if (lowerMessage.contains('firebase configuration')) {
            errorMessage = 'Firebase configuration issue. Please check Firebase Console settings.';
          }
          
          // Safely show SnackBar - widget might be disposed during async operation
          if (mounted && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        } catch (snackBarError) {
          // Widget was disposed before we could show the snackbar - ignore
          Logger.warning('Could not show error snackbar', error: snackBarError, tag: 'LoginScreen');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      if (mounted && context.mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please enter your email address'),
            ),
          );
        } catch (e) {
          Logger.warning('Could not show snackbar', error: e, tag: 'LoginScreen');
        }
      }
      return;
    }

    try {
      await _authService.resetPassword(email);
      if (mounted && context.mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Password reset email sent!'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          Logger.warning('Could not show success snackbar', error: e, tag: 'LoginScreen');
        }
      }
    } catch (e) {
      if (mounted && context.mounted) {
        try {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(e.toString()),
              backgroundColor: Colors.red,
            ),
          );
        } catch (snackBarError) {
          Logger.warning('Could not show error snackbar', error: snackBarError, tag: 'LoginScreen');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.family_restroom,
                    size: 80,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Family Hub',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.pendingInviteCode != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16, top: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
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
                                  'You\'ll join the family after signing in',
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
                  const SizedBox(height: 32),
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
                        return 'Please enter your password';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _resetPassword,
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign In'),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account? "),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => RegisterScreen(
                                pendingInviteCode: widget.pendingInviteCode,
                              ),
                            ),
                          );
                        },
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

