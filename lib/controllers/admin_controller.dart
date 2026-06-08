import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

/// AdminController
/// ----------------
/// Manages lecturer accounts using Firebase Auth and Cloud Firestore.
class AdminController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'users';

  List<UserModel> _lecturers = [];
  bool _isLoading = false;
  String? _error;

  AdminController() {
    loadLecturers();
  }

  /// Read-only view for the UI.
  List<UserModel> get lecturers => List.unmodifiable(_lecturers);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Loads all lecturers from Firestore users collection
  Future<void> loadLecturers() async {
    _setLoading(true);
    _error = null;
    try {
      final snap = await _db
          .collection(_collection)
          .where('role', isEqualTo: 'pensyarah')
          .get();
      _lecturers = snap.docs.map(UserModel.fromFirestore).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint('Error loading lecturers: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Admin creates a new Lecturer account in Firebase Auth and Firestore.
  /// Returns null on success, or an error message string on failure.
  Future<String?> addLecturer({
    required String name,
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final normalizedEmail = email.trim().toLowerCase();

      // Check if email already exists in Firestore
      final query = await _db
          .collection(_collection)
          .where('email', isEqualTo: normalizedEmail)
          .get();
      if (query.docs.isNotEmpty) {
        return 'E-mel pensyarah sudah wujud.';
      }

      // Create Firebase Auth user using a secondary Firebase app instance
      // so the current admin user session doesn't get signed out!
      final FirebaseApp tempApp = await Firebase.initializeApp(
        name: 'temp_create_user_${DateTime.now().millisecondsSinceEpoch}',
        options: Firebase.app().options,
      );
      final FirebaseAuth tempAuth = FirebaseAuth.instanceFor(app: tempApp);
      final UserCredential cred = await tempAuth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
      final uid = cred.user!.uid;
      await tempApp.delete();

      // Store in Firestore
      final userData = {
        'name': name.trim(),
        'email': normalizedEmail,
        'role': 'pensyarah',
        'createdAt': FieldValue.serverTimestamp(),
      };
      await _db.collection(_collection).doc(uid).set(userData);

      final newLecturer = UserModel(
        id: uid,
        name: name.trim(),
        email: normalizedEmail,
        role: UserRole.pensyarah,
      );
      _lecturers.add(newLecturer);
      notifyListeners();
      return null; // Success
    } catch (e) {
      return e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Admin updates a lecturer's details in Firestore.
  /// Returns null on success, or an error message string on failure.
  Future<String?> updateLecturer({
    required String id,
    required String name,
    required String email,
    String? password,
  }) async {
    _setLoading(true);
    try {
      final normalizedEmail = email.trim().toLowerCase();

      // Check if email already exists for another user
      final query = await _db
          .collection(_collection)
          .where('email', isEqualTo: normalizedEmail)
          .get();
      for (final doc in query.docs) {
        if (doc.id != id) {
          return 'E-mel pensyarah sudah wujud.';
        }
      }

      // Update in Firestore
      await _db.collection(_collection).doc(id).update({
        'name': name.trim(),
        'email': normalizedEmail,
      });

      final idx = _lecturers.indexWhere((l) => l.id == id);
      if (idx != -1) {
        _lecturers[idx] = _lecturers[idx].copyWith(
          name: name.trim(),
          email: normalizedEmail,
        );
      }
      notifyListeners();
      return null; // Success
    } catch (e) {
      return e.toString();
    } finally {
      _setLoading(false);
    }
  }

  /// Admin removes a lecturer from Firestore.
  Future<String?> removeLecturer(String id) async {
    _setLoading(true);
    try {
      await _db.collection(_collection).doc(id).delete();
      _lecturers.removeWhere((l) => l.id == id);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}
