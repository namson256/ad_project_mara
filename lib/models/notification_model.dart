import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationRecord {
  final String id;
  final String type; // kehadiran, disiplin, etc
  final String studentId;
  final String studentName;
  final String matricNo;
  final double? attendancePercentage;
  final int? warningLevel;
  final String? warningLabel;
  final String category;
  final String disciplineRecordId;
  final DateTime createdAt;
  final List<String> readBy;
  final List<String> recipients;
  final String emailStatus;
  final String? message;
  final List<String> recipientIds;

  NotificationRecord({
    required this.id,
    required this.type,
    required this.studentId,
    required this.studentName,
    required this.matricNo,
    this.attendancePercentage,
    this.warningLevel,
    this.warningLabel,
    required this.category,
    required this.disciplineRecordId,
    required this.createdAt,
    required this.readBy,
    required this.recipients,
    required this.emailStatus,
    this.message,
    required this.recipientIds,
  });

  factory NotificationRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime created;
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      created = DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }

    return NotificationRecord(
      id: doc.id,
      type: data['type'] ?? '',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      matricNo: data['matricNo'] ?? '',
      attendancePercentage: data['attendancePercentage'] != null ? (data['attendancePercentage'] as num).toDouble() : null,
      warningLevel: data['warningLevel'] as int?,
      warningLabel: data['warningLabel'] as String?,
      category: data['category'] ?? '',
      disciplineRecordId: data['disciplineRecordId'] ?? '',
      createdAt: created,
      readBy: (data['readBy'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      recipients: (data['recipients'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      recipientIds: (data['recipientIds'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      message: data['message'] as String?,
      emailStatus: data['emailStatus'] as String? ?? 'Berjaya Dihantar',
    );
  }

  NotificationRecord copyWith({
    String? id,
    String? type,
    String? studentId,
    String? studentName,
    String? matricNo,
    double? attendancePercentage,
    int? warningLevel,
    String? warningLabel,
    String? category,
    String? disciplineRecordId,
    DateTime? createdAt,
    List<String>? readBy,
    List<String>? recipients,
    List<String>? recipientIds,
    String? emailStatus,
    String? message,
  }) {
    return NotificationRecord(
      id: id ?? this.id,
      type: type ?? this.type,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      matricNo: matricNo ?? this.matricNo,
      attendancePercentage: attendancePercentage ?? this.attendancePercentage,
      warningLevel: warningLevel ?? this.warningLevel,
      warningLabel: warningLabel ?? this.warningLabel,
      category: category ?? this.category,
      disciplineRecordId: disciplineRecordId ?? this.disciplineRecordId,
      createdAt: createdAt ?? this.createdAt,
      readBy: readBy ?? this.readBy,
      recipients: recipients ?? this.recipients,
      recipientIds: recipientIds ?? this.recipientIds,
      emailStatus: emailStatus ?? this.emailStatus,
      message: message ?? this.message,
    );
  }
}
