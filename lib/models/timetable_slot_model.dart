import 'package:cloud_firestore/cloud_firestore.dart';

/// Days of the week available for scheduling.
enum DayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday;

  String get label {
    switch (this) {
      case DayOfWeek.monday:    return 'Monday';
      case DayOfWeek.tuesday:   return 'Tuesday';
      case DayOfWeek.wednesday: return 'Wednesday';
      case DayOfWeek.thursday:  return 'Thursday';
      case DayOfWeek.friday:    return 'Friday';
    }
  }

  static DayOfWeek fromString(String s) =>
      DayOfWeek.values.firstWhere((d) => d.name == s);
}

/// TimetableSlotModel
/// ------------------
/// Represents one timetable entry stored in Firestore
/// under the collection `timetable_slots`.
class TimetableSlotModel {
  final String id;
  final String subject;
  final String lecturerName;
  final String venue;
  final DayOfWeek day;
  final String startTime; // "HH:mm"
  final String endTime;   // "HH:mm"
  final String section;   // e.g. "SECP3106-01"

  const TimetableSlotModel({
    required this.id,
    required this.subject,
    required this.lecturerName,
    required this.venue,
    required this.day,
    required this.startTime,
    required this.endTime,
    required this.section,
  });

  // ---------------------------------------------------------------------------
  // Firestore serialisation
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toMap() => {
        'subject': subject,
        'lecturerName': lecturerName,
        'venue': venue,
        'day': day.name,
        'startTime': startTime,
        'endTime': endTime,
        'section': section,
      };

  factory TimetableSlotModel.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TimetableSlotModel(
      id: doc.id,
      subject: data['subject'] as String,
      lecturerName: data['lecturerName'] as String,
      venue: data['venue'] as String,
      day: DayOfWeek.fromString(data['day'] as String),
      startTime: data['startTime'] as String,
      endTime: data['endTime'] as String,
      section: data['section'] as String,
    );
  }

  TimetableSlotModel copyWith({
    String? id,
    String? subject,
    String? lecturerName,
    String? venue,
    DayOfWeek? day,
    String? startTime,
    String? endTime,
    String? section,
  }) =>
      TimetableSlotModel(
        id: id ?? this.id,
        subject: subject ?? this.subject,
        lecturerName: lecturerName ?? this.lecturerName,
        venue: venue ?? this.venue,
        day: day ?? this.day,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        section: section ?? this.section,
      );
}
