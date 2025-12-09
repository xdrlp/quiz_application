import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:quiz_application/models/user_model.dart';
import 'package:quiz_application/services/auth_service.dart';
import 'package:quiz_application/services/firestore_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _authService.currentUser != null;

  AuthProvider() {
    _authService.authStateChanges.listen((user) async {
      if (user != null) {
        _currentUser = await _firestoreService.getUser(user.uid);
      } else {
        _currentUser = null;
      }
      notifyListeners();
    });
  }

  // Normalize display names before storing or updating. This removes
  // accidental duplicate trailing words like "Nepomuceno Nepomuceno".
  static String _normalizeDisplayName(String s) {
    final trimmed = s.trim();
    if (trimmed.isEmpty) return '';
    final parts = trimmed.split(RegExp(r'\s+'));
    // Remove duplicate trailing words (case-insensitive) e.g. "Last Last".
    while (parts.length >= 2 && parts[parts.length - 1].toLowerCase() == parts[parts.length - 2].toLowerCase()) {
      parts.removeLast();
    }
    return parts.join(' ');
  }

  // Validate a name part (first/last). Accept letters, common accented
  // Latin characters, spaces, hyphens and apostrophes. Reject digits and
  // other symbols. This is intentionally conservative; expand ranges if
  // you need more script support.
  static final RegExp _nameRegExp = RegExp(r"^[A-Za-zÀ-ÖØ-öø-ÿ' -]+$");

  static bool _isValidName(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    return _nameRegExp.hasMatch(t);
  }

  // Convert a name to Title Case per word: first letter uppercase, rest
  // lowercase. Preserves apostrophes/hyphens as part of words.
  static String _toTitleCase(String s) {
    final parts = s.trim().split(RegExp(r'\s+'));
    final transformed = parts.map((p) {
      if (p.isEmpty) return p;
      final lower = p.toLowerCase();
      return lower[0].toUpperCase() + (lower.length > 1 ? lower.substring(1) : '');
    }).join(' ');
    return transformed;
  }

  Future<bool> signUp({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _authService.signUp(
        email: email,
        password: password,
      );

      // Validate and normalize name parts before saving
      if (!_isValidName(firstName) || !_isValidName(lastName)) {
        _errorMessage = 'Please enter a valid first and last name (letters, spaces, hyphens, apostrophes only).';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final normFirst = _toTitleCase(firstName);
      final normLast = _toTitleCase(lastName);
      var displayName = [normFirst, normLast].where((s) => s.trim().isNotEmpty).join(' ');
      displayName = _normalizeDisplayName(displayName);
      await _authService.updateDisplayName(displayName);


      // Create user document (no role concept)
      final newUser = UserModel(
        uid: credential.user!.uid,
        email: email,
        displayName: displayName,
        firstName: normFirst,
        lastName: normLast,
        createdAt: DateTime.now(),
      );

      await _firestoreService.createUser(credential.user!.uid, newUser);
      // Send email verification using Firebase's built-in sendEmailVerification
      // and record the timestamp in Firestore so the client can enforce a
      // short-lived verification window (e.g. 5 minutes).
      await _authService.sendEmailVerification();
      // Record verification sent time (server timestamp)
      await _firestoreService.setVerificationSent(credential.user!.uid);
      // Keep the user signed in so they can use the resend flow from the client.
      // The app already prevents navigation into the main app until `isEmailVerified` is true.

      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      // Map common Firebase auth errors to friendly messages
      switch (e.code) {
        case 'email-already-in-use':
          _errorMessage = 'An account already exists for that email.';
          break;
        case 'invalid-email':
          _errorMessage = 'The email address is badly formatted.';
          break;
        case 'weak-password':
          _errorMessage = 'The password is too weak.';
          break;
        default:
          _errorMessage = e.message ?? e.toString();
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> requestPasswordReset({required String email}) async {
    try {
      // Check if the email is registered in our users collection before
      // sending a password reset. Firebase Auth intentionally avoids
      // revealing account existence via sendPasswordResetEmail, so we
      // perform a conservative lookup in Firestore where user docs are
      // created at signup.
      final exists = await _firestoreService.emailExists(email);
      if (!exists) {
        _errorMessage = 'No account found for that email.';
        notifyListeners();
        return false;
      }

      await _authService.resetPassword(email);
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          _errorMessage = 'The email address is badly formatted.';
          break;
        default:
          _errorMessage = e.message ?? e.toString();
      }
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _authService.login(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          _errorMessage = 'The email address is badly formatted.';
          break;
        case 'user-disabled':
          _errorMessage = 'This user account has been disabled.';
          break;
        case 'user-not-found':
          _errorMessage = 'No account found for that email.';
          break;
        case 'wrong-password':
          _errorMessage = 'Incorrect password.';
          break;
        case 'invalid-credential':
          // This can occur for malformed credentials or when using different providers.
          _errorMessage = 'No account found for that email or the credentials are invalid.';
          break;
        default:
          _errorMessage = e.message ?? e.toString();
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  bool get isEmailVerified => _authService.currentUser?.emailVerified ?? false;

  /// Attempts to resend a verification email. Returns true on success.
  Future<bool> resendVerification() async {
    final user = _authService.currentUser;
    if (user == null) {
      _errorMessage = 'No authenticated user to resend verification for.';
      notifyListeners();
      return false;
    }
    try {
      await _authService.sendEmailVerification();
      await _firestoreService.setVerificationSent(user.uid);
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? e.toString();
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Return the verificationSentAt timestamp for the current authenticated user,
  /// or null if not available.
  Future<DateTime?> getVerificationSentAt() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) return null;
    return await _firestoreService.getVerificationSentAt(uid);
  }

  Future<void> logout() async {
    await _authService.logout();
    _currentUser = null;
    notifyListeners();
  }

  /// Reloads the Firebase user from the backend and returns whether the
  /// user's email is now verified.
  Future<bool> reloadAndCheckVerified() async {
    try {
      final user = await _authService.reloadCurrentUser();
      if (user != null) {
        // Refresh local profile copy
        _currentUser = await _firestoreService.getUser(user.uid);
      }
      notifyListeners();
      return _authService.currentUser?.emailVerified ?? false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update profile fields: first/last name, class section, and optional photo URL.
  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    String? classSection,
    String? photoUrl,
  }) async {
    final user = _authService.currentUser;
    if (user == null) {
      _errorMessage = 'No authenticated user.';
      notifyListeners();
      return false;
    }
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      // Validate and normalize name parts before saving
      if (!_isValidName(firstName) || !_isValidName(lastName)) {
        _errorMessage = 'Please enter a valid first and last name (letters, spaces, hyphens, apostrophes only).';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final normFirst = _toTitleCase(firstName);
      final normLast = _toTitleCase(lastName);
      var displayName = '$normFirst ${normLast.isNotEmpty ? normLast : ''}'.trim();
      displayName = _normalizeDisplayName(displayName);
      await _authService.updateDisplayName(displayName);

      // Update Firestore user doc
      final updates = <String, dynamic>{
        'displayName': displayName,
        'firstName': normFirst,
        'lastName': normLast,
        'classSection': classSection,
        'photoUrl': photoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await _firestoreService.updateUser(user.uid, updates);

      // Refresh local copy
      _currentUser = await _firestoreService.getUser(user.uid);
      _isLoading = false;
      notifyListeners();
      return true;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Role management removed — all users can create and take quizzes
}
