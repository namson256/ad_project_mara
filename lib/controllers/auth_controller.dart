import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/user_model.dart';

/// AuthController
/// ----------------
/// Manages authentication via Firebase Auth and stores user role data
/// in Firestore's `users` collection.
class AuthController extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  UserModel? _currentUser;
  bool _loading = false;

  UserModel? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _loading;

  // Role helpers
  bool get isPensyarah => _currentUser?.isPensyarah ?? false;
  bool get isStaff => _currentUser?.isStaff ?? false;
  bool get isKetuaProgram => _currentUser?.isKetuaProgram ?? false;

  /// Check if there is a currently signed-in Firebase user on app start.
  /// Call this once from main.dart after Firebase.initializeApp().
  Future<void> tryAutoLogin() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;

    try {
      _currentUser = await _fetchUserFromFirestore(firebaseUser.uid);
      notifyListeners();
    } catch (e) {
      // Firestore doc might not exist; silently fail.
      debugPrint('Auto-login failed: $e');
    }
  }

  /// Sign in with email & password.
  /// Returns null on success, or an error message string on failure.
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    _loading = true;
    notifyListeners();

    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;
      _currentUser = await _fetchUserFromFirestore(uid);

      _loading = false;
      notifyListeners();
      return null; // success
    } on FirebaseAuthException catch (e) {
      _loading = false;
      notifyListeners();
      return _mapAuthError(e.code);
    } on FirebaseException catch (e) {
      _loading = false;
      notifyListeners();
      debugPrint('FirebaseException during login: ${e.code} - ${e.message}');
      return _mapFirebaseError(e);
    } catch (e) {
      _loading = false;
      notifyListeners();
      debugPrint('Unexpected error during login: $e');
      return 'Ralat: ${e.toString()}';
    }
  }

  /// Register a new account. Creates the Firebase Auth user and a Firestore
  /// document in `users/{uid}` with the chosen role.
  /// Returns null on success, or an error message string on failure.
  Future<String?> register({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    _loading = true;
    notifyListeners();

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final uid = credential.user!.uid;

      // Store user profile + role in Firestore
      final userData = {
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'role': role.name, // 'pensyarah', 'staff', or 'ketuaProgram'
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(uid).set(userData);

      _currentUser = UserModel(
        id: uid,
        name: name.trim(),
        email: email.trim().toLowerCase(),
        role: role,
      );

      _loading = false;
      notifyListeners();
      return null; // success
    } on FirebaseAuthException catch (e) {
      _loading = false;
      notifyListeners();
      return _mapAuthError(e.code);
    } on FirebaseException catch (e) {
      _loading = false;
      notifyListeners();
      debugPrint('FirebaseException during register: ${e.code} - ${e.message}');
      return _mapFirebaseError(e);
    } catch (e) {
      _loading = false;
      notifyListeners();
      debugPrint('Unexpected error during register: $e');
      return 'Ralat: ${e.toString()}';
    }
  }

  /// Send a password-reset email.
  /// Returns null on success, or an error message string on failure.
  Future<String?> forgotPassword({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null; // success
    } on FirebaseAuthException catch (e) {
      return _mapAuthError(e.code);
    } on FirebaseException catch (e) {
      debugPrint('FirebaseException during forgotPassword: ${e.code} - ${e.message}');
      return _mapFirebaseError(e);
    } catch (e) {
      debugPrint('Unexpected error during forgotPassword: $e');
      return 'Ralat: ${e.toString()}';
    }
  }

  /// Sign out.
  void logout() {
    _auth.signOut();
    _currentUser = null;
    notifyListeners();
  }

  /// Reads the user document from Firestore.
  Future<UserModel> _fetchUserFromFirestore(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();

    if (!doc.exists) {
      throw Exception('User document not found in Firestore');
    }

    return UserModel.fromFirestore(doc);
  }

  /// Maps Firebase Auth error codes to user-friendly Malay messages.
  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'Tiada akaun dengan e-mel ini.';
      case 'wrong-password':
        return 'Kata laluan tidak betul.';
      case 'invalid-credential':
        return 'E-mel atau kata laluan tidak sah.';
      case 'email-already-in-use':
        return 'E-mel ini sudah didaftarkan.';
      case 'weak-password':
        return 'Kata laluan terlalu lemah (minimum 6 aksara).';
      case 'invalid-email':
        return 'Format e-mel tidak sah.';
      case 'too-many-requests':
        return 'Terlalu banyak percubaan. Sila cuba sebentar lagi.';
      case 'network-request-failed':
        return 'Tiada sambungan internet.';
      default:
        return 'Ralat pengesahan: $code';
    }
  }

  /// Maps general Firebase errors (e.g. Firestore permission denied).
  String _mapFirebaseError(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return 'Kebenaran Firestore ditolak. Sila tetapkan peraturan Firestore.';
    }
    if (e.code == 'unavailable') {
      return 'Perkhidmatan Firebase tidak tersedia. Sila cuba lagi.';
    }
    return 'Ralat Firebase: ${e.message ?? e.code}';
  }
}