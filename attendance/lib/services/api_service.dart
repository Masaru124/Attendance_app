import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/leave_request.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';

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
  // Use a getter to ensure the URL is always properly formatted
  static String get baseUrl {
    const String baseUrl = 'http://192.168.29.194:8000';
    // Trim any potential whitespace that might be introduced
    return baseUrl.trim();
  }

  final AuthProvider? authProvider;

  ApiService({this.authProvider});

  Map<String, String> get headers {
    final headers = {'Content-Type': 'application/json'};
    final token = authProvider?.token;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<String?> _getValidToken() async {
    if (authProvider == null) {
      print('_getValidToken: authProvider is null');
      return null;
    }

    String? token = authProvider!.token;
    print(
      '_getValidToken: Current token: ${token != null ? "exists (${token.substring(0, 20)}...)" : "NULL"}',
    );

    if (token == null || token.isEmpty) {
      print('_getValidToken: Token is null/empty, calling getValidToken()...');
      token = await authProvider!.getValidToken();
      print(
        '_getValidToken: getValidToken() returned: ${token != null ? "token (${token.substring(0, 20)}...)" : "NULL"}',
      );
    }

    return token;
  }

  Future<List<LeaveRequest>> applyLeave({
    required DateTime fromDate,
    required DateTime toDate,
    required String reason,
  }) async {
    await _getValidToken();

    final response = await http.post(
      Uri.parse('$baseUrl/leave/apply'),
      headers: headers,
      body: jsonEncode({
        'from_date': fromDate.toIso8601String().split('T')[0],
        'to_date': toDate.toIso8601String().split('T')[0],
        'reason': reason,
      }),
    );

    if (response.statusCode == 401) {
      print('Received 401, refreshing token and retrying...');
      final newToken = await authProvider?.refreshToken();

      if (newToken != null) {
        print('Token refreshed successfully, retrying request...');
        // Create fresh headers with the new token
        final freshHeaders = {'Content-Type': 'application/json'};
        freshHeaders['Authorization'] = 'Bearer $newToken';

        final retryResponse = await http.post(
          Uri.parse('$baseUrl/leave/apply'),
          headers: freshHeaders,
          body: jsonEncode({
            'from_date': fromDate.toIso8601String().split('T')[0],
            'to_date': toDate.toIso8601String().split('T')[0],
            'reason': reason,
          }),
        );

        if (retryResponse.statusCode == 201) {
          final data = jsonDecode(retryResponse.body);
          return [LeaveRequest.fromJson(data)];
        } else {
          throw Exception(
            'Failed to apply for leave after refresh: ${retryResponse.body}',
          );
        }
      }
    }

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      return [LeaveRequest.fromJson(data)];
    } else {
      throw Exception('Failed to apply for leave: ${response.body}');
    }
  }

  Future<LeaveStats> getLeaveStats() async {
    await _getValidToken();

    final response = await http.get(
      Uri.parse('$baseUrl/leave/stats'),
      headers: headers,
    );

    if (response.statusCode == 401) {
      print('Received 401, refreshing token and retrying...');
      final newToken = await authProvider?.refreshToken();

      if (newToken != null) {
        print('Token refreshed successfully, retrying request...');
        final freshHeaders = {'Content-Type': 'application/json'};
        freshHeaders['Authorization'] = 'Bearer $newToken';

        final retryResponse = await http.get(
          Uri.parse('$baseUrl/leave/stats'),
          headers: freshHeaders,
        );

        if (retryResponse.statusCode == 200) {
          final data = jsonDecode(retryResponse.body);
          return LeaveStats.fromJson(data);
        } else {
          throw Exception(
            'Failed to fetch stats after refresh: ${retryResponse.body}',
          );
        }
      }
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return LeaveStats.fromJson(data);
    } else {
      throw Exception('Failed to fetch leave stats: ${response.body}');
    }
  }

  Future<List<LeaveRequest>> getPendingLeaves() async {
    final token = await _getValidToken();

    final requestHeaders = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      requestHeaders['Authorization'] = 'Bearer $token';
      print(
        'getPendingLeaves: Using token: ${token.substring(0, math.min(20, token.length))}...',
      );
    } else {
      print('getPendingLeaves: WARNING - No token available!');
    }

    final response = await http.get(
      Uri.parse('$baseUrl/leave/pending'),
      headers: requestHeaders,
    );

    print('getPendingLeaves: Initial response status: ${response.statusCode}');

    if (response.statusCode == 401) {
      print('Received 401, refreshing token and retrying...');
      final newToken = await authProvider?.refreshToken();

      if (newToken != null) {
        print('Token refreshed successfully, retrying request...');
        print(
          'New token preview: ${newToken.substring(0, math.min(20, newToken.length))}...',
        );
        final freshHeaders = {'Content-Type': 'application/json'};
        freshHeaders['Authorization'] = 'Bearer $newToken';

        final retryResponse = await http.get(
          Uri.parse('$baseUrl/leave/pending'),
          headers: freshHeaders,
        );

        print(
          'getPendingLeaves: Retry response status: ${retryResponse.statusCode}',
        );

        if (retryResponse.statusCode == 200) {
          final List<dynamic> data = jsonDecode(retryResponse.body);
          return data.map((e) => LeaveRequest.fromJson(e)).toList();
        } else {
          throw Exception(
            'Failed to fetch pending leaves after refresh: ${retryResponse.body}',
          );
        }
      } else {
        print('getPendingLeaves: Token refresh returned null');
      }
    }

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => LeaveRequest.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch pending leaves: ${response.body}');
    }
  }

  Future<List<LeaveRequest>> getMyLeaves() async {
    print('getMyLeaves: Fetching from API...');
    await _getValidToken();

    final response = await http.get(
      Uri.parse('$baseUrl/leave/my'),
      headers: headers,
    );
    print('getMyLeaves: Response status: ${response.statusCode}');
    print('getMyLeaves: Response body: ${response.body}');

    // If we get a 401, try refreshing the token and retry once
    if (response.statusCode == 401) {
      print('Received 401, refreshing token and retrying...');
      final newToken = await authProvider?.refreshToken();

      if (newToken != null) {
        print('Token refreshed successfully, retrying request...');
        final freshHeaders = {'Content-Type': 'application/json'};
        freshHeaders['Authorization'] = 'Bearer $newToken';

        final retryResponse = await http.get(
          Uri.parse('$baseUrl/leave/my'),
          headers: freshHeaders,
        );

        if (retryResponse.statusCode == 200) {
          final List<dynamic> data = jsonDecode(retryResponse.body);
          return data.map((e) => LeaveRequest.fromJson(e)).toList();
        } else {
          throw Exception(
            'Failed to fetch your leaves after refresh: ${retryResponse.body}',
          );
        }
      }
    }

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
    print('getLeaveHistory: Fetching from URL: $url');

    // Ensure we have a valid token
    await _getValidToken();
    final response = await http.get(Uri.parse(url), headers: headers);
    print('getLeaveHistory: Response status: ${response.statusCode}');
    print('getLeaveHistory: Response body: ${response.body}');

    if (response.statusCode == 401) {
      print('Received 401, refreshing token and retrying...');
      final newToken = await authProvider?.refreshToken();

      if (newToken != null) {
        print('Token refreshed successfully, retrying request...');
        // Create fresh headers with the new token
        final freshHeaders = {'Content-Type': 'application/json'};
        freshHeaders['Authorization'] = 'Bearer $newToken';

        // Retry the request with fresh token
        final retryResponse = await http.get(
          Uri.parse(url),
          headers: freshHeaders,
        );

        if (retryResponse.statusCode == 200) {
          final List<dynamic> data = jsonDecode(retryResponse.body);
          return data.map((e) => LeaveRequest.fromJson(e)).toList();
        } else {
          throw Exception(
            'Failed to fetch history after refresh: ${retryResponse.body}',
          );
        }
      }
    }

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

    // Ensure we have a valid token
    await _getValidToken();
    final response = await http.get(url, headers: headers);

    // If we get a 401, try refreshing the token and retry once
    if (response.statusCode == 401) {
      print('Received 401, refreshing token and retrying...');
      final newToken = await authProvider?.refreshToken();

      if (newToken != null) {
        print('Token refreshed successfully, retrying request...');
        // Create fresh headers with the new token
        final freshHeaders = {'Content-Type': 'application/json'};
        freshHeaders['Authorization'] = 'Bearer $newToken';

        // Retry the request with fresh token
        final retryResponse = await http.get(url, headers: freshHeaders);

        if (retryResponse.statusCode == 200) {
          final List<dynamic> data = jsonDecode(retryResponse.body);
          return data.map((e) => LeaveRequest.fromJson(e)).toList();
        } else {
          throw Exception(
            'Failed to fetch all leaves after refresh: ${retryResponse.body}',
          );
        }
      }
    }

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
    // Ensure we have a valid token
    await _getValidToken();

    final response = await http.post(
      Uri.parse('$baseUrl/leave/$leaveId/action'),
      headers: headers,
      body: jsonEncode({'action': action}),
    );

    // If we get a 401, try refreshing the token and retry once
    if (response.statusCode == 401) {
      print('Received 401, refreshing token and retrying...');
      final newToken = await authProvider?.refreshToken();

      if (newToken != null) {
        print('Token refreshed successfully, retrying request...');
        // Create fresh headers with the new token
        final freshHeaders = {'Content-Type': 'application/json'};
        freshHeaders['Authorization'] = 'Bearer $newToken';

        // Retry the request with fresh token
        final retryResponse = await http.post(
          Uri.parse('$baseUrl/leave/$leaveId/action'),
          headers: freshHeaders,
          body: jsonEncode({'action': action}),
        );

        if (retryResponse.statusCode == 200) {
          final data = jsonDecode(retryResponse.body);
          return LeaveRequest.fromJson(data['leave_request']);
        } else {
          throw Exception(
            'Failed to $action leave after refresh: ${retryResponse.body}',
          );
        }
      }
    }

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
    // Ensure we have a valid token
    await _getValidToken();

    final response = await http.post(
      Uri.parse('$baseUrl/leave/batch/action'),
      headers: headers,
      body: jsonEncode({'leave_ids': leaveIds, 'action': action}),
    );

    // If we get a 401, try refreshing the token and retry once
    if (response.statusCode == 401) {
      print('Received 401, refreshing token and retrying...');
      final newToken = await authProvider?.refreshToken();

      if (newToken != null) {
        print('Token refreshed successfully, retrying request...');
        // Create fresh headers with the new token
        final freshHeaders = {'Content-Type': 'application/json'};
        freshHeaders['Authorization'] = 'Bearer $newToken';

        // Retry the request with fresh token
        final retryResponse = await http.post(
          Uri.parse('$baseUrl/leave/batch/action'),
          headers: freshHeaders,
          body: jsonEncode({'leave_ids': leaveIds, 'action': action}),
        );

        if (retryResponse.statusCode == 200) {
          final data = jsonDecode(retryResponse.body);
          return data['success'] ?? false;
        } else {
          throw Exception(
            'Failed to batch $action after refresh: ${retryResponse.body}',
          );
        }
      }
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['success'] ?? false;
    } else {
      throw Exception('Failed to batch $action leaves: ${response.body}');
    }
  }

  Future<void> cancelLeave(int leaveId) async {
    // Ensure we have a valid token
    await _getValidToken();

    final response = await http.delete(
      Uri.parse('$baseUrl/leave/$leaveId'),
      headers: headers,
    );

    // If we get a 401, try refreshing the token and retry once
    if (response.statusCode == 401) {
      print('Received 401, refreshing token and retrying...');
      final newToken = await authProvider?.refreshToken();

      if (newToken != null) {
        print('Token refreshed successfully, retrying request...');
        // Create fresh headers with the new token
        final freshHeaders = {'Content-Type': 'application/json'};
        freshHeaders['Authorization'] = 'Bearer $newToken';

        // Retry the request with fresh token
        final retryResponse = await http.delete(
          Uri.parse('$baseUrl/leave/$leaveId'),
          headers: freshHeaders,
        );

        if (retryResponse.statusCode == 200) {
          return;
        } else {
          throw Exception(
            'Failed to cancel leave after refresh: ${retryResponse.body}',
          );
        }
      }
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to cancel leave: ${response.body}');
    }
  }

  // ============== Notification APIs ==============

  Future<void> saveFcmToken(
    String token, {
    String deviceType = 'android',
  }) async {
    // Ensure we have a valid token
    await _getValidToken();

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
    // Ensure we have a valid token
    await _getValidToken();

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
    // Ensure we have a valid token
    await _getValidToken();

    final response = await http.get(
      Uri.parse('$baseUrl/users'),
      headers: headers,
    );

    // If we get a 401, try refreshing the token and retry once
    if (response.statusCode == 401) {
      print('Received 401, refreshing token and retrying...');
      final newToken = await authProvider?.refreshToken();

      if (newToken != null) {
        print('Token refreshed successfully, retrying request...');
        // Create fresh headers with the new token
        final freshHeaders = {'Content-Type': 'application/json'};
        freshHeaders['Authorization'] = 'Bearer $newToken';

        // Retry the request with fresh token
        final retryResponse = await http.get(
          Uri.parse('$baseUrl/users'),
          headers: freshHeaders,
        );

        if (retryResponse.statusCode == 200) {
          final List<dynamic> data = jsonDecode(retryResponse.body);
          return data.map((e) => User.fromJson(e)).toList();
        } else {
          throw Exception(
            'Failed to fetch users after refresh: ${retryResponse.body}',
          );
        }
      }
    }

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => User.fromJson(e)).toList();
    } else {
      throw Exception('Failed to fetch users: ${response.body}');
    }
  }

  Future<User> updateUserRole(String userId, UserRole role) async {
    // Ensure we have a valid token
    await _getValidToken();

    final response = await http.put(
      Uri.parse('$baseUrl/users/$userId/role'),
      headers: headers,
      body: jsonEncode({'role': role.toString().split('.').last.toUpperCase()}),
    );

    // If we get a 401, try refreshing the token and retry once
    if (response.statusCode == 401) {
      print('Received 401, refreshing token and retrying...');
      final newToken = await authProvider?.refreshToken();

      if (newToken != null) {
        print('Token refreshed successfully, retrying request...');
        // Create fresh headers with the new token
        final freshHeaders = {'Content-Type': 'application/json'};
        freshHeaders['Authorization'] = 'Bearer $newToken';

        // Retry the request with fresh token
        final retryResponse = await http.put(
          Uri.parse('$baseUrl/users/$userId/role'),
          headers: freshHeaders,
          body: jsonEncode({
            'role': role.toString().split('.').last.toUpperCase(),
          }),
        );

        if (retryResponse.statusCode == 200) {
          final data = jsonDecode(retryResponse.body);
          return User.fromJson(data);
        } else {
          throw Exception(
            'Failed to update role after refresh: ${retryResponse.body}',
          );
        }
      }
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data);
    } else {
      throw Exception('Failed to update user role: ${response.body}');
    }
  }

  /// Fetch current user profile including role from backend database
  Future<User> getCurrentUserProfile() async {
    // Ensure we have a valid token
    await _getValidToken();

    final response = await http.get(
      Uri.parse('$baseUrl/users/me'),
      headers: headers,
    );

    // If we get a 401, try refreshing the token and retry once
    if (response.statusCode == 401) {
      print('Received 401, refreshing token and retrying...');
      final newToken = await authProvider?.refreshToken();

      if (newToken != null) {
        print('Token refreshed successfully, retrying request...');
        // Create fresh headers with the new token
        final freshHeaders = {'Content-Type': 'application/json'};
        freshHeaders['Authorization'] = 'Bearer $newToken';

        // Retry the request with fresh token
        final retryResponse = await http.get(
          Uri.parse('$baseUrl/users/me'),
          headers: freshHeaders,
        );

        if (retryResponse.statusCode == 200) {
          final data = jsonDecode(retryResponse.body);
          return User.fromJson(data);
        } else {
          throw Exception(
            'Failed to fetch user profile after refresh: ${retryResponse.body}',
          );
        }
      }
    }

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return User.fromJson(data);
    } else {
      throw Exception('Failed to fetch user profile: ${response.body}');
    }
  }

  Future<void> markAttendance({required String sessionId}) async {
    await _getValidToken();

    final response = await http.post(
      Uri.parse('$baseUrl/attendance/mark'),
      headers: headers,
      body: jsonEncode({'session_id': sessionId}),
    );

    if (response.statusCode == 401) {
      print('Received 401, refreshing token and retrying...');
      final newToken = await authProvider?.refreshToken();

      if (newToken != null) {
        print('Token refreshed successfully, retrying request...');
        final freshHeaders = {'Content-Type': 'application/json'};
        freshHeaders['Authorization'] = 'Bearer $newToken';

        final retryResponse = await http.post(
          Uri.parse('$baseUrl/attendance/mark'),
          headers: freshHeaders,
          body: jsonEncode({'session_id': sessionId}),
        );

        if (retryResponse.statusCode == 200) {
          return;
        } else {
          throw Exception(
            'Failed to mark attendance after refresh: ${retryResponse.body}',
          );
        }
      }
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to mark attendance: ${response.body}');
    }
  }

  Future<List<dynamic>> getMyAttendance() async {
    await _getValidToken();

    final response = await http.get(
      Uri.parse('$baseUrl/attendance/my'),
      headers: headers,
    );

    if (response.statusCode == 401) {
      print('Received 401, refreshing token and retrying...');
      final newToken = await authProvider?.refreshToken();

      if (newToken != null) {
        print('Token refreshed successfully, retrying request...');
        final freshHeaders = {'Content-Type': 'application/json'};
        freshHeaders['Authorization'] = 'Bearer $newToken';

        final retryResponse = await http.get(
          Uri.parse('$baseUrl/attendance/my'),
          headers: freshHeaders,
        );

        if (retryResponse.statusCode == 200) {
          final List<dynamic> data = jsonDecode(retryResponse.body);
          return data;
        } else {
          throw Exception(
            'Failed to fetch attendance after refresh: ${retryResponse.body}',
          );
        }
      }
    }

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception('Failed to fetch attendance: ${response.body}');
    }
  }

  Future<List<dynamic>> getSessionAttendance(String sessionId) async {
    await _getValidToken();

    final response = await http.get(
      Uri.parse('$baseUrl/attendance/session/$sessionId'),
      headers: headers,
    );

    if (response.statusCode == 401) {
      print('Received 401, refreshing token and retrying...');
      final newToken = await authProvider?.refreshToken();

      if (newToken != null) {
        print('Token refreshed successfully, retrying request...');
        // Create fresh headers with the new token
        final freshHeaders = {'Content-Type': 'application/json'};
        freshHeaders['Authorization'] = 'Bearer $newToken';

        final retryResponse = await http.get(
          Uri.parse('$baseUrl/attendance/session/$sessionId'),
          headers: freshHeaders,
        );

        if (retryResponse.statusCode == 200) {
          final List<dynamic> data = jsonDecode(retryResponse.body);
          return data;
        } else {
          throw Exception(
            'Failed to fetch session attendance after refresh: ${retryResponse.body}',
          );
        }
      }
    }

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data;
    } else {
      throw Exception('Failed to fetch session attendance: ${response.body}');
    }
  }

  Future<bool> healthCheck() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
