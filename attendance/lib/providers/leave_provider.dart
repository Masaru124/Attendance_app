import 'package:flutter/material.dart';
import '../models/leave_request.dart';
import '../services/api_service.dart';

class LeaveProvider with ChangeNotifier {
  List<LeaveRequest> _pendingLeaves = [];
  List<LeaveRequest> _myLeaves = [];
  bool _isLoading = false;
  String? _error;

  List<LeaveRequest> get pendingLeaves => _pendingLeaves;
  List<LeaveRequest> get myLeaves => _myLeaves;
  bool get isLoading => _isLoading;
  String? get error => _error;

  final ApiService apiService;

  LeaveProvider({required this.apiService});

  Future<void> fetchPendingLeaves(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _pendingLeaves = await ApiService(authToken: token).getPendingLeaves();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMyLeaves(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _myLeaves = await ApiService(authToken: token).getMyLeaves();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<LeaveRequest> applyLeave({
    required String token,
    required DateTime fromDate,
    required DateTime toDate,
    required String reason,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final leaves = await ApiService(
        authToken: token,
      ).applyLeave(fromDate: fromDate, toDate: toDate, reason: reason);

      // Add to my leaves list
      if (leaves.isNotEmpty) {
        _myLeaves.insert(0, leaves.first);
      }

      _isLoading = false;
      notifyListeners();
      return leaves.first;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<LeaveRequest> approveLeave({
    required String token,
    required int leaveId,
  }) async {
    try {
      final updatedLeave = await ApiService(
        authToken: token,
      ).approveLeave(leaveId);

      // Remove from pending list
      _pendingLeaves.removeWhere((leave) => leave.id == leaveId);

      // Add to my leaves if this is the current user's leave
      _myLeaves.insert(0, updatedLeave);

      notifyListeners();
      return updatedLeave;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<LeaveRequest> rejectLeave({
    required String token,
    required int leaveId,
  }) async {
    try {
      final updatedLeave = await ApiService(
        authToken: token,
      ).rejectLeave(leaveId);

      // Remove from pending list
      _pendingLeaves.removeWhere((leave) => leave.id == leaveId);

      // Add to my leaves if this is the current user's leave
      _myLeaves.insert(0, updatedLeave);

      notifyListeners();
      return updatedLeave;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
