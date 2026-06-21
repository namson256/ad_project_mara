import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/timetable_slot_model.dart';

/// TimetableController
/// -------------------
/// Manages timetable slots using Cloud Firestore.
/// Follows the same ChangeNotifier pattern as AdminController.
///
/// Firestore collection: `timetable_slots`
class TimetableController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'timetable_slots';

  List<TimetableSlotModel> _slots = [];
  bool _isLoading = false;
  String? _error;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------
  List<TimetableSlotModel> get slots => List.unmodifiable(_slots);
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// All slots for a specific day, sorted by start time.
  List<TimetableSlotModel> slotsForDay(DayOfWeek day) {
    return _slots.where((s) => s.day == day).toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  // ---------------------------------------------------------------------------
  // Firestore — fetch all
  // ---------------------------------------------------------------------------
  Future<void> loadSlots() async {
    _setLoading(true);
    _error = null;
    try {
      final snap = await _db
          .collection(_collection)
          .orderBy('day')
          .orderBy('startTime')
          .get();
      _slots = snap.docs.map(TimetableSlotModel.fromDoc).toList();
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
  Future<String?> addSlot(TimetableSlotModel slot) async {
    // Check for exact duplicate: lecturer_id + course_id + day + start_time + end_time
    final hasDuplicate = _slots.any((s) =>
        s.lecturerId == slot.lecturerId &&
        s.courseId == slot.courseId &&
        s.day == slot.day &&
        s.startTime == slot.startTime &&
        s.endTime == slot.endTime);
    if (hasDuplicate) {
      return 'Rekod jadual telah wujud.';
    }

    // Local conflict check before hitting Firestore
    final conflict = _findConflict(slot);
    if (conflict != null) {
      return 'Pertindihan Masa Dikesan.';
    }

    _setLoading(true);
    try {
      final id = const Uuid().v4();
      await _db.collection(_collection).doc(id).set(slot.toMap());
      _slots.add(slot.copyWith(id: id));
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
  Future<String?> updateSlot(TimetableSlotModel updated) async {
    // Check for exact duplicate: lecturer_id + course_id + day + start_time + end_time
    final hasDuplicate = _slots.any((s) =>
        s.id != updated.id &&
        s.lecturerId == updated.lecturerId &&
        s.courseId == updated.courseId &&
        s.day == updated.day &&
        s.startTime == updated.startTime &&
        s.endTime == updated.endTime);
    if (hasDuplicate) {
      return 'Rekod jadual telah wujud.';
    }

    final conflict = _findConflict(updated, excludeId: updated.id);
    if (conflict != null) {
      return 'Pertindihan Masa Dikesan.';
    }

    _setLoading(true);
    try {
      await _db
          .collection(_collection)
          .doc(updated.id)
          .update(updated.toMap());
      final idx = _slots.indexWhere((s) => s.id == updated.id);
      if (idx != -1) _slots[idx] = updated;
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
  Future<void> deleteSlot(String id) async {
    _setLoading(true);
    try {
      await _db.collection(_collection).doc(id).delete();
      _slots.removeWhere((s) => s.id == id);
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
  TimetableSlotModel? _findConflict(
    TimetableSlotModel candidate, {
    String? excludeId,
  }) {
    for (final s in _slots) {
      if (s.id == excludeId) continue;
      if (s.day != candidate.day) continue;

      // Overlap: NOT (end1 <= start2 OR start1 >= end2)
      final hasOverlap = !(candidate.endTime.compareTo(s.startTime) <= 0 ||
          candidate.startTime.compareTo(s.endTime) >= 0);
      if (!hasOverlap) continue;

      // 1. Same venue conflict
      if (s.venue.trim().toLowerCase() == candidate.venue.trim().toLowerCase()) {
        return s;
      }

      // 2. Same lecturer conflict
      final sameLecturer = (candidate.lecturerId.isNotEmpty && s.lecturerId.isNotEmpty && candidate.lecturerId == s.lecturerId) ||
          (candidate.lecturerName.trim().toLowerCase() == s.lecturerName.trim().toLowerCase());
      if (sameLecturer) {
        return s;
      }
    }
    return null;
  }

  void _setLoading(bool v) {
    _isLoading = v;
    notifyListeners();
  }
}
