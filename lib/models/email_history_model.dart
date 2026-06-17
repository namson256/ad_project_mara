import 'package:cloud_firestore/cloud_firestore.dart';

class EmailHistoryRecord {
  final String id;
  final String subject;
  final String body;
  final List<String> recipients;
  final String status; // Berjaya Dihantar, Gagal Dihantar, Belum Hantar
  final DateTime createdAt;
  final String disciplineRecordId;

  EmailHistoryRecord({
    required this.id,
    required this.subject,
    required this.body,
    required this.recipients,
    required this.status,
    required this.createdAt,
    required this.disciplineRecordId,
  });

  factory EmailHistoryRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    DateTime created;
    if (data['createdAt'] is Timestamp) {
      created = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      created = DateTime.tryParse(data['createdAt'] as String) ?? DateTime.now();
    } else {
      created = DateTime.now();
    }

    return EmailHistoryRecord(
      id: doc.id,
      subject: data['subject'] ?? '',
      body: data['body'] ?? '',
      recipients: (data['recipients'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      status: data['status'] ?? 'Belum Hantar',
      createdAt: created,
      disciplineRecordId: data['disciplineRecordId'] ?? '',
    );
  }

  EmailHistoryRecord copyWith({
    String? id,
    String? subject,
    String? body,
    List<String>? recipients,
    String? status,
    DateTime? createdAt,
    String? disciplineRecordId,
  }) {
    return EmailHistoryRecord(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      recipients: recipients ?? this.recipients,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      disciplineRecordId: disciplineRecordId ?? this.disciplineRecordId,
    );
  }
}
