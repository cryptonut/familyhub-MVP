import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../core/services/logger_service.dart';

/// Types of operations that can be queued
enum QueuedOperationType {
  addTask,
  updateTask,
  deleteTask,
  sendMessage,
  addEvent,
  updateEvent,
  deleteEvent,
  uploadPhoto,
}

/// A queued operation for offline execution
class QueuedOperation {
  final String id;
  final QueuedOperationType type;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;

  QueuedOperation({
    required this.id,
    required this.type,
    required this.data,
    DateTime? createdAt,
    this.retryCount = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.toString(),
    'data': data,
    'createdAt': createdAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory QueuedOperation.fromJson(Map<String, dynamic> json) => QueuedOperation(
    id: json['id'],
    type: QueuedOperationType.values.firstWhere(
      (e) => e.toString() == json['type']
    ),
    data: json['data'],
    createdAt: DateTime.parse(json['createdAt']),
    retryCount: json['retryCount'] ?? 0,
  );
}

/// Service for queuing operations when offline and executing them when back online
class OfflineQueueService {
  static final OfflineQueueService _instance = OfflineQueueService._internal();
  factory OfflineQueueService() => _instance;
  OfflineQueueService._internal();

  final Queue<QueuedOperation> _queue = Queue<QueuedOperation>();
  final Map<String, Completer<void>> _pendingOperations = {};
  bool _isProcessing = false;
  bool _isInitialized = false;
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;
  
  // Hive box for persistent storage
  static const String _queueBoxName = 'offline_queue';
  Box? _queueBox;

  /// Initialize the offline queue service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Hive box for persistent storage
      _queueBox = await Hive.openBox(_queueBoxName);
      
      // Load queued operations from storage
      await _loadFromLocalStorage();

      // Listen for connectivity changes
      _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
        _onConnectivityChanged
      );

      // Check initial connectivity and process queue if online
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        _processQueue();
      }

      _isInitialized = true;
      Logger.info('OfflineQueueService initialized (${_queue.length} operations loaded from storage)', tag: 'OfflineQueueService');
    } catch (e) {
      Logger.error('Error initializing OfflineQueueService', error: e, tag: 'OfflineQueueService');
    }
  }

  /// Queue an operation for offline execution
  Future<void> queueOperation(QueuedOperation operation) async {
    if (!_isInitialized) await initialize();

    Logger.debug('Queueing operation: ${operation.type} (${operation.id})', tag: 'OfflineQueueService');

    _queue.add(operation);
    await _saveToLocalStorage(operation);

    // Try to process immediately if online
    _processQueue();
  }

  /// Create a queued operation for a task
  Future<String> queueTaskOperation({
    required QueuedOperationType type,
    required Map<String, dynamic> taskData,
  }) async {
    final operationId = 'task_${DateTime.now().millisecondsSinceEpoch}_${type.name}';
    final operation = QueuedOperation(
      id: operationId,
      type: type,
      data: taskData,
    );

    await queueOperation(operation);
    return operationId;
  }

  /// Create a queued operation for a message
  Future<String> queueMessageOperation({
    required QueuedOperationType type,
    required Map<String, dynamic> messageData,
  }) async {
    final operationId = 'message_${DateTime.now().millisecondsSinceEpoch}_${type.name}';
    final operation = QueuedOperation(
      id: operationId,
      type: type,
      data: messageData,
    );

    await queueOperation(operation);
    return operationId;
  }

  /// Create a queued operation for an event
  Future<String> queueEventOperation({
    required QueuedOperationType type,
    required Map<String, dynamic> eventData,
  }) async {
    final operationId = 'event_${DateTime.now().millisecondsSinceEpoch}_${type.name}';
    final operation = QueuedOperation(
      id: operationId,
      type: type,
      data: eventData,
    );

    await queueOperation(operation);
    return operationId;
  }

  /// Get the number of queued operations
  int get queueLength => _queue.length;

  /// Check if currently online
  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      Logger.warning('Error checking connectivity', error: e, tag: 'OfflineQueueService');
      return false;
    }
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(ConnectivityResult result) {
    Logger.debug('Connectivity changed: $result', tag: 'OfflineQueueService');

    if (result != ConnectivityResult.none) {
      // Back online, process queue
      _processQueue();
    }
  }

  /// Process the operation queue
  Future<void> _processQueue() async {
    if (_isProcessing || _queue.isEmpty) return;

    final isOnline = await _isOnline();
    if (!isOnline) {
      Logger.debug('Skipping queue processing - offline', tag: 'OfflineQueueService');
      return;
    }

    _isProcessing = true;
    Logger.info('Starting queue processing (${_queue.length} operations)', tag: 'OfflineQueueService');

    while (_queue.isNotEmpty && await _isOnline()) {
      final operation = _queue.removeFirst();

      try {
        Logger.debug('Processing operation: ${operation.type} (${operation.id})', tag: 'OfflineQueueService');
        await _executeOperation(operation);
        await _removeFromLocalStorage(operation.id);
        Logger.debug('Operation completed successfully: ${operation.id}', tag: 'OfflineQueueService');
      } catch (e, st) {
        Logger.warning('Operation failed, re-queuing: ${operation.id}', error: e, stackTrace: st, tag: 'OfflineQueueService');

        // Increment retry count
        final retryOperation = QueuedOperation(
          id: operation.id,
          type: operation.type,
          data: operation.data,
          createdAt: operation.createdAt,
          retryCount: operation.retryCount + 1,
        );

        // Only re-queue if under retry limit
        if (retryOperation.retryCount < 3) {
          _queue.addFirst(retryOperation);
          await _saveToLocalStorage(retryOperation);
        } else {
          Logger.error('Operation failed permanently after 3 retries: ${operation.id}', error: e, tag: 'OfflineQueueService');
          await _removeFromLocalStorage(operation.id);
        }

        // Stop processing on first failure to avoid overwhelming the system
        break;
      }
    }

    _isProcessing = false;
    Logger.info('Queue processing completed', tag: 'OfflineQueueService');
  }

  /// Execute a queued operation
  Future<void> _executeOperation(QueuedOperation operation) async {
    // This would integrate with the actual services
    // For now, we'll just simulate execution with logging
    Logger.debug('Executing ${operation.type} with data: ${operation.data}', tag: 'OfflineQueueService');

    // In a real implementation, this would call the appropriate service methods
    switch (operation.type) {
      case QueuedOperationType.addTask:
      case QueuedOperationType.updateTask:
      case QueuedOperationType.deleteTask:
        // Would call TaskService methods
        break;
      case QueuedOperationType.sendMessage:
        // Would call ChatService methods
        break;
      case QueuedOperationType.addEvent:
      case QueuedOperationType.updateEvent:
      case QueuedOperationType.deleteEvent:
        // Would call CalendarService methods
        break;
      case QueuedOperationType.uploadPhoto:
        // Would call PhotoService methods
        break;
    }

    // Simulate some processing time
    await Future.delayed(const Duration(milliseconds: 100));
  }

  /// Load queued operations from local storage
  Future<void> _loadFromLocalStorage() async {
    if (_queueBox == null) {
      _queueBox = await Hive.openBox(_queueBoxName);
    }

    try {
      final keys = _queueBox!.keys.toList();
      Logger.debug('Loading ${keys.length} operations from storage', tag: 'OfflineQueueService');

      for (var key in keys) {
        try {
          final jsonData = _queueBox!.get(key);
          if (jsonData != null) {
            final operation = QueuedOperation.fromJson(Map<String, dynamic>.from(jsonData));
            _queue.add(operation);
          }
        } catch (e) {
          Logger.warning('Error loading operation $key from storage, removing', error: e, tag: 'OfflineQueueService');
          await _queueBox!.delete(key);
        }
      }

      Logger.info('Loaded ${_queue.length} operations from storage', tag: 'OfflineQueueService');
    } catch (e) {
      Logger.error('Error loading operations from storage', error: e, tag: 'OfflineQueueService');
    }
  }

  /// Save operation to local storage
  Future<void> _saveToLocalStorage(QueuedOperation operation) async {
    if (_queueBox == null) {
      _queueBox = await Hive.openBox(_queueBoxName);
    }

    try {
      await _queueBox!.put(operation.id, operation.toJson());
      Logger.debug('Saved operation to local storage: ${operation.id}', tag: 'OfflineQueueService');
    } catch (e) {
      Logger.warning('Error saving operation to local storage', error: e, tag: 'OfflineQueueService');
    }
  }

  /// Remove operation from local storage
  Future<void> _removeFromLocalStorage(String operationId) async {
    if (_queueBox == null) {
      _queueBox = await Hive.openBox(_queueBoxName);
    }

    try {
      await _queueBox!.delete(operationId);
      Logger.debug('Removed operation from local storage: $operationId', tag: 'OfflineQueueService');
    } catch (e) {
      Logger.warning('Error removing operation from local storage', error: e, tag: 'OfflineQueueService');
    }
  }

  /// Clear all queued operations
  Future<void> clearQueue() async {
    _queue.clear();
    _pendingOperations.clear();
    
    // Clear from storage as well
    if (_queueBox != null) {
      await _queueBox!.clear();
    }
    
    Logger.info('Offline queue cleared', tag: 'OfflineQueueService');
  }

  /// Dispose of the service
  void dispose() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _queue.clear();
    _pendingOperations.clear();
    Logger.info('OfflineQueueService disposed', tag: 'OfflineQueueService');
  }
}
