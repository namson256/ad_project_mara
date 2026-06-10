import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/booking_model.dart';
import '../models/timetable_slot_model.dart';

/// BookingController
/// -----------------
/// Manages booking requests in Firestore (`bookings` collection).
///
/// Responsibilities:
///   * Lecturer  : create + list own bookings
///   * Ketua     : list pending, approve, reject — conflict-checked
///   * All       : conflict detection against timetable slots + approved bookings
class BookingController extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final _col = 'bookings';

  List<BookingModel> _bookings = [];
  bool _isLoading = false;
  String? _error;

  List<BookingModel> get bookings  => List.unmodifiable(_bookings);
  bool get isLoading               => _isLoading;
  String? get error                => _error;

  // Convenience filters
  List<BookingModel> get pending   =>
      _bookings.where((b) => b.isPending).toList();
  List<BookingModel> get approved  =>
      _bookings.where((b) => b.isApproved).toList();
  List<BookingModel> get rejected  =>
      _bookings.where((b) => b.isRejected).toList();

  /// Returns only the approved replacement classes (Kelas Ganti).
  /// Useful for showing them in timetable views.
  List<BookingModel> get approvedReplacements => _bookings
      .where((b) => b.isApproved && b.isReplacement)
      .toList();

  List<BookingModel> forLecturer(String lecturerId) =>
      _bookings.where((b) => b.lecturerId == lecturerId).toList();

  // ── Loading ────────────────────────────────────────────────────────

  Future<void> loadAll() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final snap = await _db
          .collection(_col)
          .orderBy('createdAt', descending: true)
          .get();
      _bookings = snap.docs.map(BookingModel.fromDoc).toList();
    } catch (e) {
      _error = 'Gagal memuatkan tempahan: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Create (lecturer) ──────────────────────────────────────────────

  /// Creates a new booking with status = Menunggu.
  /// Returns `null` on success, or an error message string on failure.
  Future<String?> createBooking({
    required String lecturerId,
    required String lecturerName,
    required String type,
    required String venue,
    required DateTime date,
    required String startTime,
    required String endTime,
    required String programme,
    required String subject,
    required String purpose,
    required String remarks,
  }) async {
    // Basic validation
    if (venue.trim().isEmpty)     return 'Sila isi bilik.';
    if (programme.trim().isEmpty) return 'Sila isi program / kelas.';
    if (subject.trim().isEmpty)   return 'Sila isi subjek.';
    if (purpose.trim().isEmpty)   return 'Sila isi tujuan.';
    if (_toMinutes(endTime) <= _toMinutes(startTime)) {
      return 'Waktu tamat mesti lewat daripada waktu mula.';
    }
    if (date.isBefore(DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day))) {
      return 'Tarikh tidak boleh sebelum hari ini.';
    }

    try {
      final docRef = _db.collection(_col).doc();
      final booking = BookingModel(
        id:           docRef.id,
        lecturerId:   lecturerId,
        lecturerName: lecturerName,
        type:         type,
        venue:        venue.trim(),
        date:         DateTime(date.year, date.month, date.day),
        startTime:    startTime,
        endTime:      endTime,
        programme:    programme.trim(),
        subject:      subject.trim(),
        purpose:      purpose.trim(),
        remarks:      remarks.trim(),
        status:       BookingStatus.menunggu,
        createdAt:    DateTime.now(),
      );
      await docRef.set(booking.toMap());
      _bookings.insert(0, booking);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('createBooking error: $e');
      return 'Gagal menghantar tempahan: $e';
    }
  }

  // ── Approve / Reject (ketua) ───────────────────────────────────────

  /// Approves a booking after checking for conflicts.
  /// Returns `null` on success, or an error/conflict message.
  Future<String?> approveBooking({
    required String bookingId,
    required String reviewerId,
    String? notes,
    required List<TimetableSlotModel> timetableSlots,
  }) async {
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    if (idx == -1) return 'Tempahan tidak ditemui.';
    final booking = _bookings[idx];

    // Conflict check
    final conflict = detectConflict(
      venue:      booking.venue,
      date:       booking.date,
      startTime:  booking.startTime,
      endTime:    booking.endTime,
      slots:      timetableSlots,
      excludeBookingId: bookingId,
    );
    if (conflict != null) return conflict;

    // Persist
    try {
      final now = DateTime.now();
      await _db.collection(_col).doc(bookingId).update({
        'status':        BookingStatus.diluluskan,
        'reviewedBy':    reviewerId,
        'reviewedAt':    Timestamp.fromDate(now),
        'reviewerNotes': notes,
      });
      _bookings[idx] = booking.copyWith(
        status:        BookingStatus.diluluskan,
        reviewedBy:    reviewerId,
        reviewedAt:    now,
        reviewerNotes: notes,
      );
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('approveBooking error: $e');
      return 'Gagal meluluskan tempahan: $e';
    }
  }

  Future<String?> rejectBooking({
    required String bookingId,
    required String reviewerId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) return 'Sila berikan sebab penolakan.';
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    if (idx == -1) return 'Tempahan tidak ditemui.';
    final booking = _bookings[idx];

    try {
      final now = DateTime.now();
      await _db.collection(_col).doc(bookingId).update({
        'status':        BookingStatus.ditolak,
        'reviewedBy':    reviewerId,
        'reviewedAt':    Timestamp.fromDate(now),
        'reviewerNotes': reason.trim(),
      });
      _bookings[idx] = booking.copyWith(
        status:        BookingStatus.ditolak,
        reviewedBy:    reviewerId,
        reviewedAt:    now,
        reviewerNotes: reason.trim(),
      );
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('rejectBooking error: $e');
      return 'Gagal menolak tempahan: $e';
    }
  }

  /// Lecturer cancels their own pending booking.
  Future<String?> cancelBooking(String bookingId) async {
    final idx = _bookings.indexWhere((b) => b.id == bookingId);
    if (idx == -1) return 'Tempahan tidak ditemui.';
    if (!_bookings[idx].isPending) {
      return 'Hanya tempahan menunggu boleh dibatalkan.';
    }
    try {
      await _db.collection(_col).doc(bookingId).delete();
      _bookings.removeAt(idx);
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('cancelBooking error: $e');
      return 'Gagal membatalkan tempahan: $e';
    }
  }

  // ── Conflict detection ─────────────────────────────────────────────

  /// Checks whether the given venue/date/time overlaps with:
  ///   1) any timetable slot on the same weekday + venue
  ///   2) any approved booking on the same date + venue
  ///
  /// Returns a human-readable conflict message, or `null` if free.
  String? detectConflict({
    required String venue,
    required DateTime date,
    required String startTime,
    required String endTime,
    required List<TimetableSlotModel> slots,
    String? excludeBookingId,
  }) {
    final venueLower = venue.trim().toLowerCase();
    final dayOfWeek = _dayOfWeekFromDate(date);

    // 1) Timetable slot conflict (only weekdays Mon–Fri are in the enum)
    if (dayOfWeek != null) {
      for (final slot in slots) {
        if (slot.venue.trim().toLowerCase() != venueLower) continue;
        if (slot.day != dayOfWeek) continue;
        if (_overlap(slot.startTime, slot.endTime, startTime, endTime)) {
          return 'Konflik dengan slot jadual: '
              '${slot.subject} (${slot.startTime}–${slot.endTime}) di $venue.';
        }
      }
    }

    // 2) Approved booking conflict on same exact date
    for (final b in _bookings) {
      if (b.id == excludeBookingId) continue;
      if (!b.isApproved) continue;
      if (b.venue.trim().toLowerCase() != venueLower) continue;
      if (!_sameDate(b.date, date)) continue;
      if (_overlap(b.startTime, b.endTime, startTime, endTime)) {
        return 'Konflik dengan tempahan diluluskan: '
            '${b.subject} (${b.startTime}–${b.endTime}) di $venue.';
      }
    }

    return null;
  }

  // ── Internal helpers ───────────────────────────────────────────────

  int _toMinutes(String hhmm) {
    final parts = hhmm.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }

  bool _overlap(String a1, String a2, String b1, String b2) {
    final s1 = _toMinutes(a1);
    final e1 = _toMinutes(a2);
    final s2 = _toMinutes(b1);
    final e2 = _toMinutes(b2);
    return s1 < e2 && s2 < e1;
  }

  bool _sameDate(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  DayOfWeek? _dayOfWeekFromDate(DateTime d) {
    switch (d.weekday) {
      case DateTime.monday:    return DayOfWeek.monday;
      case DateTime.tuesday:   return DayOfWeek.tuesday;
      case DateTime.wednesday: return DayOfWeek.wednesday;
      case DateTime.thursday:  return DayOfWeek.thursday;
      case DateTime.friday:    return DayOfWeek.friday;
      default: return null;
    }
  }
}