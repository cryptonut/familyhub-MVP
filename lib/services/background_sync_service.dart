import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../core/services/logger_service.dart';
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
      Logger.info('Background sync service initialized', tag: 'BackgroundSyncService');
    } catch (e, st) {
      Logger.error('Error initializing background sync', error: e, stackTrace: st, tag: 'BackgroundSyncService');
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
      Logger.info('Periodic calendar sync registered', tag: 'BackgroundSyncService');
    } catch (e, st) {
      Logger.error('Error registering periodic sync', error: e, stackTrace: st, tag: 'BackgroundSyncService');
    }
  }

  /// Cancel periodic sync
  static Future<void> cancelPeriodicSync() async {
    try {
      await Workmanager().cancelByUniqueName(_syncTaskName);
      Logger.info('Periodic calendar sync cancelled', tag: 'BackgroundSyncService');
    } catch (e, st) {
      Logger.error('Error cancelling periodic sync', error: e, stackTrace: st, tag: 'BackgroundSyncService');
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
    } catch (e, st) {
      Logger.error('Error triggering sync', error: e, stackTrace: st, tag: 'BackgroundSyncService');
    }
  }
}

/// Background callback dispatcher (must be top-level)
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      Logger.info('Background calendar sync started', tag: 'BackgroundSyncService');
      final syncService = CalendarSyncService();
      await syncService.performSync();
      Logger.info('Background calendar sync completed', tag: 'BackgroundSyncService');
      return true;
    } catch (e, st) {
      Logger.error('Background calendar sync error', error: e, stackTrace: st, tag: 'BackgroundSyncService');
      return false;
    }
  });
}

