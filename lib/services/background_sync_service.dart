import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'calendar_sync_service.dart';

/// Service for background calendar synchronization
class BackgroundSyncService {
  static const String _syncTaskName = 'calendarSyncTask';
  static const Duration _syncInterval = Duration(minutes: 30);

  /// Initialize background sync
  static Future<void> initialize() async {
    try {
      await Workmanager().initialize(
        _callbackDispatcher,
        isInDebugMode: kDebugMode,
      );
      debugPrint('Background sync service initialized');
    } catch (e) {
      debugPrint('Error initializing background sync: $e');
    }
  }

  /// Register periodic sync task
  static Future<void> registerPeriodicSync() async {
    try {
      await Workmanager().registerPeriodicTask(
        _syncTaskName,
        _syncTaskName,
        frequency: _syncInterval,
        constraints: Constraints(
          networkType: NetworkType.connected,
          requiresBatteryNotLow: false,
          requiresCharging: false,
          requiresDeviceIdle: false,
          requiresStorageNotLow: false,
        ),
      );
      debugPrint('Periodic calendar sync registered');
    } catch (e) {
      debugPrint('Error registering periodic sync: $e');
    }
  }

  /// Cancel periodic sync
  static Future<void> cancelPeriodicSync() async {
    try {
      await Workmanager().cancelByUniqueName(_syncTaskName);
      debugPrint('Periodic calendar sync cancelled');
    } catch (e) {
      debugPrint('Error cancelling periodic sync: $e');
    }
  }

  /// One-time sync task
  static Future<void> triggerSync() async {
    try {
      await Workmanager().registerOneOffTask(
        '${_syncTaskName}_${DateTime.now().millisecondsSinceEpoch}',
        _syncTaskName,
        initialDelay: const Duration(seconds: 5),
      );
    } catch (e) {
      debugPrint('Error triggering sync: $e');
    }
  }
}

/// Background callback dispatcher (must be top-level)
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('Background calendar sync started');
      final syncService = CalendarSyncService();
      await syncService.performSync();
      debugPrint('Background calendar sync completed');
      return true;
    } catch (e) {
      debugPrint('Background calendar sync error: $e');
      return false;
    }
  });
}

