import 'package:cloud_firestore/cloud_firestore.dart';
 
/// Booking status values.
///   - Menunggu   : pending review (lecturer just submitted)
///   - Diluluskan : approved by Ketua Program
///   - Ditolak    : rejected by Ketua Program
class BookingStatus {
  static const String menunggu   = 'Menunggu';
  static const String diluluskan = 'Diluluskan';
  static const String ditolak    = 'Ditolak';
}
 
/// Booking type values.
///   - tempahanBilik : standard room booking
///   - kelasGanti    : replacement class — eligible to appear in timetable
///                     and become attendance-takeable once approved.
class BookingType {
  static const String tempahanBilik = 'Tempahan Bilik';
  static const String kelasGanti    = 'Kelas Ganti';
}
 
/// BookingModel
/// ------------
/// Represents one booking request stored in Firestore under `bookings`.
class BookingModel {
  final String id;
  final String lecturerId;
  final String lecturerName;
  final String type;        // BookingType.*
  final String venue;       // room
  final DateTime date;      // calendar date (time portion ignored)
  final String startTime;   // "HH:mm"
  final String endTime;     // "HH:mm"
  final String programme;   // class / programme e.g. "DSK 2A"
  final String subject;     // subject / course
  final String purpose;     // why
  final String remarks;     // optional notes
  final String status;      // BookingStatus.*
  final DateTime createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? reviewerNotes;
 
  const BookingModel({
    required this.id,
    required this.lecturerId,
    required this.lecturerName,
    required this.type,
    required this.venue,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.programme,
    required this.subject,
    required this.purpose,
    required this.remarks,
    required this.status,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
    this.reviewerNotes,
  });
 
  bool get isReplacement => type == BookingType.kelasGanti;
  bool get isPending     => status == BookingStatus.menunggu;
  bool get isApproved    => status == BookingStatus.diluluskan;
  bool get isRejected    => status == BookingStatus.ditolak;
 
  // ── Firestore serialisation ─────────────────────────────────────────
 
  Map<String, dynamic> toMap() => {
        'lecturerId':    lecturerId,
        'lecturerName':  lecturerName,
        'type':          type,
        'venue':         venue,
        'date':          Timestamp.fromDate(date),
        'startTime':     startTime,
        'endTime':       endTime,
        'programme':     programme,
        'subject':       subject,
        'purpose':       purpose,
        'remarks':       remarks,
        'status':        status,
        'createdAt':     Timestamp.fromDate(createdAt),
        'reviewedBy':    reviewedBy,
        'reviewedAt':    reviewedAt == null
                             ? null
                             : Timestamp.fromDate(reviewedAt!),
        'reviewerNotes': reviewerNotes,
      };
 
  factory BookingModel.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return BookingModel(
      id:            doc.id,
      lecturerId:    d['lecturerId']    as String? ?? '',
      lecturerName:  d['lecturerName']  as String? ?? '',
      type:          d['type']          as String? ?? BookingType.tempahanBilik,
      venue:         d['venue']         as String? ?? '',
      date:          (d['date']         as Timestamp).toDate(),
      startTime:     d['startTime']     as String? ?? '00:00',
      endTime:       d['endTime']       as String? ?? '00:00',
      programme:     d['programme']     as String? ?? '',
      subject:       d['subject']       as String? ?? '',
      purpose:       d['purpose']       as String? ?? '',
      remarks:       d['remarks']       as String? ?? '',
      status:        d['status']        as String? ?? BookingStatus.menunggu,
      createdAt:     (d['createdAt']    as Timestamp).toDate(),
      reviewedBy:    d['reviewedBy']    as String?,
      reviewedAt:    d['reviewedAt'] == null
                         ? null
                         : (d['reviewedAt'] as Timestamp).toDate(),
      reviewerNotes: d['reviewerNotes'] as String?,
    );
  }
 
  BookingModel copyWith({
    String? id,
    String? lecturerId,
    String? lecturerName,
    String? type,
    String? venue,
    DateTime? date,
    String? startTime,
    String? endTime,
    String? programme,
    String? subject,
    String? purpose,
    String? remarks,
    String? status,
    DateTime? createdAt,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? reviewerNotes,
  }) =>
      BookingModel(
        id:            id            ?? this.id,
        lecturerId:    lecturerId    ?? this.lecturerId,
        lecturerName:  lecturerName  ?? this.lecturerName,
        type:          type          ?? this.type,
        venue:         venue         ?? this.venue,
        date:          date          ?? this.date,
        startTime:     startTime     ?? this.startTime,
        endTime:       endTime       ?? this.endTime,
        programme:     programme     ?? this.programme,
        subject:       subject       ?? this.subject,
        purpose:       purpose       ?? this.purpose,
        remarks:       remarks       ?? this.remarks,
        status:        status        ?? this.status,
        createdAt:     createdAt     ?? this.createdAt,
        reviewedBy:    reviewedBy    ?? this.reviewedBy,
        reviewedAt:    reviewedAt    ?? this.reviewedAt,
        reviewerNotes: reviewerNotes ?? this.reviewerNotes,
      );
}