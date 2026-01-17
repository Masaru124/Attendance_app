import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeTabController extends ChangeNotifier {
  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  void setIndex(int index) {
    if (index >= 0 && index < 5) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  void setTeacherIndex(int index) {
    if (index >= 0 && index < 4) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  void setAdminIndex(int index) {
    if (index >= 0 && index < 4) {
      _currentIndex = index;
      notifyListeners();
    }
  }

  void goToDashboard() {
    _currentIndex = 0;
    notifyListeners();
  }

  void goToApplyLeave() {
    _currentIndex = 1;
    notifyListeners();
  }

  void goToLeaveHistory() {
    _currentIndex = 2;
    notifyListeners();
  }

  void goToQRScanner() {
    _currentIndex = 3;
    notifyListeners();
  }

  void goToAttendance() {
    _currentIndex = 4;
    notifyListeners();
  }

  void goToPendingRequests() {
    _currentIndex = 1;
    notifyListeners();
  }

  void goToAdminPanel() {
    _currentIndex = 0;
    notifyListeners();
  }

  void goToAttendanceSessions() {
    _currentIndex = 3;
    notifyListeners();
  }
}

final homeTabControllerProvider = ChangeNotifierProvider<HomeTabController>((
  ref,
) {
  return HomeTabController();
});
