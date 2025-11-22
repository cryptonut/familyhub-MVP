import 'dart:async';
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
import '../services/calendar_sync_service.dart';
import '../services/background_sync_service.dart';
import '../widgets/error_handler.dart';
import '../models/user_model.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _pendingInviteCode;
  String? _pendingHubInviteId;
  bool _hasResetToDashboard = false;
  String? _lastUserId; // Track last logged-in user ID to detect new login sessions

  @override
  void initState() {
    super.initState();
    _checkForInviteCode();
  }

  void _checkForInviteCode() {
    // Check URL parameters for invitation code (web only)
    // This is a legitimate web-specific feature, not a workaround
    // Android uses deep links handled by the platform, not URL parameters
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

    // Rebuild: Simple, reliable auth flow
    // Only check Firebase Auth - no Firestore blocking
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Handle stream errors
        if (snapshot.hasError) {
          debugPrint('AuthWrapper: Stream error - ${snapshot.error}');
          _resetState();
          return LoginScreen(pendingInviteCode: _pendingInviteCode);
        }

        // Initial loading - show spinner briefly
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // No user = show login
        if (!snapshot.hasData || snapshot.data == null) {
          debugPrint('AuthWrapper: No user - showing login');
          _resetState();
          
          if (_pendingHubInviteId != null && _pendingHubInviteId!.isNotEmpty) {
            return HubInviteScreen(inviteId: _pendingHubInviteId!);
          }
          
          return LoginScreen(pendingInviteCode: _pendingInviteCode);
        }

        // User exists - validate it's a real session
        final user = snapshot.data!;
        debugPrint('AuthWrapper: User found - ${user.uid}');
        debugPrint('AuthWrapper: Firebase Auth session persisted (user automatically logged in)');
        debugPrint('AuthWrapper: Email: ${user.email}');
        debugPrint('AuthWrapper: Now attempting to load user data from Firestore...');
        
        // Reset state if different user (new login after logout)
        if (_lastUserId != null && _lastUserId != user.uid) {
          debugPrint('AuthWrapper: Different user detected - resetting state');
          _resetState();
        }
        
        // Verify Firestore is accessible by checking if we can load user data
        // This check is platform-agnostic and applies to both web and Android
        // If Firestore is unavailable, show a warning but don't block navigation
        if (!_hasResetToDashboard) {
          final appState = Provider.of<AppState>(context, listen: false);
          
          // Check Firestore connectivity before proceeding (non-blocking)
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            
            try {
              // Try to load user model with timeout to detect Firestore issues
              // Use a reasonable timeout that works for both web and Android
              final userModel = await authService.getCurrentUserModel()
                  .timeout(const Duration(seconds: 10), onTimeout: () {
                debugPrint('AuthWrapper: ⚠️ Firestore timeout - cannot load user data');
                debugPrint('AuthWrapper: This may indicate network issues or API restrictions');
                return null;
              });
              
              if (userModel == null && mounted) {
                debugPrint('AuthWrapper: ⚠️ WARNING - Cannot load user data from Firestore');
                debugPrint('AuthWrapper: User is authenticated but Firestore is unavailable');
                debugPrint('AuthWrapper: This will result in empty dashboard with no data');
                
                // Show a warning to the user (platform-agnostic)
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Cannot load data from Firestore. Please sign out and sign back in, or check your connection.',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 8),
                      action: SnackBarAction(
                        label: 'Sign Out',
                        textColor: Colors.white,
                        onPressed: () async {
                          await authService.signOut();
                        },
                      ),
                    ),
                  );
                }
              } else {
                debugPrint('AuthWrapper: ✓ User data loaded successfully from Firestore');
              }
            } catch (e) {
              debugPrint('AuthWrapper: Error checking Firestore connectivity: $e');
              // Only show error snackbar for critical Firestore unavailable errors
              if (mounted && e.toString().toLowerCase().contains('unavailable')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Firestore is unavailable. Sign out and try again.',
                      style: TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 8),
                    action: SnackBarAction(
                      label: 'Sign Out',
                      textColor: Colors.white,
                      onPressed: () async {
                        await authService.signOut();
                      },
                    ),
                  ),
                );
              }
            }
            
            // Reset dashboard state regardless of Firestore connectivity
            // This ensures the user can still navigate even if Firestore is unavailable
            if (mounted) {
              appState.setCurrentIndex(0);
              _hasResetToDashboard = true;
              _lastUserId = user.uid;
              _triggerCalendarSyncIfEnabled();
            }
          });
        }
        
        // Handle pending invites
        if (_pendingHubInviteId != null && _pendingHubInviteId!.isNotEmpty) {
          return HubInviteScreen(inviteId: _pendingHubInviteId!);
        }
        
        final code = _pendingInviteCode;
        if (code != null && code.isNotEmpty) {
          Future.microtask(() {
            if (mounted && _pendingInviteCode == code) {
              _handleInviteCode(code);
            }
          });
        }
        
        return const HomeScreen();
      },
    );
  }

  void _resetState() {
    _hasResetToDashboard = false;
    _lastUserId = null;
  }

  Future<void> _triggerCalendarSyncIfEnabled() async {
    // Don't block - run in background and handle errors gracefully
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      // Use timeout to prevent hanging
      final userModel = await authService.getCurrentUserModel()
          .timeout(const Duration(seconds: 3), onTimeout: () {
        debugPrint('_triggerCalendarSyncIfEnabled: Timeout getting user model');
        return null;
      }).catchError((e) {
        debugPrint('_triggerCalendarSyncIfEnabled: Error getting user model: $e');
        return null;
      });
      
      if (userModel?.calendarSyncEnabled == true && userModel?.localCalendarId != null) {
        // Register background sync if not already registered (non-blocking)
        BackgroundSyncService.registerPeriodicSync().catchError((e) {
          debugPrint('Error registering background sync: $e');
        });
        
        // Perform initial sync in background (don't block UI)
        final syncService = CalendarSyncService();
        syncService.performSync().catchError((e) {
          debugPrint('Error performing initial calendar sync: $e');
        });
      }
    } catch (e) {
      debugPrint('Error checking calendar sync status: $e');
      // Don't rethrow - this is non-critical
    }
  }
}

