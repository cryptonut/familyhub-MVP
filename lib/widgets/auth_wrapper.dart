import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../screens/home_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/family/join_family_screen.dart';
import '../screens/hubs/hub_invite_screen.dart';
import '../services/auth_service.dart';
import '../services/app_state.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _pendingInviteCode;
  String? _pendingHubInviteId;
  bool _hasResetToDashboard = false;

  @override
  void initState() {
    super.initState();
    _checkForInviteCode();
  }

  void _checkForInviteCode() {
    // Check URL parameters for invitation code (web)
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        try {
          final uri = Uri.base;
          
          // Check for family invite
          final inviteCode = uri.queryParameters['invite'];
          if (inviteCode != null && inviteCode.isNotEmpty) {
            final trimmedCode = inviteCode.trim();
            if (trimmedCode.isNotEmpty && mounted) {
              setState(() {
                _pendingInviteCode = trimmedCode;
              });
              debugPrint('Family invitation code found: $trimmedCode');
            }
          }
          
          // Check for hub invite
          final hubInviteId = uri.queryParameters['hub-invite'];
          if (hubInviteId != null && hubInviteId.isNotEmpty) {
            final trimmedId = hubInviteId.trim();
            if (trimmedId.isNotEmpty && mounted) {
              setState(() {
                _pendingHubInviteId = trimmedId;
              });
              debugPrint('Hub invite ID found: $trimmedId');
            }
          }
        } catch (e, stackTrace) {
          debugPrint('Error checking for invite code: $e');
          debugPrint('Stack trace: $stackTrace');
          // Don't crash the app, just log the error
        }
      });
    }
  }

  Future<void> _handleInviteCode(String code) async {
    if (!mounted) return;
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user == null) {
        // User not logged in - store code and show login screen
        // The code will be handled when they register or after login
        if (mounted) {
          setState(() {
            _pendingInviteCode = code;
          });
        }
      } else {
        // User is logged in - try to join family
        try {
          await authService.joinFamilyByInvitationCode(code);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Successfully joined family!'),
                backgroundColor: Colors.green,
              ),
            );
            setState(() {
              _pendingInviteCode = null;
            });
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error joining family: $e'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Catch any errors during the process
      debugPrint('Error handling invite code: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing invitation: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          // User is logged in - ensure we're on the dashboard (only reset once per login session)
          if (!_hasResetToDashboard) {
            final appState = Provider.of<AppState>(context, listen: false);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                appState.setCurrentIndex(0);
                _hasResetToDashboard = true;
              }
            });
          }
          
          // If there's a pending hub invite, show hub invite screen
          if (_pendingHubInviteId != null && _pendingHubInviteId!.isNotEmpty) {
            return HubInviteScreen(inviteId: _pendingHubInviteId!);
          }
          
          // If there's a pending invite code, handle it
          final code = _pendingInviteCode;
          if (code != null && code.isNotEmpty) {
            // Use a microtask to ensure the widget is fully built
            Future.microtask(() {
              if (mounted && _pendingInviteCode == code) {
                _handleInviteCode(code);
              }
            });
          }
          return const HomeScreen();
        } else {
          // User logged out - reset flag for next login
          _hasResetToDashboard = false;
        }
        
        // User not logged in - check for hub invite
        if (_pendingHubInviteId != null && _pendingHubInviteId!.isNotEmpty) {
          // Show hub invite screen even if not logged in
          // The screen will prompt for login if needed
          return HubInviteScreen(inviteId: _pendingHubInviteId!);
        }

        // User not logged in - show login screen
        // Pass pending invite code to login screen
        final pendingCode = _pendingInviteCode;
        return LoginScreen(pendingInviteCode: pendingCode);
      },
    );
  }
}

