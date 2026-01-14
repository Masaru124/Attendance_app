import 'package:flutter/material.dart';
import '../models/leave_request.dart';
import '../services/api_service.dart';

class LeaveStatsData {
  final int total;
  final int pending;
  final int approved;
  final int rejected;

  LeaveStatsData({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  factory LeaveStatsData.fromJson(Map<String, dynamic> json) {
    return LeaveStatsData(
      total: json['total'] ?? 0,
      pending: json['pending'] ?? 0,
      approved: json['approved'] ?? 0,
      rejected: json['rejected'] ?? 0,
    );
  }
}

class LeaveProvider with ChangeNotifier {
  List<LeaveRequest> _pendingLeaves = [];
  List<LeaveRequest> _myLeaves = [];
  LeaveStatsData? _stats;
  bool _isLoading = false;
  String? _error;

  List<LeaveRequest> get pendingLeaves => _pendingLeaves;
  List<LeaveRequest> get myLeaves => _myLeaves;
  LeaveStatsData? get stats => _stats;
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

  Future<LeaveStatsData> fetchLeaveStats(String token) async {
    try {
      final stats = await ApiService(authToken: token).getLeaveStats();
      _stats = LeaveStatsData(
        total: stats.total,
        pending: stats.pending,
        approved: stats.approved,
        rejected: stats.rejected,
      );
      notifyListeners();
      return _stats!;
    } catch (e) {
      _error = e.toString();
      rethrow;
    }
  }

  Future<List<LeaveRequest>> fetchLeaveHistory({
    required String token,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final leaves = await ApiService(authToken: token).getLeaveHistory(
        status: status,
        startDate: startDate,
        endDate: endDate,
        page: page,
      );
      _myLeaves = leaves;
      _isLoading = false;
      notifyListeners();
      return leaves;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
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

  Future<bool> batchLeaveAction({
    required String token,
    required List<int> leaveIds,
    required String action,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final success = await ApiService(
        authToken: token,
      ).batchLeaveAction(leaveIds: leaveIds, action: action);

      // Remove processed leaves from pending list
      for (var id in leaveIds) {
        _pendingLeaves.removeWhere((leave) => leave.id == id);
      }

      _isLoading = false;
      notifyListeners();
      return success;
    } catch (e) {
      _isLoading = false;
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> cancelLeave({
    required String token,
    required int leaveId,
  }) async {
    try {
      await ApiService(authToken: token).cancelLeave(leaveId);

      // Remove from my leaves list
      _myLeaves.removeWhere((leave) => leave.id == leaveId);

      notifyListeners();
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

  void clearLeaves() {
    _myLeaves = [];
    _pendingLeaves = [];
    _stats = null;
    notifyListeners();
  }
}
