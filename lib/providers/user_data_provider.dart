import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../core/services/logger_service.dart';

/// Shared state provider for user and family data
/// Reduces redundant Firestore queries across screens
class UserDataProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  UserModel? _currentUser;
  List<UserModel> _familyMembers = [];
  UserModel? _familyCreator;
  bool _isLoading = false;
  DateTime? _lastRefresh;
  static const Duration _cacheTTL = Duration(minutes: 5);

  UserModel? get currentUser => _currentUser;
  List<UserModel> get familyMembers => _familyMembers;
  UserModel? get familyCreator => _familyCreator;
  bool get isLoading => _isLoading;
  bool get hasData => _currentUser != null;

  /// Get cached data if available and fresh, otherwise fetch
  Future<void> loadUserData({bool forceRefresh = false}) async {
    // Return cached data if fresh and not forcing refresh
    if (!forceRefresh && _currentUser != null && _lastRefresh != null) {
      final age = DateTime.now().difference(_lastRefresh!);
      if (age < _cacheTTL) {
        Logger.debug('Using cached user data (age: ${age.inSeconds}s)', tag: 'UserDataProvider');
        return;
      }
    }

    if (_isLoading) {
      Logger.debug('User data already loading, skipping', tag: 'UserDataProvider');
      return;
    }

    _isLoading = true;
    // Defer notification to avoid setState during build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_isLoading) { // Only notify if still loading (wasn't cancelled)
        notifyListeners();
      }
    });

    try {
      // Load user model
      _currentUser = await _authService.getCurrentUserModel();
      
      if (_currentUser == null) {
        Logger.warning('No current user found', tag: 'UserDataProvider');
        _isLoading = false;
        notifyListeners();
        return;
      }

      // Load family members
      _familyMembers = await _authService.getFamilyMembers();
      
      // Load family creator (non-critical)
      try {
        _familyCreator = await _authService.getFamilyCreator();
      } catch (e) {
        Logger.warning('Error loading family creator (non-critical)', error: e, tag: 'UserDataProvider');
        _familyCreator = null;
      }

      _lastRefresh = DateTime.now();
      Logger.debug('User data loaded: ${_familyMembers.length} family members', tag: 'UserDataProvider');
    } catch (e, stackTrace) {
      Logger.error('Error loading user data', error: e, stackTrace: stackTrace, tag: 'UserDataProvider');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh data in background (doesn't block UI)
  Future<void> refreshInBackground() async {
    if (_isLoading) return;
    
    try {
      final user = await _authService.getCurrentUserModel();
      if (user != null) {
        final members = await _authService.getFamilyMembers();
        
        // Always update with fresh data to catch profile changes (photo, name, etc.)
        _currentUser = user;
        _familyMembers = members;
        _lastRefresh = DateTime.now();
        notifyListeners();
      }
    } catch (e) {
      Logger.warning('Background refresh failed', error: e, tag: 'UserDataProvider');
    }
  }

  /// Clear cached data
  void clearCache() {
    _currentUser = null;
    _familyMembers = [];
    _familyCreator = null;
    _lastRefresh = null;
    notifyListeners();
  }

  /// Refresh data (force reload)
  Future<void> refresh() async {
    await loadUserData(forceRefresh: true);
  }

  /// Get user model by ID (with caching)
  Future<UserModel?> getUserModel(String userId) async {
    // Check family members first (most common case)
    final member = _familyMembers.firstWhere(
      (m) => m.uid == userId,
      orElse: () => UserModel(
        uid: '', 
        email: '', 
        displayName: '',
        createdAt: DateTime.now(),
        familyId: '',
      ),
    );
    if (member.uid.isNotEmpty) {
      return member;
    }

    // Fallback to service
    return await _authService.getUserModel(userId);
  }
}

