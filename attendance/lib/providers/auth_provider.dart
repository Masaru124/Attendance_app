import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/firebase_auth_service.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
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
    _authService.authStateChanges.listen((user) async {
      print('AuthStateChanges: User received: ${user?.email ?? "null"}');
      _currentUser = user;
      // Clear token when user signs out
      if (user == null) {
        _token = null;
        print('AuthStateChanges: User is null, cleared token');
      } else {
        
        print('AuthStateChanges: User is not null, trying to get token...');

        await Future.delayed(const Duration(milliseconds: 500));

        if (_authService.currentUser != null) {
          _token = await _authService.getIdToken();
          print(
            'AuthProvider: Initialized token from session restore: ${_token?.substring(0, 20)}...',
          );

          await _syncUserRoleFromBackend();
        } else {
          print(
            'AuthProvider: WARNING - currentUser is still null after delay',
          );
        }
      }
      notifyListeners();
    });
  }


  Future<String?> getValidToken() async {
    try {
      final token = await _authService.getIdToken();
      if (token != null) {
        _token = token;
        notifyListeners();
      }
      return token;
    } catch (e) {
      print('Error getting valid token: $e');
      return null;
    }
  }


  Future<String?> refreshToken() async {
    try {
      final token = await _authService.forceRefreshToken();
      if (token != null) {
        _token = token;
        notifyListeners();
      }
      return token;
    } catch (e) {
      print('Error refreshing token: $e');
      return null;
    }
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
      // Get the actual Firebase ID token for API authentication
      _token = await _authService.getIdToken();

      await _syncUserRoleFromBackend();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      setLoading(false);
    }
  }


  Future<void> _syncUserRoleFromBackend() async {
    try {
      final apiService = ApiService(authProvider: this);
      final userProfile = await apiService.getCurrentUserProfile();

      if (userProfile.id.isNotEmpty) {
        _currentUser = User(
          id: userProfile.id,
          email: _currentUser?.email ?? '',
          name: _currentUser?.name ?? userProfile.name,
          role: userProfile.role,
        );
        notifyListeners();
        print('Synced user role from backend: ${userProfile.role}');
      }
    } catch (e) {
      print('Failed to sync user role from backend: $e');
     
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
      _token = await _authService.getIdToken();
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
      _token = await _authService.getIdToken();

      await _syncUserRoleFromBackend();
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

final authProviderProvider = ChangeNotifierProvider<AuthProvider>((ref) {
  return AuthProvider();
});
