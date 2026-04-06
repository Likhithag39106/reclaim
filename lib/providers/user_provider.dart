import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class UserProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _user;
  bool _isLoading = false;
  String? _error;

  UserModel? get user => _user;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Check if user is already logged in
  Future<void> checkAuthStatus() async {
    try {
      debugPrint('[UserProvider] Checking auth status...');
      final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      
      if (firebaseUser != null) {
        debugPrint('[UserProvider] User is logged in: ${firebaseUser.uid}');
        
        // Try to get user from Firestore
        UserModel? userModel = await _firestoreService.getUser(firebaseUser.uid);
        
        // If user doesn't exist in Firestore, create a basic profile
        if (userModel == null) {
          debugPrint('[UserProvider] User not found in Firestore, creating profile...');
          userModel = UserModel(
            uid: firebaseUser.uid,
            email: firebaseUser.email ?? '',
            displayName: firebaseUser.displayName ?? 'User',
            addictions: [],
            createdAt: DateTime.now(),
          );
          await _firestoreService.createUser(userModel);
        }
        
        _user = userModel;
        notifyListeners();
      } else {
        debugPrint('[UserProvider] No user logged in');
      }
    } catch (e) {
      debugPrint('[UserProvider] checkAuthStatus error: $e');
    }
  }

  // Signup with email and password
  Future<bool> signup({
    required String email,
    required String password,
    required String displayName,
    required List<String> addictions,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[UserProvider] Starting signup for: $email');
      
      // Try to sign up
      firebase_auth.User? firebaseUser;
      
      try {
        firebaseUser = await _authService.signUpWithEmail(email, password);
      } on firebase_auth.FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          debugPrint('[UserProvider] Email already exists, trying to sign in...');
          
          // Email exists, try to sign in and create profile if missing
          try {
            firebaseUser = await _authService.signInWithEmail(email, password);
            
            if (firebaseUser != null) {
              // Check if user profile exists
              UserModel? existingUser = await _firestoreService.getUser(firebaseUser.uid);
              
              if (existingUser == null) {
                // Create the missing profile
                debugPrint('[UserProvider] Creating missing profile for existing user...');
                final newUser = UserModel(
                  uid: firebaseUser.uid,
                  email: email,
                  displayName: displayName,
                  addictions: addictions,
                  createdAt: DateTime.now(),
                );
                
                await _firestoreService.createUser(newUser);
                _user = newUser;
                
                _isLoading = false;
                notifyListeners();
                return true;
              } else {
                _user = existingUser;
                _isLoading = false;
                notifyListeners();
                return true;
              }
            }
          } catch (signInError) {
            debugPrint('[UserProvider] Sign in failed: $signInError');
            throw Exception('Email already in use. Please login instead.');
          }
        } else {
          rethrow;
        }
      }

      if (firebaseUser == null) {
        throw Exception('Failed to create authentication account');
      }

      debugPrint('[UserProvider] Auth account created: ${firebaseUser.uid}');

      // Create user profile
      final newUser = UserModel(
        uid: firebaseUser.uid,
        email: email,
        displayName: displayName,
        addictions: addictions,
        createdAt: DateTime.now(),
      );

      await _firestoreService.createUser(newUser);
      _user = newUser;

      debugPrint('[UserProvider] Signup completed successfully');

      _isLoading = false;
      notifyListeners();
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint('[UserProvider] FirebaseAuth error: ${e.code} - ${e.message}');
      _error = e.message ?? 'Signup failed';
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('[UserProvider] Signup error: $e');
      _error = 'Signup failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Login with email and password
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[UserProvider] Attempting login for: $email');
      
      final firebaseUser = await _authService.signInWithEmail(email, password);

      if (firebaseUser == null) {
        throw Exception('Login failed');
      }

      debugPrint('[UserProvider] Login successful: ${firebaseUser.uid}');

      // Get user profile
      UserModel? userModel = await _firestoreService.getUser(firebaseUser.uid);
      
      // If profile doesn't exist, create a basic one
      if (userModel == null) {
        debugPrint('[UserProvider] User profile not found, creating one...');
        userModel = UserModel(
          uid: firebaseUser.uid,
          email: firebaseUser.email ?? email,
          displayName: firebaseUser.displayName ?? 'User',
          addictions: [],
          createdAt: DateTime.now(),
        );
        await _firestoreService.createUser(userModel);
      }

      _user = userModel;

      // Track login for analytics
      await _firestoreService.logLogin(userModel.uid);

      _isLoading = false;
      notifyListeners();
      return true;
    } on firebase_auth.FirebaseAuthException catch (e) {
      debugPrint('[UserProvider] FirebaseAuth login error: ${e.code}');
      if (e.code == 'user-not-found') {
        _error = 'No user found with this email';
      } else if (e.code == 'wrong-password') {
        _error = 'Incorrect password';
      } else if (e.code == 'invalid-credential') {
        _error = 'Invalid email or password';
      } else {
        _error = e.message ?? 'Login failed';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('[UserProvider] Login error: $e');
      _error = 'Login failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout
  Future<void> logout() async {
    try {
      await _authService.signOut();
      _user = null;
      notifyListeners();
    } catch (e) {
      debugPrint('[UserProvider] Logout error: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}