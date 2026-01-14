import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/leave_request.dart';
import '../models/user.dart';

class LeaveStats {
  final int total;
  final int pending;
  final int approved;
  final int rejected;

  LeaveStats({
    required this.total,
    required this.pending,
    required this.approved,
    required this.rejected,
  });

  factory LeaveStats.fromJson(Map<String, dynamic> json) {
    return LeaveStats(
      total: json['total'] ?? 0,
      pending: json['pending'] ?? 0,
      approved: json['approved'] ?? 0,
      rejected: json['rejected'] ?? 0,
    );
  }
}

class ApiService {
  static const String baseUrl = 'http://localhost:8000';

  // For mobile, use your computer's IP address
  // static const String baseUrl = 'http://192.168.1.X:8000';

  final String? authToken;

  ApiService({this.authToken});

  Map<String, String> get headers {
    final headers = {'Content-Type': 'application/json'};
    if (authToken != null) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    return headers;
  }

  // ============== Leave APIs ==============

  Future<List<LeaveRequest>> applyLeave({
    required DateTime fromDate,
    required DateTime toDate,
    required String reason,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/leave/apply'),
      headers: headers,
      body: jsonEncode({
        'from_date': fromDate.toIso8601String().split('T')[0],
        'to_date': toDate.toIso8601String().split('T')[0],
        'reason': reason,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return [LeaveRequest.fromJson(data)];
    } else {
      throw Exception('Failed to apply for leave: ${response.body}');
    }
  }

  Future<LeaveStats> getLeaveStats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/leave/stats'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return LeaveStats.fromJson(data);
    } else {
      throw Exception('Failed to fetch leave stats: ${response.body}');
    }
  }

  Future<List<LeaveRequest>> getPendingLeaves() async {
    final response = await http.get(
      Uri.parse('$baseUrl/leave/pending'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => LeaveRequest.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch pending leaves: ${response.body}');
    }
  }

  Future<List<LeaveRequest>> getMyLeaves() async {
    final response = await http.get(
      Uri.parse('$baseUrl/leave/my'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => LeaveRequest.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch your leaves: ${response.body}');
    }
  }

  Future<List<LeaveRequest>> getLeaveHistory({
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String>[];
    if (status != null) params.add('status=$status');
    if (startDate != null) {
      params.add('start_date=${startDate.toIso8601String().split('T')[0]}');
    }
    if (endDate != null) {
      params.add('end_date=${endDate.toIso8601String().split('T')[0]}');
    }
    params.add('page=$page');
    params.add('page_size=$pageSize');

    final url = '$baseUrl/leave/history?${params.join('&')}';
    final response = await http.get(Uri.parse(url), headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => LeaveRequest.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch leave history: ${response.body}');
    }
  }

  Future<List<LeaveRequest>> getAllLeaves({String? status}) async {
    final url = status != null
        ? Uri.parse('$baseUrl/leave/all?status=$status')
        : Uri.parse('$baseUrl/leave/all');

    final response = await http.get(url, headers: headers);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => LeaveRequest.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch all leaves: ${response.body}');
    }
  }

  Future<LeaveRequest> approveLeave(int leaveId) async {
    return _performLeaveAction(leaveId, 'APPROVE');
  }

  Future<LeaveRequest> rejectLeave(int leaveId) async {
    return _performLeaveAction(leaveId, 'REJECT');
  }

  Future<LeaveRequest> _performLeaveAction(int leaveId, String action) async {
    final response = await http.post(
      Uri.parse('$baseUrl/leave/$leaveId/action'),
      headers: headers,
      body: jsonEncode({'action': action}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return LeaveRequest.fromJson(data['leave_request']);
    } else {
      throw Exception('Failed to $action leave: ${response.body}');
    }
  }

  Future<bool> batchLeaveAction({
    required List<int> leaveIds,
    required String action,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/leave/batch/action'),
      headers: headers,
      body: jsonEncode({'leave_ids': leaveIds, 'action': action}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['success'] ?? false;
    } else {
      throw Exception('Failed to batch $action leaves: ${response.body}');
    }
  }

  Future<void> cancelLeave(int leaveId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/leave/$leaveId'),
      headers: headers,
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to cancel leave: ${response.body}');
    }
  }

  // ============== Notification APIs ==============

  Future<void> saveFcmToken(
    String token, {
    String deviceType = 'android',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/notifications/fcm-token'),
      headers: headers,
      body: jsonEncode({'token': token, 'device_type': deviceType}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to save FCM token: ${response.body}');
    }
  }

  Future<void> deleteFcmToken(String token) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/notifications/fcm-token'),
      headers: headers,
      body: jsonEncode({'token': token}),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to delete FCM token: ${response.body}');
    }
  }

  // ============== User Management APIs ==============

  Future<List<User>> getUsers() async {
    final response = await http.get(
      Uri.parse('$baseUrl/users'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => User.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch users: ${response.body}');
    }
  }

  Future<User> updateUserRole(String userId, UserRole role) async {
    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId/role'),
      headers: headers,
      body: jsonEncode({'role': role.toString().split('.').last.toUpperCase()}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data);
    } else {
      throw Exception('Failed to update user role: ${response.body}');
    }
  }

  // ============== Health Check ==============

  Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
