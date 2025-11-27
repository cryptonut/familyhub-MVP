import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import 'dashboard/dashboard_screen.dart';
import 'calendar/calendar_screen.dart';
import 'tasks/tasks_screen.dart';
import 'chat/chat_screen.dart';
import 'location/location_screen.dart';
import 'family/family_invitation_screen.dart';
import 'family/join_family_screen.dart';
import 'admin/role_management_screen.dart';
import 'admin/migration_screen.dart';
import 'admin/database_reset_screen.dart';
import 'profile/edit_profile_screen.dart';
import 'settings/calendar_sync_settings_screen.dart';
import 'settings/privacy_center_screen.dart';
import 'games/games_home_screen.dart';
import 'photos/photos_home_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  Future<void> _showFixFamilyDialog(BuildContext context, AuthService authService) async {
    // Capture outer context before showing dialog to avoid using invalid context after pop
    final outerContext = context;
    final emailController = TextEditingController();
    final familyIdController = TextEditingController();
    bool isLoading = false;
    String? kateFamilyId;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.family_restroom, color: Colors.orange),
              SizedBox(width: 8),
              Text('Fix Family Link'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This will update your familyId to match Kate\'s family.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: "Kate's Email",
                    hintText: 'Enter Kate\'s email to find her familyId',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email),
                  ),
                  enabled: !isLoading && kateFamilyId == null,
                ),
                const SizedBox(height: 8),
                if (kateFamilyId != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Found Kate\'s Family ID:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          kateFamilyId!,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  controller: familyIdController,
                  decoration: const InputDecoration(
                    labelText: 'Or Enter Family ID Directly',
                    hintText: 'Paste family ID here',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.vpn_key),
                  ),
                  enabled: !isLoading,
                ),
                if (isLoading) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: isLoading ? null : () async {
                if (emailController.text.isNotEmpty && kateFamilyId == null) {
                  // Find Kate's familyId by email
                  setState(() => isLoading = true);
                  try {
                    final familyId = await authService.getFamilyIdByEmail(emailController.text.trim());
                    setState(() {
                      isLoading = false;
                      kateFamilyId = familyId;
                    });
                    if (familyId == null) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          const SnackBar(
                            content: Text('No user found with that email'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      }
                    } else {
                      familyIdController.text = familyId;
                    }
                  } catch (e) {
                    setState(() => isLoading = false);
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                } else if (familyIdController.text.isNotEmpty) {
                  // Update familyId directly
                  setState(() => isLoading = true);
                  try {
                    await authService.updateFamilyIdDirectly(familyIdController.text.trim());
                    // Close dialog first, then show snackbar using outer context
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    // Use outer context for snackbar after dialog is closed
                    if (outerContext.mounted) {
                      ScaffoldMessenger.of(outerContext).showSnackBar(
                        const SnackBar(
                          content: Text('Family ID updated! Please restart the app to see changes.'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 5),
                        ),
                      );
                    }
                  } catch (e) {
                    setState(() => isLoading = false);
                    if (dialogContext.mounted) {
                      ScaffoldMessenger.of(dialogContext).showSnackBar(
                        SnackBar(
                          content: Text('Error updating family ID: $e'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  }
                } else {
                  if (dialogContext.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Please enter Kate\'s email or family ID'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check),
              label: Text(kateFamilyId == null && emailController.text.isNotEmpty 
                  ? 'Find Family ID' 
                  : 'Update Family ID'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      // Dispose controllers when dialog is dismissed
      emailController.dispose();
      familyIdController.dispose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    
    return Consumer<AppState>(
      builder: (context, appState, _) {
        return Scaffold(
          appBar: AppBar(
            title: GestureDetector(
              onTap: () {
                // Navigate to dashboard (index 0)
                appState.setCurrentIndex(0);
              },
              child: const Text('Family Hub'),
            ),
            actions: [
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'invite',
                    child: Row(
                      children: [
                        Icon(Icons.person_add, size: 20),
                        SizedBox(width: 8),
                        Text('Invite Family'),
                      ],
                    ),
                  ),
        const PopupMenuItem(
          value: 'join',
          child: Row(
            children: [
              Icon(Icons.group_add, size: 20),
              SizedBox(width: 8),
              Text('Join Family'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person, size: 20),
              SizedBox(width: 8),
              Text('Edit Profile'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'calendar_sync',
          child: Row(
            children: [
              Icon(Icons.sync, size: 20),
              SizedBox(width: 8),
              Text('Calendar Sync'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'privacy',
          child: Row(
            children: [
              Icon(Icons.privacy_tip, size: 20),
              SizedBox(width: 8),
              Text('Privacy Center'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'roles',
          child: Row(
            children: [
              Icon(Icons.admin_panel_settings, size: 20),
              SizedBox(width: 8),
              Text('Manage Roles'),
            ],
          ),
        ),
                      const PopupMenuItem(
                        value: 'migration',
                        child: Row(
                          children: [
                            Icon(Icons.sync, size: 20),
                            SizedBox(width: 8),
                            Text('Run Migration'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'reset',
                        child: Row(
                          children: [
                            Icon(Icons.delete_forever, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Reset Database', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
        const PopupMenuItem(
          value: 'fix_family',
          child: Row(
            children: [
              Icon(Icons.family_restroom, size: 20, color: Colors.orange),
              SizedBox(width: 8),
              Text('Fix Family Link', style: TextStyle(color: Colors.orange)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'force_signout',
          child: Row(
            children: [
              Icon(Icons.refresh, size: 20, color: Colors.blue),
              SizedBox(width: 8),
              Text('Refresh Session', style: TextStyle(color: Colors.blue)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'debug',
          child: Row(
            children: [
              Icon(Icons.bug_report, size: 20),
              SizedBox(width: 8),
              Text('Debug User Info'),
            ],
          ),
        ),
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Logout', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) async {
                  if (value == 'invite') {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FamilyInvitationScreen(),
                      ),
                    );
                  } else if (value == 'join') {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const JoinFamilyScreen(),
                      ),
                    );
          // If successfully joined, refresh the app state
          if (result == true && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Please restart the app to see family members'),
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else if (value == 'profile') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditProfileScreen(),
            ),
          );
        } else if (value == 'calendar_sync') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CalendarSyncSettingsScreen(),
            ),
          );
        } else if (value == 'privacy') {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const PrivacyCenterScreen(),
            ),
          );
        } else if (value == 'roles') {
          // Check if user is Admin before allowing role management
          final userModel = await authService.getCurrentUserModel();
          if (userModel != null && userModel.isAdmin()) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const RoleManagementScreen(),
              ),
            );
          } else {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Only Admins can manage roles'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        } else if (value == 'migration') {
          // Check if user is Admin before allowing migration
          final userModel = await authService.getCurrentUserModel();
          if (userModel != null && userModel.isAdmin()) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const MigrationScreen(),
              ),
            );
                        } else {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Only Admins can run migrations'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      } else if (value == 'reset') {
                        // Show warning before allowing database reset
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('⚠️ Warning'),
                            content: const Text(
                              'Database Reset will permanently delete your account and all data. '
                              'This is for development/testing only. Continue?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Continue'),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirm == true && context.mounted) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DatabaseResetScreen(),
                            ),
                          );
                        }
                      } else if (value == 'fix_family') {
                        // Quick fix to re-link to Kate's family
                        await _showFixFamilyDialog(context, authService);
                      } else if (value == 'force_signout') {
                        // Force sign out to clear persisted session and refresh
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Refresh Session'),
                            content: const Text(
                              'This will sign you out and clear your session. '
                              'Use this if you\'re seeing an empty dashboard or missing data. '
                              'You\'ll need to sign back in after.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                                child: const Text('Sign Out & Refresh'),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && context.mounted) {
                          await authService.signOut();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Signed out. Please sign back in.'),
                                backgroundColor: Colors.blue,
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      } else if (value == 'debug') {
                        // Show debug information
                        final user = authService.currentUser;
                        if (user != null) {
                          UserModel? userModel;
                          try {
                            userModel = await authService.getCurrentUserModel();
                          } catch (e) {
                            // If getCurrentUserModel fails (orphaned account), userModel will be null
                            debugPrint('getCurrentUserModel failed (likely orphaned account): $e');
                          }
                          if (context.mounted) {
                            await showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('User Debug Info'),
                                content: SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('User ID: ${user.uid}'),
                                      const SizedBox(height: 8),
                                      Text('Email: ${user.email ?? "N/A"}'),
                                      const SizedBox(height: 8),
                                      Text('Firebase Auth Display Name: ${user.displayName ?? "N/A"}'),
                                      const SizedBox(height: 16),
                                      const Divider(),
                                      const SizedBox(height: 8),
                                      Text('User Document Exists: ${userModel != null ? "Yes" : "No"}'),
                                      if (userModel != null) ...[
                                        const SizedBox(height: 8),
                                        Text('Firestore Display Name: ${userModel.displayName}'),
                                        const SizedBox(height: 8),
                                        Text('Family ID: ${userModel.familyId ?? "None"}'),
                                        const SizedBox(height: 8),
                                        Text('Created At: ${userModel.createdAt}'),
                                      ] else ...[
                                        const SizedBox(height: 8),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Text(
                                            '⚠️ Orphaned Account: Auth account exists but Firestore document is missing.',
                                            style: TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      try {
                                        await authService.forceInitializeFamilyId();
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('User document created/updated! Please refresh the app.'),
                                              backgroundColor: Colors.green,
                                              duration: Duration(seconds: 3),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          final errorMsg = e.toString();
                                          final isPermissionError = errorMsg.contains('permission-denied') || 
                                                                    errorMsg.contains('permission denied');
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                isPermissionError 
                                                  ? 'Permission denied. Please ensure Firestore rules are published in Firebase Console.'
                                                  : 'Error: $e'
                                              ),
                                              backgroundColor: Colors.red,
                                              duration: const Duration(seconds: 5),
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    child: const Text('Fix User Document'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      try {
                                        await authService.updateDisplayNameFromAuth();
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Display name updated! Please restart the app.'),
                                              backgroundColor: Colors.green,
                                              duration: Duration(seconds: 5),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Fix Display Name'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      try {
                                        await authService.selfAssignAdminRole();
                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('Admin role added! Please restart the app.'),
                                              backgroundColor: Colors.green,
                                              duration: Duration(seconds: 5),
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Add Admin Role (One-time)'),
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final controller = TextEditingController();
                                      final result = await showDialog<bool>(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                          title: const Text('Join Family'),
                                          content: TextField(
                                            controller: controller,
                                            decoration: const InputDecoration(
                                              labelText: 'Enter Family ID',
                                              hintText: 'Paste family ID here',
                                              border: OutlineInputBorder(),
                                            ),
                                            autofocus: true,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(context, false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              onPressed: () => Navigator.pop(context, true),
                                              child: const Text('Join'),
                                            ),
                                          ],
                                        ),
                                      );
                                      
                                      if (result == true && controller.text.trim().isNotEmpty) {
                                        try {
                                          await authService.joinFamilyByInvitationCode(controller.text.trim());
                                          if (context.mounted) {
                                            Navigator.pop(context);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Successfully joined family! Please restart the app.'),
                                                backgroundColor: Colors.green,
                                                duration: Duration(seconds: 5),
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Error joining family: $e'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      }
                                      controller.dispose();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Join Family (Manual)'),
                                  ),
                                  if (userModel == null)
                                    ElevatedButton(
                                      onPressed: () async {
                                        final passwordController = TextEditingController();
                                        final password = await showDialog<String>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Force Delete Auth Account'),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Text(
                                                  'This will delete your Firebase Auth account only (Firestore data is already missing).\n\n'
                                                  'You will be signed out and can create a new account.\n\n'
                                                  'This action cannot be undone.',
                                                ),
                                                const SizedBox(height: 16),
                                                TextField(
                                                  controller: passwordController,
                                                  decoration: const InputDecoration(
                                                    labelText: 'Enter Password to Confirm',
                                                    hintText: 'Your account password',
                                                    border: OutlineInputBorder(),
                                                  ),
                                                  obscureText: true,
                                                  autofocus: true,
                                                  onSubmitted: (value) => Navigator.pop(context, value),
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
                                                child: const Text('Cancel'),
                                              ),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(context, passwordController.text),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  foregroundColor: Colors.white,
                                                ),
                                                child: const Text('Delete Account'),
                                              ),
                                            ],
                                          ),
                                        );
                                        
                                        if (password != null && password.isNotEmpty && context.mounted) {
                                          try {
                                            await authService.deleteCurrentUserAccount(
                                              password: password,
                                              skipFirestoreDeletion: true,
                                            );
                                            if (context.mounted) {
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Auth account deleted. You will be signed out.'),
                                                  backgroundColor: Colors.green,
                                                  duration: Duration(seconds: 5),
                                                ),
                                              );
                                            }
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error deleting account: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        }
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: const Text('Force Delete Auth Account'),
                                    ),
                                ],
                              ),
                            );
                          }
                        }
                      } else if (value == 'logout') {
                    await authService.signOut();
                  }
                },
              ),
            ],
          ),
          body: IndexedStack(
            index: appState.currentIndex,
            children: const [
              DashboardScreen(),
              CalendarScreen(),
              TasksScreen(),
              ChatScreen(),
              GamesHomeScreen(),
              PhotosHomeScreen(),
              LocationScreen(),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: appState.currentIndex,
            onDestinationSelected: (index) {
              appState.setCurrentIndex(index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today),
                label: 'Calendar',
              ),
              NavigationDestination(
                icon: Icon(Icons.task_outlined),
                selectedIcon: Icon(Icons.task),
                label: 'Jobs',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Chat',
              ),
              NavigationDestination(
                icon: Icon(Icons.sports_esports_outlined),
                selectedIcon: Icon(Icons.sports_esports),
                label: 'Games',
              ),
              NavigationDestination(
                icon: Icon(Icons.photo_library_outlined),
                selectedIcon: Icon(Icons.photo_library),
                label: 'Photos',
              ),
              NavigationDestination(
                icon: Icon(Icons.location_on_outlined),
                selectedIcon: Icon(Icons.location_on),
                label: 'Location',
              ),
            ],
          ),
        );
      },
    );
  }
}

