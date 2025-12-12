import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/services/logger_service.dart';
import '../core/errors/app_exceptions.dart';
import '../models/widget_config.dart';
import '../utils/firestore_path_utils.dart';
import 'auth_service.dart';

/// Service for managing widget configurations
class WidgetConfigurationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final AuthService _authService = AuthService();

  String? get currentUserId => _auth.currentUser?.uid;

  /// Save widget configuration to Firestore
  Future<void> saveWidgetConfig(WidgetConfig config) async {
    final userId = currentUserId;
    if (userId == null) {
      throw AuthException('User not logged in', code: 'not-authenticated');
    }

    if (config.userId != userId) {
      throw ValidationException('Widget config userId must match current user');
    }

    try {
      final configData = config.toJson();
      configData.remove('widgetId'); // Don't store widgetId in document ID

      await _firestore
          .collection(FirestorePathUtils.getUserSubcollectionPath(userId, 'widgetConfigs'))
          .doc(config.widgetId)
          .set(configData, SetOptions(merge: true));

      Logger.debug('Widget config saved: ${config.widgetId}', tag: 'WidgetConfigurationService');
    } catch (e, st) {
      Logger.error('Error saving widget config', error: e, stackTrace: st, tag: 'WidgetConfigurationService');
      throw AppException('Failed to save widget configuration: $e');
    }
  }

  /// Get widget configuration by widget ID
  Future<WidgetConfig?> getWidgetConfig(String widgetId) async {
    final userId = currentUserId;
    if (userId == null) return null;

    try {
      final doc = await _firestore
          .collection(FirestorePathUtils.getUserSubcollectionPath(userId, 'widgetConfigs'))
          .doc(widgetId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      data['widgetId'] = widgetId; // Add widgetId back to data
      return WidgetConfig.fromJson(data);
    } catch (e, st) {
      Logger.error('Error getting widget config', error: e, stackTrace: st, tag: 'WidgetConfigurationService');
      return null;
    }
  }

  /// Get all widget configurations for current user
  Future<List<WidgetConfig>> getUserWidgets() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final snapshot = await _firestore
          .collection(FirestorePathUtils.getUserSubcollectionPath(userId, 'widgetConfigs'))
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['widgetId'] = doc.id;
        return WidgetConfig.fromJson(data);
      }).toList();
    } catch (e, st) {
      Logger.error('Error getting user widgets', error: e, stackTrace: st, tag: 'WidgetConfigurationService');
      return [];
    }
  }

  /// Delete widget configuration
  Future<void> deleteWidgetConfig(String widgetId) async {
    final userId = currentUserId;
    if (userId == null) {
      throw AuthException('User not logged in', code: 'not-authenticated');
    }

    try {
      await _firestore
          .collection(FirestorePathUtils.getUserSubcollectionPath(userId, 'widgetConfigs'))
          .doc(widgetId)
          .delete();

      Logger.debug('Widget config deleted: $widgetId', tag: 'WidgetConfigurationService');
    } catch (e, st) {
      Logger.error('Error deleting widget config', error: e, stackTrace: st, tag: 'WidgetConfigurationService');
      throw AppException('Failed to delete widget configuration: $e');
    }
  }

  /// Update widget configuration
  Future<void> updateWidgetConfig(WidgetConfig config) async {
    final updatedConfig = config.copyWith(updatedAt: DateTime.now());
    await saveWidgetConfig(updatedConfig);
  }
}

