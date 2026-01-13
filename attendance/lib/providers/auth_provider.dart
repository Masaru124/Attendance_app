import 'package:flutter/material.dart';
import '../models/user.dart';
import '../services/firebase_auth_service.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  String? _token;
  bool _isLoading = false;
  String? _errorMessage;
  final FirebaseAuthService _authService = FirebaseAuthService();

  User? get currentUser => _currentUser;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _initializeAuthListener();
  }

  void _initializeAuthListener() {
    _authService.authStateChanges.listen((user) {
      _currentUser = user;
      notifyListeners();
    });
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    setLoading(true);
    _errorMessage = null;
    try {
      final user = await _authService.signInWithEmailAndPassword(
        email,
        password,
      );
      _currentUser = user;
      _token = user.id; // Use user ID as token for API calls
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<void> createUserWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    setLoading(true);
    _errorMessage = null;
    try {
      final user = await _authService.createUserWithEmailAndPassword(
        email,
        password,
        name,
      );
      _currentUser = user;
      _token = user.id;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<void> signInWithGoogle() async {
    setLoading(true);
    _errorMessage = null;
    try {
      final user = await _authService.signInWithGoogle();
      _currentUser = user;
      _token = user.id;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<void> signOut() async {
    setLoading(true);
    try {
      await _authService.signOut();
      _currentUser = null;
      _token = null;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    setLoading(true);
    _errorMessage = null;
    try {
      await _authService.sendPasswordResetEmail(email);
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  void clearError() {
    _errorMessage = null;
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Demo login for testing without Firebase Auth
  void demoLogin(String role) {
    _currentUser = User(
      id: '1',
      email: 'demo@example.com',
      name: 'Demo ${role[0].toUpperCase() + role.substring(1).toLowerCase()}',
      role: _parseRole(role),
    );
    _token = 'demo-token';
    notifyListeners();
  }

  UserRole _parseRole(String role) {
    switch (role.toUpperCase()) {
      case 'TEACHER':
        return UserRole.teacher;
      case 'ADMIN':
        return UserRole.admin;
      default:
        return UserRole.student;
    }
  }
}
