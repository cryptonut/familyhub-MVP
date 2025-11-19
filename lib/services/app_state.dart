import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  int _currentIndex = 0;
  int? _tasksTabIndex;

  int get currentIndex => _currentIndex;
  int? get tasksTabIndex => _tasksTabIndex;

  void setCurrentIndex(int index) {
    _currentIndex = index;
    _tasksTabIndex = null; // Clear tab index when switching screens
    notifyListeners();
  }

  void setCurrentIndexWithTasksTab(int index, int? tasksTabIndex) {
    _currentIndex = index;
    _tasksTabIndex = tasksTabIndex;
    notifyListeners();
  }

  void clearTasksTabIndex() {
    _tasksTabIndex = null;
    notifyListeners();
  }
}

