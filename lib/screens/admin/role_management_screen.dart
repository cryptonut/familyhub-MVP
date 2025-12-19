import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../models/user_model.dart';

class RoleManagementScreen extends StatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  State<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends State<RoleManagementScreen> {
  final AuthService _authService = AuthService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<UserModel> _familyMembers = [];
  bool _isLoading = true;
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadFamilyMembers();
  }

  Future<void> _loadFamilyMembers() async {
    setState(() => _isLoading = true);
    
    try {
      _currentUser = await _authService.getCurrentUserModel();
      if (_currentUser == null || !_currentUser!.isAdmin()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only Admins can manage roles'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }
      
      _familyMembers = await _authService.getFamilyMembers();
      // Sort: current user first, then by name
      _familyMembers.sort((a, b) {
        if (a.uid == _auth.currentUser?.uid) return -1;
        if (b.uid == _auth.currentUser?.uid) return 1;
        return a.displayName.compareTo(b.displayName);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading family members: $e'),
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

  Future<void> _updateUserRoles(UserModel user, List<String> newRoles) async {
    try {
      await _authService.assignRoles(user.uid, newRoles);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Roles updated for ${user.displayName}'),
            backgroundColor: Colors.green,
          ),
        );
        _loadFamilyMembers(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating roles: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Role Management')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Role Management'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadFamilyMembers,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Role Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildRoleInfo('Admin', 'Full access: can assign roles, create jobs with rewards, approve jobs'),
                    const SizedBox(height: 8),
                    _buildRoleInfo('Banker', 'Can create jobs with rewards (mints in-app currency)'),
                    const SizedBox(height: 8),
                    _buildRoleInfo('Approver', 'Can approve any job regardless of creator'),
                    const SizedBox(height: 8),
                    _buildRoleInfo('Tester', 'Can access User Acceptance Testing (UAT) features for testing new releases'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Family Members',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ..._familyMembers.map((member) => _buildMemberCard(member)),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleInfo(String role, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getRoleColor(role).withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            role,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _getRoleColor(role),
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberCard(UserModel member) {
    final isCurrentUser = member.uid == _auth.currentUser?.uid;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    member.displayName[0].toUpperCase(),
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            member.displayName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (isCurrentUser) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'You',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        member.email,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Roles:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!(_currentUser?.isAdmin() ?? false)) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.lock, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  Text(
                    'Only Admins can edit',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildRoleChip('Admin', member.isAdmin(), (value) {
                  _toggleRole(member, 'admin', value);
                }, member.isAdmin() && isCurrentUser, _currentUser?.isAdmin() ?? false),
                _buildRoleChip('Banker', member.isBanker(), (value) {
                  _toggleRole(member, 'banker', value);
                }, false, _currentUser?.isAdmin() ?? false),
                _buildRoleChip('Approver', member.isApprover(), (value) {
                  _toggleRole(member, 'approver', value);
                }, false, _currentUser?.isAdmin() ?? false),
                _buildRoleChip('Tester', member.hasRole('tester'), (value) {
                  _toggleRole(member, 'tester', value);
                }, false, _currentUser?.isAdmin() ?? false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip(String role, bool hasRole, Function(bool) onChanged, bool isCurrentUserAdminRole, bool isCurrentUserAdmin) {
    // Only Admins can edit roles
    // The check for preventing removal of own Admin role (if last Admin) is handled in _toggleRole
    final canEdit = isCurrentUserAdmin;
    
    return FilterChip(
      label: Text(role),
      selected: hasRole,
      onSelected: canEdit ? onChanged : null,
      selectedColor: _getRoleColor(role).withOpacity(0.2),
      checkmarkColor: _getRoleColor(role),
      labelStyle: TextStyle(
        color: hasRole ? _getRoleColor(role) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
        fontWeight: hasRole ? FontWeight.bold : FontWeight.normal,
      ),
      tooltip: !isCurrentUserAdmin 
          ? 'Only Admins can edit roles' 
          : null,
    );
  }

  void _toggleRole(UserModel member, String role, bool add) {
    // Double-check that current user is Admin (security check)
    if (_currentUser == null || !_currentUser!.isAdmin()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Only Admins can edit roles'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    final currentRoles = List<String>.from(member.roles);
    final isTargetUserCurrentUser = member.uid == _auth.currentUser?.uid;
    
    if (add) {
      if (!currentRoles.contains(role)) {
        currentRoles.add(role);
      }
    } else {
      // Prevent removing Admin role from current user (last Admin protection)
      if (role == 'admin' && isTargetUserCurrentUser) {
        // Check if there are other Admins in the family
        final otherAdmins = _familyMembers.where((m) => 
          m.uid != member.uid && m.isAdmin()
        ).length;
        
        if (otherAdmins == 0) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot remove Admin role: You are the only Admin. Assign Admin to another user first.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
          return;
        }
      }
      currentRoles.remove(role);
    }
    
    _updateUserRoles(member, currentRoles);
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'banker':
        return Colors.blue;
      case 'approver':
        return Colors.green;
      case 'tester':
        return Colors.teal;
      default:
        return Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);
    }
  }
}

