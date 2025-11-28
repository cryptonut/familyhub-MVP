import 'package:flutter/foundation.dart';

/// Centralized logging service with log levels
/// 
/// Usage:
/// ```dart
/// Logger.debug('Debug message', tag: 'AuthService');
/// Logger.info('Info message');
/// Logger.warning('Warning message');
/// Logger.error('Error message', error: e, stackTrace: st);
/// ```
class Logger {
  Logger._(); // Prevent instantiation

  /// Minimum log level - only logs at or above this level
  static LogLevel _minLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  /// Set minimum log level (useful for production)
  static void setMinLevel(LogLevel level) {
    _minLevel = level;
  }

  /// Debug level logs (only in debug mode)
  static void debug(String message, {String? tag}) {
    _log(LogLevel.debug, message, tag: tag);
  }

  /// Info level logs
  static void info(String message, {String? tag}) {
    _log(LogLevel.info, message, tag: tag);
  }

  /// Warning level logs
  /// 
  /// [error] - The error object (optional)
  /// [stackTrace] - Stack trace (optional)
  /// [tag] - Tag for categorizing logs
  static void warning(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    _log(LogLevel.warning, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  /// Error level logs
  /// 
  /// [error] - The error object (optional)
  /// [stackTrace] - Stack trace (optional)
  /// [tag] - Tag for categorizing logs
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
  }) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
    
    // In production, report to crash analytics
    if (!kDebugMode && error != null) {
      // TODO: Integrate Firebase Crashlytics or similar
      // FirebaseCrashlytics.instance.recordError(error, stackTrace);
    }
  }

  /// Internal log method
  static void _log(
    LogLevel level,
    String message, {
    String? tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    // Skip if below minimum level
    if (level.index < _minLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final tagStr = tag != null ? '[$tag] ' : '';
    final levelStr = level.name.toUpperCase().padRight(7);
    
    final logMessage = '$levelStr $timestamp $tagStr$message';
    
    if (kDebugMode) {
      debugPrint(logMessage);
      if (error != null) {
        debugPrint('  Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('  Stack: $stackTrace');
      }
    } else {
      // In production, use a proper logging service
      // For now, still use debugPrint but without sensitive info
      debugPrint(logMessage);
    }
  }

  /// Safely log API key (only shows first N characters)
  static void logApiKey(String? apiKey, {String? tag, int displayLength = 10}) {
    if (apiKey == null || apiKey.isEmpty) {
      warning('API Key: NULL or empty', tag: tag);
      return;
    }
    
    final maskedKey = apiKey.length > displayLength
        ? '${apiKey.substring(0, displayLength)}...'
        : '${'*' * apiKey.length}';
    
    info('API Key: $maskedKey', tag: tag);
  }
}

/// Log levels in order of severity
enum LogLevel {
  debug,   // Most verbose
  info,    // Informational
  warning, // Warnings
  error,   // Errors only
}

