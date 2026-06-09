import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/discipline_record_model.dart';
import '../models/course_model.dart';
import 'attendance_controller.dart';

class DisciplineController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'discipline_records';

  List<DisciplineRecord> _records = [];
  bool _isLoading = false;
  String? _error;

  DisciplineController() {
    loadRecords();
  }

  List<DisciplineRecord> get records => List.unmodifiable(_records);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadRecords() async {
    _isLoading = true;
    _error = null;
    try {
      final snap = await _db.collection(_collection).orderBy('reportedDate', descending: true).get();
      _records = snap.docs.map(DisciplineRecord.fromFirestore).toList();
    } catch (e) {
      _error = e.toString();
      debugPrint("Error loading discipline records: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> addRecord(DisciplineRecord record) async {
    _isLoading = true;
    notifyListeners();
    try {
      // Preserve the provided id (e.g. auto_<studentId>_<courseId>) or generate a new UUID
      final id = record.id.isNotEmpty ? record.id : const Uuid().v4();
      final finalRecord = record.copyWith(id: id);
      await _db.collection(_collection).doc(id).set(finalRecord.toMap());
      // Remove any existing entry with the same id before inserting
      _records.removeWhere((r) => r.id == id);
      _records.insert(0, finalRecord);
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> updateRecord(DisciplineRecord record) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _db.collection(_collection).doc(record.id).set(record.toMap());
      final idx = _records.indexWhere((r) => r.id == record.id);
      if (idx != -1) {
        _records[idx] = record;
      } else {
        // Auto-detected record being saved for first time via edit
        _records.insert(0, record);
      }
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> deleteRecord(String id) async {
    _isLoading = true;
    notifyListeners();
    try {
      if (id.startsWith('auto_')) {
        // For auto-detected records: mark as 'Dipadam' in Firestore so it won't
        // be dynamically re-generated on next getCombinedRecords call.
        final parts = id.split('_');
        final studentId = parts.length > 1 ? parts[1] : '';
        final existing = _records.firstWhere(
          (r) => r.id == id,
          orElse: () => DisciplineRecord(
            id: id,
            studentId: studentId,
            studentName: studentDetailsMap[studentId]?['name'] ?? '',
            matricNo: studentDetailsMap[studentId]?['matric'] ?? '',
            programme: studentDetailsMap[studentId]?['program'] ?? '',
            category: 'Isu Kehadiran',
            title: 'Kehadiran Rendah (< 80%)',
            description: '',
            reportedDate: DateTime.now(),
            severity: 'Tinggi',
            status: 'Dipadam',
            reportedBy: 'Sistem',
            isAutoDetected: true,
          ),
        );
        final tombstone = existing.copyWith(status: 'Dipadam');
        await _db.collection(_collection).doc(id).set(tombstone.toMap());
        final idx = _records.indexWhere((r) => r.id == id);
        if (idx != -1) {
          _records[idx] = tombstone;
        } else {
          _records.add(tombstone);
        }
      } else {
        await _db.collection(_collection).doc(id).delete();
        _records.removeWhere((r) => r.id == id);
      }
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> updateStatus(String id, String newStatus) async {
    _isLoading = true;
    notifyListeners();
    try {
      // For auto-detected records that don't exist in Firestore yet,
      // we need a full document set rather than merge.
      final existing = _records.where((r) => r.id == id).toList();
      if (existing.isEmpty && id.startsWith('auto_')) {
        // Will be handled silently — the record is purely dynamic, update local only
        // (no Firestore doc exists yet, merge would create empty doc)
        debugPrint('updateStatus: auto-detected record $id not persisted yet, skipping Firestore write.');
      } else {
        await _db.collection(_collection).doc(id).set({
          'status': newStatus,
        }, SetOptions(merge: true));
      }

      final idx = _records.indexWhere((r) => r.id == id);
      if (idx != -1) {
        _records[idx] = _records[idx].copyWith(status: newStatus);
      } else {
        await loadRecords();
      }
      return null;
    } catch (e) {
      return e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Calculates dynamic auto-detected attendance issues (< 80%)
  /// and returns them merged with manual records.
  List<DisciplineRecord> getCombinedRecords(List<CourseModel> courses, AttendanceController attendanceCtrl) {
    final List<DisciplineRecord> combined = [];
    for (final r in _records) {
      if (r.status != 'Dipadam') {
        combined.add(r);
      }
    }

    final Set<String> storedAutos = _records.map((r) => r.id).toSet();
    final Set<String> processedPairs = {};

    for (final course in courses) {
      final students = attendanceCtrl.studentsForCourse(course.id);
      for (final student in students) {
        final pct = attendanceCtrl.attendancePercentage(student);
        if (pct < 80.0) {
          final autoId = 'auto_${student.id}_${course.id}';
          
          if (storedAutos.contains(autoId)) continue;
          if (processedPairs.contains(autoId)) continue;
          processedPairs.add(autoId);

          final stableHoursAgo = (student.id.hashCode % 24) + 1;
          final date = DateTime.now().subtract(Duration(hours: stableHoursAgo));

          combined.add(
            DisciplineRecord(
              id: autoId,
              studentId: student.id,
              studentName: student.name,
              matricNo: studentDetailsMap[student.id]?['matric'] ?? 'M${student.id.toUpperCase()}',
              programme: studentDetailsMap[student.id]?['program'] ?? 'Diploma Sains Komputer',
              category: 'Isu Kehadiran',
              title: 'Kehadiran Rendah (< 80%)',
              description: 'Kehadiran dikesan secara automatik pada ${pct.toStringAsFixed(1)}% di dalam kursus ${course.code} (${course.name}).',
              reportedDate: date,
              severity: 'Tinggi',
              status: 'Belum Selesai',
              reportedBy: 'Sistem',
              isAutoDetected: true,
              attendancePercentage: pct,
            ),
          );
        }
      }
    }

    // Sort all records: latest report date first
    combined.sort((a, b) => b.reportedDate.compareTo(a.reportedDate));
    return combined;
  }
}
