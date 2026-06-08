import 'package:cloud_firestore/cloud_firestore.dart';

/// CourseModel
/// -----------
/// Represents one course (subject) available for timetable scheduling.
///
/// Firestore collection: `courses`
class CourseModel {
  final String id;
  final String code; // e.g. CS101, SECP3106
  final String name; // e.g. Software Engineering
  final String lecturerId;
  final String lecturerName;
  final String department;
  final int sections;

  const CourseModel({
    required this.id,
    required this.code,
    required this.name,
    required this.lecturerId,
    required this.lecturerName,
    required this.department,
    required this.sections,
  });

  bool get hasLecturer => lecturerId.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'code': code,
        'name': name,
        'lecturerId': lecturerId,
        'lecturerName': lecturerName,
        'department': department,
        'sections': sections,
      };

  factory CourseModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CourseModel(
      id: doc.id,
      code: data['code'] as String? ?? '',
      name: data['name'] as String? ?? '',
      lecturerId: data['lecturerId'] as String? ?? '',
      lecturerName: data['lecturerName'] as String? ?? '',
      department: data['department'] as String? ?? '',
      sections: data['sections'] as int? ?? 1,
    );
  }

  CourseModel copyWith({
    String? id,
    String? code,
    String? name,
    String? lecturerId,
    String? lecturerName,
    String? department,
    int? sections,
  }) =>
      CourseModel(
        id: id ?? this.id,
        code: code ?? this.code,
        name: name ?? this.name,
        lecturerId: lecturerId ?? this.lecturerId,
        lecturerName: lecturerName ?? this.lecturerName,
        department: department ?? this.department,
        sections: sections ?? this.sections,
      );
}
