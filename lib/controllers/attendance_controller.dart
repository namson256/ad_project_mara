import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/attendance_model.dart';

class AttendanceController extends ChangeNotifier {
  static const int totalWeeks = 18;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _collection = 'course_attendance';

  /// Semester start date (Monday of Week 1).
  /// Weeks roll over every Monday.
  static final DateTime semesterStartDate = DateTime(2026, 5, 5); // 5 May 2026

  /// Returns the current academic week number (1-based).
  /// After totalWeeks it clamps at totalWeeks; before start returns 0.
  static int get currentWeek {
    final now = DateTime.now();
    final diff = now.difference(semesterStartDate).inDays;
    if (diff < 0) return 0; // semester hasn't started
    final week = (diff ~/ 7) + 1;
    return week > totalWeeks ? totalWeeks : week;
  }

  /// Returns true if [week] is the current editable week.
  static bool isWeekEditable(int week) => week == currentWeek;

  /// All students (shared names/IDs across courses).
  static final List<AttendanceStudent> _defaultStudents = [
    AttendanceStudent(id: 's01', name: 'ADAM HAIQAL BIN ROZLAN',             totalWeeks: totalWeeks),
    AttendanceStudent(id: 's02', name: 'AHMAD HASNUL ADIB BIN EDHAM',        totalWeeks: totalWeeks),
    AttendanceStudent(id: 's03', name: 'AIDIEL HAIKAL BIN ZULKARNAIN',       totalWeeks: totalWeeks),
    AttendanceStudent(id: 's04', name: 'AIMAN AIZAT BIN MAHMMED ZUEKFFLEE',  totalWeeks: totalWeeks),
    AttendanceStudent(id: 's05', name: 'AMIR IZZUDDIN BIN YUSRI',            totalWeeks: totalWeeks),
    AttendanceStudent(id: 's06', name: 'BATRISYAH ALMA BINTI AHMAD SUHAIMI', totalWeeks: totalWeeks),
    AttendanceStudent(id: 's07', name: 'ELLYSA FARHALIS AZNURIN BINTI AZMI', totalWeeks: totalWeeks),
    AttendanceStudent(id: 's08', name: 'MARYAM NAQIBAH BINTI HISYAMUDIN',    totalWeeks: totalWeeks),
    AttendanceStudent(id: 's09', name: 'MOHAMMAD JAILANI BIN MOHD NAZIR',    totalWeeks: totalWeeks),
    AttendanceStudent(id: 's10', name: 'MUHAMAMAD AKMAL HAFIZ BIN SHAHARUDDIN', totalWeeks: totalWeeks),
    AttendanceStudent(id: 's11', name: 'MUHAMMAD ALIFF AQMAR BIN MOHD KAMAL',  totalWeeks: totalWeeks),
    AttendanceStudent(id: 's12', name: 'MUHAMMAD AMIRUL AIMAN BIN JUSOH',    totalWeeks: totalWeeks),
    AttendanceStudent(id: 's13', name: 'MUHAMMAD ARIFF FIKRI BIN MOHD YUNUS', totalWeeks: totalWeeks),
    AttendanceStudent(id: 's14', name: 'MUHAMMAD HAFIZ DANIAL BIN ROSLI',    totalWeeks: totalWeeks),
    AttendanceStudent(id: 's15', name: 'MUHAMMAD HAIKAL SIAAHAAN BIN AMRAN', totalWeeks: totalWeeks),
    AttendanceStudent(id: 's16', name: 'MUHAMMAD SYAUQI IQBAL BIN KHALID',   totalWeeks: totalWeeks),
    AttendanceStudent(id: 's17', name: 'MUHAMMAD ZAIREEN SHAH BIN ZAILANI',  totalWeeks: totalWeeks),
    AttendanceStudent(id: 's18', name: 'MUHAMMAD ZAIRUL AMIRUL BIN ZAINUDDIN', totalWeeks: totalWeeks),
    AttendanceStudent(id: 's19', name: 'WAN MUHAMMAD AIZACK BIN WAN MOHD ASRI', totalWeeks: totalWeeks),
  ];

  /// Attendance records keyed by courseId → student list.
  final Map<String, List<AttendanceStudent>> _courseAttendance = {};
  
  /// Track which courses have been loaded from Firestore
  final Map<String, bool> _hasLoadedCourse = {};

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Returns the student attendance list for [courseId].
  /// Triggers a fetch from Firestore if not yet loaded.
  List<AttendanceStudent> studentsForCourse(String courseId) {
    if (!_hasLoadedCourse.containsKey(courseId)) {
      _hasLoadedCourse[courseId] = true;
      
      // Initialize with default students immediately
      _courseAttendance[courseId] = _defaultStudents
          .map((s) => AttendanceStudent(
                id: s.id,
                name: s.name,
                totalWeeks: totalWeeks,
              ))
          .toList();
          
      // Fetch from Firestore
      _fetchCourseAttendance(courseId);
    }
    return List.unmodifiable(_courseAttendance[courseId]!);
  }

  Future<void> _fetchCourseAttendance(String courseId) async {
    // Only set global loading if we really want to block UI, but usually 
    // we want background loading.
    _isLoading = true;
    // Don't notify yet to avoid interrupting the initial build cycle
    
    try {
      final doc = await _db.collection(_collection).doc(courseId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final studentsData = data['students'] as List<dynamic>? ?? [];
        
        // Merge fetched data with default students (to handle missing students if any)
        final fetchedStudentsMap = {
          for (var s in studentsData) 
            s['id'] as String: AttendanceStudent.fromMap(s as Map<String, dynamic>, totalWeeks: totalWeeks)
        };

        _courseAttendance[courseId] = _defaultStudents.map((s) {
          if (fetchedStudentsMap.containsKey(s.id)) {
            return fetchedStudentsMap[s.id]!;
          }
          return AttendanceStudent(id: s.id, name: s.name, totalWeeks: totalWeeks);
        }).toList();
      }
    } catch (e) {
      debugPrint("Error fetching attendance: \$e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Updates the status of [studentId] for [week] in [courseId].
  Future<void> updateStatus(
    String courseId,
    String studentId,
    int week,
    AttendanceStatus status,
  ) async {
    if (week < 1 || week > totalWeeks) return;

    final students = _courseAttendance[courseId];
    if (students == null) return;

    final index = students.indexWhere((s) => s.id == studentId);
    if (index == -1) return;

    final student = students[index];
    final updatedStatus = Map<int, AttendanceStatus>.from(student.weeklyStatus);
    updatedStatus[week] = status;

    students[index] = student.copyWith(
      weeklyStatus: updatedStatus,
      totalWeeks: totalWeeks,
    );
    notifyListeners();

    // Save to Firestore in the background
    try {
      final docRef = _db.collection(_collection).doc(courseId);
      await docRef.set({
        'students': students.map((s) => s.toMap()).toList()
      });
    } catch (e) {
      debugPrint("Error saving attendance: \$e");
    }
  }

  double attendancePercentage(AttendanceStudent student) {
    var attended = 0;
    var eligible = 0;

    for (final status in student.weeklyStatus.values) {
      switch (status) {
        case AttendanceStatus.hadir:
          attended++;
          eligible++;
          break;
        case AttendanceStatus.lewat:
          attended++;
          eligible++;
          break;
        case AttendanceStatus.tidakHadir:
          eligible++;
          break;
        case AttendanceStatus.mc:
        case AttendanceStatus.ck:
          break;
      }
    }

    if (eligible == 0) return 0;
    return (attended / eligible) * 100;
  }
}
