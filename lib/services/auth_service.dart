import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Sign up with email and password
  Future<User?> signUpWithEmail(String email, String password) async {
    try {
      debugPrint('[AuthService] Signing up user: $email');
      final UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('[AuthService] User signed up successfully: ${userCredential.user?.uid}');
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] Sign up error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] Unexpected sign up error: $e');
      rethrow;
    }
  }

  // Sign in with email and password
  Future<User?> signInWithEmail(String email, String password) async {
    try {
      debugPrint('[AuthService] Signing in user: $email');
      final UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('[AuthService] User signed in successfully: ${userCredential.user?.uid}');
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] Sign in error: ${e.code} - ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('[AuthService] Unexpected sign in error: $e');
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      debugPrint('[AuthService] Signing out user');
      await _auth.signOut();
      debugPrint('[AuthService] User signed out successfully');
    } catch (e) {
      debugPrint('[AuthService] Sign out error: $e');
      rethrow;
    }
  }

  // Check if user is signed in
  bool isSignedIn() {
    return _auth.currentUser != null;
  }

  // Get current user ID
  String? getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}