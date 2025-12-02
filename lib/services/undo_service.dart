import 'package:flutter/material.dart';
import '../core/services/logger_service.dart';

class UndoService {
  static final UndoService _instance = UndoService._internal();
  factory UndoService() => _instance;
  UndoService._internal();

  final Map<String, VoidCallback> _undoableActions = {};

  void registerUndoableAction(String actionId, VoidCallback undo) {
    _undoableActions[actionId] = undo;
    Logger.debug('Registered undoable action: $actionId', tag: 'UndoService');
  }

  void showUndoSnackbar(
    BuildContext context, {
    required String message,
    required String actionId,
    Duration duration = const Duration(seconds: 4),
  }) {
    final undo = _undoableActions[actionId];
    if (undo == null) {
      Logger.warning('No undo action found for: $actionId', tag: 'UndoService');
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        action: SnackBarAction(
          label: 'UNDO',
          textColor: Colors.white,
          onPressed: () {
            undo();
            _undoableActions.remove(actionId);
            Logger.debug('Undo executed for: $actionId', tag: 'UndoService');
          },
        ),
      ),
    );

    // Auto-remove after duration
    Future.delayed(duration, () {
      _undoableActions.remove(actionId);
    });
  }

  void clearAction(String actionId) {
    _undoableActions.remove(actionId);
  }

  void clearAll() {
    _undoableActions.clear();
  }
}

