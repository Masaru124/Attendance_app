import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';

class FirebaseAuthService {
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;
    return User(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      name: firebaseUser.displayName ?? '',
      role: UserRole.student,
    );
  }

  Stream<User?> get authStateChanges {
    return _auth.authStateChanges().map((firebaseUser) {
      if (firebaseUser == null) return null;
      return User(
        id: firebaseUser.uid,
        email: firebaseUser.email ?? '',
        name: firebaseUser.displayName ?? '',
        role: UserRole.student,
      );
    });
  }

  bool get isAuthenticated => _auth.currentUser != null;

  Future<User> signInWithEmailAndPassword(String email, String password) async {
    try {
      final firebase_auth.UserCredential credential = await _auth
          .signInWithEmailAndPassword(email: email, password: password);

      // Check if this is the admin user
      UserRole role = UserRole.student;
      if (email == 'admin@test.com') {
        role = UserRole.admin;
      }

      return User(
        id: credential.user!.uid,
        email: credential.user!.email ?? '',
        name: credential.user!.displayName ?? email.split('@')[0],
        role: role,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<User> createUserWithEmailAndPassword(
    String email,
    String password,
    String name,
  ) async {
    try {
      final firebase_auth.UserCredential credential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      await credential.user!.updateDisplayName(name);

      return User(
        id: credential.user!.uid,
        email: credential.user!.email ?? '',
        name: name,
        role: UserRole.student,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  Future<User> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        throw AuthException('Google sign-in was cancelled', 'cancelled');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final oauthCredential = firebase_auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final firebase_auth.UserCredential userCredential = await _auth
          .signInWithCredential(oauthCredential);

      return User(
        id: userCredential.user!.uid,
        email: userCredential.user!.email ?? '',
        name: userCredential.user!.displayName ?? googleUser.displayName ?? '',
        role: UserRole.student,
      );
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      if (e.toString().contains('cancelled')) rethrow;
      throw AuthException('Google sign-in failed: $e', 'google_error');
    }
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on firebase_auth.FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  AuthException _handleAuthException(firebase_auth.FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'user-not-found':
        message = 'No user found with this email. Please register first.';
        break;
      case 'wrong-password':
        message = 'Incorrect password. Please try again.';
        break;
      case 'email-already-in-use':
        message = 'This email is already registered. Please login instead.';
        break;
      case 'invalid-email':
        message = 'Invalid email format. Please check your email.';
        break;
      case 'weak-password':
        message = 'Password is too weak. Use at least 6 characters.';
        break;
      case 'user-disabled':
        message = 'This account has been disabled.';
        break;
      case 'too-many-requests':
        message = 'Too many attempts. Please try again later.';
        break;
      case 'network-request-failed':
        message = 'Network error. Please check your connection.';
        break;
      default:
        message = e.message ?? 'An error occurred. Please try again.';
    }
    return AuthException(message, e.code);
  }
}

class AuthException implements Exception {
  final String message;
  final String code;

  AuthException(this.message, this.code);

  @override
  String toString() => message;
}
