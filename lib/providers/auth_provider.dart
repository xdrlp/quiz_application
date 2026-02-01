import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
        try {
          _currentUser = await _firestoreService.getUser(user.uid);
          // If profile doc is missing, attempt to create a minimal one.
          if (_currentUser == null) {
            try {
              final fu = _authService.currentUser;
              final display = fu?.displayName ?? '';
              final parts = display.split(' ');
              final first = parts.isNotEmpty ? parts.first : '';
              final last = parts.length > 1 ? parts.sublist(1).join(' ') : '';
              final newUser = UserModel(
                uid: user.uid,
                email: fu?.email ?? '',
                displayName: fu?.displayName ?? fu?.email?.split('@').first ?? '',
                firstName: first,
                lastName: last,
                createdAt: DateTime.now(),
              );
              await _firestoreService.createUser(user.uid, newUser);
              _currentUser = await _firestoreService.getUser(user.uid);
            } catch (e) {
              // Creation may fail due to rules; log and continue with null profile.
              // ignore: avoid_print
              print('Failed to auto-create user doc: $e');
            }
          }
        } catch (e) {
          _currentUser = null;
          _errorMessage = 'Unable to load profile information.';
        }
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
      // Keep the user signed in. We no longer require email verification.

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
      // 1. Removed fetchSignInMethods check (deprecated/removed in Firebase Auth 6.x)

      // 2. Try Firestore check (if rules allow it)
      // Note: Rules typically block this for unauthenticated users, returning false/error.
      final firestoreExists = await _firestoreService.emailExists(email);
      if (firestoreExists) {
        await _authService.resetPassword(email);
        return true;
      }
      
      // 3. Try Cloud Function (Authoritative check bypassing client rules)
      // This requires the 'checkEmailExists' function to be deployed.
      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable('checkEmailExists')
            .call({'email': email});
        final data = result.data as Map<dynamic, dynamic>?;
        if (data != null && data['exists'] == true) {
           await _authService.resetPassword(email);
           return true;
        } else if (data != null && data['exists'] == false) {
           _errorMessage = 'No account found for that email.';
           notifyListeners();
           return false;
        }
      } catch (e) {
        // Function not deployed or other error.
        // We have a dilemma: Block everyone (current bug) or Allow everyone (privacy feature).
        // Since user complained about blocking valid emails, we MUST Fail Open (Allow) if we can't verify.
        // But we can try one last thing: attempting to send the email and catching specific errors.
      }

      // 4. Final Fallback: Attempt to send and catch error.
      // If Protection is ON, this succeeds (void) even if user missing -> user sees success (Privacy).
      // If Protection is OFF, this throws user-not-found -> user sees error.
      // This is the standard behavior.
      await _authService.resetPassword(email);
      return true;

    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'invalid-email':
          _errorMessage = 'The email address is badly formatted.';
          break;
        case 'user-not-found':
          _errorMessage = 'No account found for that email.';
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
      // Log the exception for debugging (visible in device logs).
      // This helps diagnose issues like network, config, or auth method problems.
      // ignore: avoid_print
      print('FirebaseAuthException during login: ${e.code} ${e.message}');
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
      // ignore: avoid_print
      print('Unexpected error during login: $e');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Email verification is not required in this application.
  bool get isEmailVerified => true;

  /// Attempts to resend a verification email. Returns true on success.
  Future<bool> resendVerification() async {
    // Verification flow removed — treat resend as a no-op that succeeds.
    return true;
  }

  /// Return the verificationSentAt timestamp for the current authenticated user,
  /// or null if not available.
  Future<DateTime?> getVerificationSentAt() async {
    // Verification timestamps are no longer used.
    return null;
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
      // Email verification not required — consider user verified.
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Update profile fields: first/last name, class section, year level, and optional photo URL.
  Future<bool> updateProfile({
    required String firstName,
    required String lastName,
    String? classSection,
    String? yearLevel,
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
        'yearLevel': yearLevel,
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
