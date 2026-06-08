import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/course_model.dart';

/// CourseController
/// ----------------
/// Manages courses using Cloud Firestore.
/// Follows the ChangeNotifier pattern.
///
/// Firestore collection: `courses`
class CourseController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'courses';

  List<CourseModel> _courses = [];
  bool _isLoading = false;
  String? _error;

  CourseController() {
    loadCourses();
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------
  List<CourseModel> get courses => List.unmodifiable(_courses);
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ---------------------------------------------------------------------------
  // Firestore — fetch all
  // ---------------------------------------------------------------------------
  Future<void> loadCourses() async {
    _setLoading(true);
    _error = null;
    try {
      final snap = await _db.collection(_collection).orderBy('code').get();
      _courses = snap.docs.map(CourseModel.fromDoc).toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Firestore — add
  // ---------------------------------------------------------------------------
  /// Returns an error message string on failure, null on success.
  Future<String?> addCourse(CourseModel course) async {
    final codeExists = _courses.any(
      (c) => c.code.trim().toUpperCase() == course.code.trim().toUpperCase(),
    );
    if (codeExists) {
      return 'Kod kursus "${course.code}" sudah wujud.';
    }

    _setLoading(true);
    try {
      final id = const Uuid().v4();
      final newCourse = course.copyWith(id: id);
      await _db.collection(_collection).doc(id).set(newCourse.toMap());
      _courses.add(newCourse);
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Firestore — update
  // ---------------------------------------------------------------------------
  /// Returns an error message string on failure, null on success.
  Future<String?> updateCourse(CourseModel updated) async {
    final codeExists = _courses.any(
      (c) =>
          c.id != updated.id &&
          c.code.trim().toUpperCase() == updated.code.trim().toUpperCase(),
    );
    if (codeExists) {
      return 'Kod kursus "${updated.code}" sudah wujud.';
    }

    _setLoading(true);
    try {
      await _db
          .collection(_collection)
          .doc(updated.id)
          .update(updated.toMap());
      final idx = _courses.indexWhere((c) => c.id == updated.id);
      if (idx != -1) {
        _courses[idx] = updated;
      }
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Firestore — delete
  // ---------------------------------------------------------------------------
  Future<void> deleteCourse(String id) async {
    _setLoading(true);
    try {
      await _db.collection(_collection).doc(id).delete();
      _courses.removeWhere((c) => c.id == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}
