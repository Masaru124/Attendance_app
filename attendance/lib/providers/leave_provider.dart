import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/leave_request.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

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

class LeaveProvider extends ChangeNotifier {
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

  final AuthProvider? authProvider;

  LeaveProvider({this.authProvider});

  Future<void> fetchPendingLeaves() async {
    _isLoading = true;
    _error = null;
    await Future.microtask(() {});

    try {
      _pendingLeaves = await ApiService(
        authProvider: authProvider,
      ).getPendingLeaves();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchMyLeaves() async {
    _isLoading = true;
    _error = null;
    await Future.microtask(() {});

    try {
      _myLeaves = await ApiService(authProvider: authProvider).getMyLeaves();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<LeaveStatsData> fetchLeaveStats() async {
    try {
      final stats = await ApiService(
        authProvider: authProvider,
      ).getLeaveStats();
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
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
  }) async {
    _isLoading = true;
    _error = null;
    await Future.microtask(() {});

    try {
      final leaves = await ApiService(authProvider: authProvider)
          .getLeaveHistory(
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
    required DateTime fromDate,
    required DateTime toDate,
    required String reason,
  }) async {
    _isLoading = true;
    _error = null;
    await Future.microtask(() {});

    try {
      final leaves = await ApiService(
        authProvider: authProvider,
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

  Future<LeaveRequest> approveLeave({required int leaveId}) async {
    try {
      final updatedLeave = await ApiService(
        authProvider: authProvider,
      ).approveLeave(leaveId);

      _pendingLeaves.removeWhere((leave) => leave.id == leaveId);

      _myLeaves.removeWhere((leave) => leave.id == leaveId);

      _myLeaves.insert(0, updatedLeave);

      await fetchLeaveStats();

      await fetchMyLeaves();

      notifyListeners();
      return updatedLeave;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<LeaveRequest> rejectLeave({required int leaveId}) async {
    try {
      final updatedLeave = await ApiService(
        authProvider: authProvider,
      ).rejectLeave(leaveId);

      _pendingLeaves.removeWhere((leave) => leave.id == leaveId);

      _myLeaves.removeWhere((leave) => leave.id == leaveId);

      _myLeaves.insert(0, updatedLeave);

      await fetchLeaveStats();

      await fetchMyLeaves();

      notifyListeners();
      return updatedLeave;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> batchLeaveAction({
    required List<int> leaveIds,
    required String action,
  }) async {
    _isLoading = true;
    await Future.microtask(() {});

    try {
      final success = await ApiService(
        authProvider: authProvider,
      ).batchLeaveAction(leaveIds: leaveIds, action: action);

      for (var id in leaveIds) {
        _pendingLeaves.removeWhere((leave) => leave.id == id);
      }

      await fetchMyLeaves();

      await fetchLeaveStats();

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

  Future<void> cancelLeave({required int leaveId}) async {
    try {
      await ApiService(authProvider: authProvider).cancelLeave(leaveId);

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

final leaveProviderProvider = ChangeNotifierProvider<LeaveProvider>((ref) {
  final authProvider = ref.watch(authProviderProvider);
  return LeaveProvider(authProvider: authProvider);
});
