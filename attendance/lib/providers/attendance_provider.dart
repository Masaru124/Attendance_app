import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/attendance_session.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';

class AttendanceProvider extends ChangeNotifier {
  List<AttendanceSession> _sessions = [];
  AttendanceSession? _currentSession;
  bool _isLoading = false;
  String? _error;
  bool _isCreating = false;

  List<AttendanceSession> get sessions => _sessions;
  AttendanceSession? get currentSession => _currentSession;
  bool get isLoading => _isLoading;
  bool get isCreating => _isCreating;
  String? get error => _error;

  final AuthProvider? authProvider;

  AttendanceProvider({this.authProvider});

  Map<String, String> get _headers {
    final headers = {'Content-Type': 'application/json'};
    final token = authProvider?.token;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<String?> _getValidToken() async {
    if (authProvider == null) return null;
    String? token = authProvider!.token;
    if (token == null || token.isEmpty) {
      token = await authProvider!.getValidToken();
    }
    return token;
  }

  Future<void> fetchSessions() async {
    if (authProvider == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _getValidToken();
      if (token == null) {
        throw Exception('No token available');
      }

      final requestHeaders = {..._headers};
      requestHeaders['Authorization'] = 'Bearer $token';

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/attendance/sessions'),
        headers: requestHeaders,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        _sessions = data.map((e) => AttendanceSession.fromJson(e)).toList();
      } else {
        _error = 'Failed to fetch sessions: ${response.body}';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<AttendanceSession?> createSession({
    required String sessionName,
    String? location,
  }) async {
    if (authProvider == null) return null;

    _isCreating = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _getValidToken();
      if (token == null) {
        throw Exception('No token available');
      }

      final requestHeaders = {..._headers};
      requestHeaders['Authorization'] = 'Bearer $token';

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/attendance/sessions'),
        headers: requestHeaders,
        body: jsonEncode({'session_name': sessionName, 'location': location}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final session = AttendanceSession.fromJson(data);
        _sessions.insert(0, session);
        _isCreating = false;
        notifyListeners();
        return session;
      } else {
        _error = 'Failed to create session: ${response.body}';
        _isCreating = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = e.toString();
      _isCreating = false;
      notifyListeners();
      return null;
    }
  }

  Future<AttendanceSession?> getSessionWithQrCode(int sessionId) async {
    if (authProvider == null) return null;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final token = await _getValidToken();
      if (token == null) {
        throw Exception('No token available');
      }

      final requestHeaders = {..._headers};
      requestHeaders['Authorization'] = 'Bearer $token';

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/attendance/sessions/$sessionId/qr'),
        headers: requestHeaders,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final session = AttendanceSession.fromJson(data);
        _currentSession = session;
        _isLoading = false;
        notifyListeners();
        return session;
      } else {
        _error = 'Failed to get session QR code: ${response.body}';
        _isLoading = false;
        notifyListeners();
        return null;
      }
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  Future<bool> closeSession(int sessionId) async {
    if (authProvider == null) return false;

    try {
      final token = await _getValidToken();
      if (token == null) {
        throw Exception('No token available');
      }

      final requestHeaders = {..._headers};
      requestHeaders['Authorization'] = 'Bearer $token';

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/attendance/sessions/$sessionId/close'),
        headers: requestHeaders,
        body: jsonEncode({}),
      );

      if (response.statusCode == 200) {
        // Update session in list
        final index = _sessions.indexWhere((s) => s.id == sessionId);
        if (index != -1) {
          _sessions[index] = AttendanceSession(
            id: _sessions[index].id,
            sessionName: _sessions[index].sessionName,
            location: _sessions[index].location,
            createdAt: _sessions[index].createdAt,
            isClosed: true,
            totalRecords: _sessions[index].totalRecords,
          );
          notifyListeners();
        }
        return true;
      } else {
        _error = 'Failed to close session: ${response.body}';
        return false;
      }
    } catch (e) {
      _error = e.toString();
      return false;
    }
  }

  Future<AttendanceSession?> getSessionDetails(int sessionId) async {
    if (authProvider == null) return null;

    try {
      final token = await _getValidToken();
      if (token == null) {
        throw Exception('No token available');
      }

      final requestHeaders = {..._headers};
      requestHeaders['Authorization'] = 'Bearer $token';

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/attendance/sessions/$sessionId'),
        headers: requestHeaders,
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final session = AttendanceSession.fromJson(data);
        return session;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearCurrentSession() {
    _currentSession = null;
    notifyListeners();
  }
}

final attendanceProviderProvider = ChangeNotifierProvider<AttendanceProvider>((
  ref,
) {
  final authProvider = ref.watch(authProviderProvider);
  return AttendanceProvider(authProvider: authProvider);
});
