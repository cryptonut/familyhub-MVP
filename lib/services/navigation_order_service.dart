import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/logger_service.dart';
import '../utils/firestore_path_utils.dart';
import '../services/auth_service.dart';

/// Service for managing navigation bar item order (stored in Firestore per user)
class NavigationOrderService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();
  
  // Default order (Home is always 0)
  static const List<int> _defaultOrder = [0, 1, 2, 3, 4, 5, 6]; // Home, Calendar, Jobs, Games, Photos, Shopping, Location
  
  /// Get the current navigation order for the user
  Future<List<int>> getNavigationOrder() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        Logger.warning('User not authenticated, returning default order', tag: 'NavigationOrderService');
        return List.from(_defaultOrder);
      }

      final userDoc = await _firestore.collection(FirestorePathUtils.getUsersCollection()).doc(userId).get();
      
      if (!userDoc.exists || userDoc.data() == null) {
        return List.from(_defaultOrder);
      }
      
      final data = userDoc.data()!;
      final orderList = data['navigationOrder'] as List<dynamic>?;
      
      if (orderList == null) {
        return List.from(_defaultOrder);
      }
      
      final order = orderList.map((e) => (e as num).toInt()).toList();
      
      // Validate order: must contain all indices 0-6, and 0 must be first
      if (order.length != 7 || order[0] != 0 || !order.every((i) => i >= 0 && i < 7)) {
        Logger.warning('Invalid navigation order, resetting to default', tag: 'NavigationOrderService');
        await resetToDefault();
        return List.from(_defaultOrder);
      }
      
      return order;
    } catch (e) {
      Logger.error('Error getting navigation order', error: e, tag: 'NavigationOrderService');
      return List.from(_defaultOrder);
    }
  }
  
  /// Save the navigation order to Firestore
  Future<void> saveNavigationOrder(List<int> order) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Validate: Home (0) must be first
      if (order.isEmpty || order[0] != 0) {
        throw Exception('Home must be first in navigation order');
      }
      
      // Validate: must contain all indices 0-6
      if (order.length != 7 || !order.every((i) => i >= 0 && i < 7)) {
        throw Exception('Navigation order must contain all indices 0-6');
      }
      
      await _firestore.collection(FirestorePathUtils.getUsersCollection()).doc(userId).set({
        'navigationOrder': order,
      }, SetOptions(merge: true));
      
      Logger.info('Navigation order saved to Firestore: $order', tag: 'NavigationOrderService');
    } catch (e) {
      Logger.error('Error saving navigation order', error: e, tag: 'NavigationOrderService');
      rethrow;
    }
  }
  
  /// Reset to default order
  Future<void> resetToDefault() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) {
        Logger.warning('User not authenticated, cannot reset order', tag: 'NavigationOrderService');
        return;
      }

      await _firestore.collection(FirestorePathUtils.getUsersCollection()).doc(userId).set({
        'navigationOrder': _defaultOrder,
      }, SetOptions(merge: true));
      
      Logger.info('Navigation order reset to default', tag: 'NavigationOrderService');
    } catch (e) {
      Logger.error('Error resetting navigation order', error: e, tag: 'NavigationOrderService');
    }
  }
  
  /// Get the screen index for a given navigation index
  Future<int> getScreenIndex(int navigationIndex) async {
    final order = await getNavigationOrder();
    return order[navigationIndex];
  }
  
  /// Get the navigation index for a given screen index
  Future<int> getNavigationIndex(int screenIndex) async {
    final order = await getNavigationOrder();
    return order.indexOf(screenIndex);
  }
}

