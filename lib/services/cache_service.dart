import 'dart:async';
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../core/services/logger_service.dart';
import '../core/constants/app_constants.dart';

class CacheService {
  static final CacheService _instance = CacheService._internal();
  factory CacheService() => _instance;
  CacheService._internal();

  Box? _box;
  bool _initialized = false;
  bool _initializing = false;
  final Completer<void> _initCompleter = Completer<void>();

  /// Initialize cache service - truly non-blocking with timeout protection
  /// This prevents file system operations from interfering with Firebase Auth
  Future<void> initialize() async {
    // If already initialized, return immediately
    if (_initialized) return;
    
    // If currently initializing, wait for existing initialization to complete
    if (_initializing) {
      return _initCompleter.future;
    }

    _initializing = true;

    try {
      // CRITICAL FIX: Add timeout to prevent blocking Firebase Auth
      // getApplicationDocumentsDirectory() can block on Android, especially on first run
      final directory = await getApplicationDocumentsDirectory()
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () {
              Logger.warning('Cache: getApplicationDocumentsDirectory() timed out - using fallback', tag: 'CacheService');
              throw TimeoutException('Directory access timed out');
            },
          );
      
      // Initialize Hive with timeout protection
      await Future(() {
        Hive.init(directory.path);
      }).timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          Logger.warning('Cache: Hive.init() timed out', tag: 'CacheService');
          throw TimeoutException('Hive initialization timed out');
        },
      );
      
      // Open box with timeout
      _box = await Hive.openBox('app_cache')
          .timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              Logger.warning('Cache: Hive.openBox() timed out', tag: 'CacheService');
              throw TimeoutException('Box opening timed out');
            },
          );
      
      _initialized = true;
      Logger.info('Cache service initialized successfully', tag: 'CacheService');
      
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    } on TimeoutException catch (e, st) {
      Logger.warning('Cache initialization timed out - cache will be disabled', error: e, stackTrace: st, tag: 'CacheService');
      _initialized = false;
      _box = null;
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e);
      }
    } catch (e, st) {
      Logger.warning('Cache initialization failed - cache will be disabled', error: e, stackTrace: st, tag: 'CacheService');
      _initialized = false;
      _box = null;
      if (!_initCompleter.isCompleted) {
        _initCompleter.completeError(e);
      }
    } finally {
      _initializing = false;
    }
  }

  Future<T?> get<T>(String key) async {
    // Don't block if initialization fails - just return null
    if (!_initialized) {
      try {
        await initialize().timeout(const Duration(seconds: 1));
      } catch (e) {
        // Initialization failed or timed out - return null without blocking
        return null;
      }
    }
    if (_box == null) return null;

    try {
      final value = _box!.get(key);
      if (value == null) return null;

      // Handle different types
      if (T == String) {
        return value as T;
      } else if (T == int || T == double || T == bool) {
        return value as T;
      } else {
        // JSON decode for complex types
        final jsonStr = value as String;
        final json = jsonDecode(jsonStr);
        return json as T;
      }
    } catch (e) {
      Logger.warning('Error getting cache value for key: $key', error: e, tag: 'CacheService');
      return null;
    }
  }

  Future<void> set<T>(String key, T value, {Duration? ttl}) async {
    // Don't block if initialization fails - just return
    if (!_initialized) {
      try {
        await initialize().timeout(const Duration(seconds: 1));
      } catch (e) {
        // Initialization failed or timed out - return without blocking
        return;
      }
    }
    if (_box == null) return;

    try {
      dynamic cacheValue;
      if (value is String || value is int || value is double || value is bool) {
        cacheValue = value;
      } else {
        // JSON encode for complex types
        cacheValue = jsonEncode(value);
      }

      final cacheEntry = {
        'value': cacheValue,
        'expiresAt': ttl != null ? DateTime.now().add(ttl).toIso8601String() : null,
      };

      await _box!.put(key, jsonEncode(cacheEntry));
    } catch (e) {
      Logger.warning('Error setting cache value for key: $key', error: e, tag: 'CacheService');
    }
  }

  Future<void> delete(String key) async {
    if (!_initialized) {
      try {
        await initialize().timeout(const Duration(seconds: 1));
      } catch (e) {
        return;
      }
    }
    if (_box == null) return;

    try {
      await _box!.delete(key);
    } catch (e) {
      Logger.warning('Error deleting cache value for key: $key', error: e, tag: 'CacheService');
    }
  }

  Future<void> clear() async {
    if (!_initialized) {
      try {
        await initialize().timeout(const Duration(seconds: 1));
      } catch (e) {
        return;
      }
    }
    if (_box == null) return;

    try {
      await _box!.clear();
      Logger.info('Cache cleared', tag: 'CacheService');
    } catch (e) {
      Logger.warning('Error clearing cache', error: e, tag: 'CacheService');
    }
  }

  Future<int> getCacheSize() async {
    if (!_initialized) {
      try {
        await initialize().timeout(const Duration(seconds: 1));
      } catch (e) {
        return 0;
      }
    }
    if (_box == null) return 0;

    try {
      int size = 0;
      for (var key in _box!.keys) {
        final value = _box!.get(key);
        if (value is String) {
          size += value.length;
        }
      }
      return size;
    } catch (e) {
      return 0;
    }
  }

  Future<void> clearExpired() async {
    if (!_initialized) {
      try {
        await initialize().timeout(const Duration(seconds: 1));
      } catch (e) {
        return;
      }
    }
    if (_box == null) return;

    try {
      final now = DateTime.now();
      final keysToDelete = <String>[];

      for (var key in _box!.keys) {
        final value = _box!.get(key);
        if (value is String) {
          try {
            final entry = jsonDecode(value) as Map<String, dynamic>;
            final expiresAt = entry['expiresAt'] as String?;
            if (expiresAt != null) {
              final expiry = DateTime.parse(expiresAt);
              if (now.isAfter(expiry)) {
                keysToDelete.add(key.toString());
              }
            }
          } catch (e) {
            // Invalid entry, skip
          }
        }
      }

      for (var key in keysToDelete) {
        await _box!.delete(key);
      }

      if (keysToDelete.isNotEmpty) {
        Logger.info('Cleared ${keysToDelete.length} expired cache entries', tag: 'CacheService');
      }
    } catch (e) {
      Logger.warning('Error clearing expired cache', error: e, tag: 'CacheService');
    }
  }
}

