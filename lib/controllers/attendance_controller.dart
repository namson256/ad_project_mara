import 'package:flutter/foundation.dart';
import '../models/attendance_model.dart';

class AttendanceController extends ChangeNotifier {
  static const int totalWeeks = 18;

  final List<AttendanceStudent> _students = [
    AttendanceStudent(
        id: 's01', name: 'ADAM HAIQAL BIN ROZLAN', totalWeeks: totalWeeks),
    AttendanceStudent(
        id: 's02', name: 'AHMAD HASNUL ADIB BIN EDHAM', totalWeeks: totalWeeks),
    AttendanceStudent(
        id: 's03',
        name: 'AIDIEL HAIKAL BIN ZULKARNAIN',
        totalWeeks: totalWeeks),
    AttendanceStudent(
        id: 's04',
        name: 'AIMAN AIZAT BIN MAHMMED ZUEKFFLEE',
        totalWeeks: totalWeeks),
    AttendanceStudent(
        id: 's05', name: 'AMIR IZZUDDIN BIN YUSRI', totalWeeks: totalWeeks),
    AttendanceStudent(
        id: 's06',
        name: 'BATRISYAH ALMA BINTI AHMAD SUHAIMI',
        totalWeeks: totalWeeks),
    AttendanceStudent(
        id: 's07',
        name: 'ELLYSA FARHALIS AZNURIN BINTI AZMI',
        totalWeeks: totalWeeks),
    AttendanceStudent(
        id: 's08',
        name: 'MARYAM NAQIBAH BINTI HISYAMUDIN',
        totalWeeks: totalWeeks),
    AttendanceStudent(
        id: 's09',
        name: 'MOHAMMAD JAILANI BIN MOHD NAZIR',
        totalWeeks: totalWeeks),
    AttendanceStudent(
        id: 's10',
        name: 'MUHAMAMAD AKMAL HAFIZ BIN SHAHARUDDIN',
        totalWeeks: totalWeeks),
    AttendanceStudent(
        id: 's11',
        name: 'MUHAMMAD ALIFF AQMAR BIN MOHD KAMAL',
        totalWeeks: totalWeeks),
    AttendanceStudent(
        id: 's12',
        name: 'MUHAMMAD AMIRUL AIMAN BIN JUSOH',
        totalWeeks: totalWeeks),
    AttendanceStudent(
        id: 's13',
        name: 'MUHAMMAD ARIFF FIKRI BIN MOHD YUNUS',
        totalWeeks: totalWeeks),
    AttendanceStudent(
        id: 's14',
        name: 'MUHAMMAD HAFIZ DANIAL BIN ROSLI',
        totalWeeks: totalWeeks),
    AttendanceStudent(
        id: 's15',
        name: 'MUHAMMAD HAIKAL SIAAHAAN BIN AMRAN',
        totalWeeks: totalWeeks),
    AttendanceStudent(
        id: 's16',
        name: 'MUHAMMAD SYAUQI IQBAL BIN KHALID',
        totalWeeks: totalWeeks),
    AttendanceStudent(
        id: 's17',
        name: 'MUHAMMAD ZAIREEN SHAH BIN ZAILANI',
        totalWeeks: totalWeeks),
    AttendanceStudent(
        id: 's18',
        name: 'MUHAMMAD ZAIRUL AMIRUL BIN ZAINUDDIN',
        totalWeeks: totalWeeks),
    AttendanceStudent(
        id: 's19',
        name: 'WAN MUHAMMAD AIZACK BIN WAN MOHD ASRI',
        totalWeeks: totalWeeks),
  ];

  List<AttendanceStudent> get students => List.unmodifiable(_students);

  void updateStatus(String studentId, int week, AttendanceStatus status) {
    if (week < 1 || week > totalWeeks) return;

    final index = _students.indexWhere((student) => student.id == studentId);
    if (index == -1) return;

    final student = _students[index];
    final updatedStatus = Map<int, AttendanceStatus>.from(student.weeklyStatus);
    updatedStatus[week] = status;

    _students[index] = student.copyWith(
      weeklyStatus: updatedStatus,
      totalWeeks: totalWeeks,
    );
    notifyListeners();
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
