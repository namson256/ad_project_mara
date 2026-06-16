import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/booking_controller.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/timetable_controller.dart';
import '../../models/booking_model.dart';
import '../../models/course_model.dart';
import '../../models/timetable_slot_model.dart';
import 'lecturer_shell.dart';

class LecturerBookingView extends StatefulWidget {
  const LecturerBookingView({super.key});

  @override
  State<LecturerBookingView> createState() => _LecturerBookingViewState();
}

class _LecturerBookingViewState extends State<LecturerBookingView> {
  String _filter = 'Semua';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingController>().loadAll();
      context.read<TimetableController>().loadSlots();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final booking = context.watch<BookingController>();
    final me = auth.currentUser?.id ?? '';

    var myBookings = booking.forLecturer(me);
    if (_filter != 'Semua') {
      myBookings = myBookings.where((b) => b.status == _filter).toList();
    }

    return LecturerShell(
      currentRoute: '/lecturer-booking',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tempahan Bilik & Kelas Ganti',
                          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text(
                          'Mohon tempahan bilik atau kelas ganti. Permohonan akan disemak oleh Ketua Program.',
                          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B1538),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () => _openCreateDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tempahan Baharu'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Status summary cards
            Row(
              children: [
                Expanded(child: _StatPill(
                  label: 'JUMLAH',
                  value: '${booking.forLecturer(me).length}',
                  color: const Color(0xFF8B1538),
                  bg: const Color(0xFFFDE8ED),
                  icon: Icons.event_available_outlined,
                )),
                const SizedBox(width: 12),
                Expanded(child: _StatPill(
                  label: 'MENUNGGU',
                  value: '${booking.forLecturer(me).where((b) => b.isPending).length}',
                  color: const Color(0xFFD97706),
                  bg: const Color(0xFFFEF3C7),
                  icon: Icons.schedule_outlined,
                )),
                const SizedBox(width: 12),
                Expanded(child: _StatPill(
                  label: 'DILULUSKAN',
                  value: '${booking.forLecturer(me).where((b) => b.isApproved).length}',
                  color: const Color(0xFF059669),
                  bg: const Color(0xFFD1FAE5),
                  icon: Icons.check_circle_outline,
                )),
                const SizedBox(width: 12),
                Expanded(child: _StatPill(
                  label: 'DITOLAK',
                  value: '${booking.forLecturer(me).where((b) => b.isRejected).length}',
                  color: const Color(0xFFDC2626),
                  bg: const Color(0xFFFEE2E2),
                  icon: Icons.cancel_outlined,
                )),
              ],
            ),
            const SizedBox(height: 24),

            // ── Filter chips
            Wrap(
              spacing: 8,
              children: ['Semua', 'Menunggu', 'Diluluskan', 'Ditolak']
                  .map((s) => ChoiceChip(
                        label: Text(s),
                        selected: _filter == s,
                        onSelected: (_) => setState(() => _filter = s),
                        selectedColor: const Color(0xFFFDE8ED),
                        labelStyle: TextStyle(
                          color: _filter == s
                              ? const Color(0xFF8B1538)
                              : const Color(0xFF374151),
                          fontWeight: FontWeight.w600,
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // ── List
            if (booking.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (myBookings.isEmpty)
              _EmptyState(filter: _filter, onCreate: () => _openCreateDialog(context))
            else
              ...myBookings.map((b) => _BookingCard(
                    booking: b,
                    onCancel: b.isPending ? () => _confirmCancel(context, b) : null,
                  )),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  void _openCreateDialog(BuildContext context) {
    showDialog(context: context, builder: (_) => const _CreateBookingDialog());
  }

  Future<void> _confirmCancel(BuildContext context, BookingModel b) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan tempahan?'),
        content: Text('Tempahan untuk ${b.subject} pada ${_fmtDate(b.date)} akan dipadam.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Tidak')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ya, batalkan')),
        ],
      ),
    );
    if (yes != true) return;
    final err = await context.read<BookingController>().cancelBooking(b.id);
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }
}

// ─────────────────────────────────────────────────────────────────
// Occupied slot data class
// ─────────────────────────────────────────────────────────────────
class _OccupiedSlot {
  final String startTime;
  final String endTime;
  final String label;
  final String source; // 'Jadual', 'Tempahan', 'Menunggu'
  final String lecturer;
  const _OccupiedSlot({
    required this.startTime,
    required this.endTime,
    required this.label,
    required this.source,
    required this.lecturer,
  });
}

// ─────────────────────────────────────────────────────────────────
// Create Booking Dialog — auto-fetch, hourly slots, occupancy
// ─────────────────────────────────────────────────────────────────
class _CreateBookingDialog extends StatefulWidget {
  const _CreateBookingDialog();
  @override
  State<_CreateBookingDialog> createState() => _CreateBookingDialogState();
}

class _CreateBookingDialogState extends State<_CreateBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _purpose = TextEditingController();
  final _remarks = TextEditingController();

  String _type = BookingType.tempahanBilik;
  CourseModel? _selectedCourse;
  String? _selectedVenue;
  DateTime? _date;
  String? _startTime;
  String? _endTime;
  bool _submitting = false;

  /// Hourly time slots 08:00 – 18:00
  static const List<String> _allHours = [
    '08:00','09:00','10:00','11:00','12:00',
    '13:00','14:00','15:00','16:00','17:00','18:00',
  ];

  /// Start times: 08:00–17:00 (leave room for ≥1 hour)
  List<String> get _startOptions => _allHours.sublist(0, _allHours.length - 1);

  /// End times: hours after the selected start
  List<String> get _endOptions {
    if (_startTime == null) return [];
    final idx = _allHours.indexOf(_startTime!);
    if (idx == -1) return [];
    return _allHours.sublist(idx + 1);
  }

  @override
  void dispose() {
    _purpose.dispose();
    _remarks.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────

  int _toMinutes(String hhmm) {
    final p = hhmm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  List<String> _getVenues(TimetableController ctrl) {
    final v = <String>{};
    for (final s in ctrl.slots) {
      if (s.venue.trim().isNotEmpty) v.add(s.venue.trim());
    }
    return v.toList()..sort();
  }

  List<CourseModel> _lecturerCourses(CourseController ctrl, String uid) =>
      ctrl.courses.where((c) => c.lecturerId == uid).toList();

  List<_OccupiedSlot> _getOccupied(
    String venue,
    DateTime date,
    TimetableController tt,
    BookingController bk,
  ) {
    final List<_OccupiedSlot> out = [];
    final vl = venue.trim().toLowerCase();

    // Map weekday
    DayOfWeek? dow;
    switch (date.weekday) {
      case DateTime.monday:    dow = DayOfWeek.monday;    break;
      case DateTime.tuesday:   dow = DayOfWeek.tuesday;   break;
      case DateTime.wednesday: dow = DayOfWeek.wednesday;  break;
      case DateTime.thursday:  dow = DayOfWeek.thursday;   break;
      case DateTime.friday:    dow = DayOfWeek.friday;     break;
    }

    // Timetable slots on this weekday + venue
    if (dow != null) {
      for (final s in tt.slots) {
        if (s.venue.trim().toLowerCase() != vl) continue;
        if (s.day != dow) continue;
        out.add(_OccupiedSlot(
          startTime: s.startTime, endTime: s.endTime,
          label: s.subject, source: 'Jadual', lecturer: s.lecturerName,
        ));
      }
    }

    // Approved bookings on this date + venue
    for (final b in bk.bookings) {
      if (!b.isApproved) continue;
      if (b.venue.trim().toLowerCase() != vl) continue;
      if (b.date.year != date.year || b.date.month != date.month || b.date.day != date.day) continue;
      out.add(_OccupiedSlot(
        startTime: b.startTime, endTime: b.endTime,
        label: b.subject, source: 'Tempahan', lecturer: b.lecturerName,
      ));
    }

    // Pending bookings on this date + venue
    for (final b in bk.bookings) {
      if (!b.isPending) continue;
      if (b.venue.trim().toLowerCase() != vl) continue;
      if (b.date.year != date.year || b.date.month != date.month || b.date.day != date.day) continue;
      out.add(_OccupiedSlot(
        startTime: b.startTime, endTime: b.endTime,
        label: b.subject, source: 'Menunggu', lecturer: b.lecturerName,
      ));
    }

    out.sort((a, b) => a.startTime.compareTo(b.startTime));
    return out;
  }

  bool _hasConflict(String start, String end, List<_OccupiedSlot> occ) {
    final s1 = _toMinutes(start), e1 = _toMinutes(end);
    for (final o in occ) {
      final s2 = _toMinutes(o.startTime), e2 = _toMinutes(o.endTime);
      if (s1 < e2 && s2 < e1) return true;
    }
    return false;
  }

  bool _isHourBlocked(String hour, List<_OccupiedSlot> occ) {
    final h = _toMinutes(hour), hEnd = h + 60;
    for (final o in occ) {
      final s = _toMinutes(o.startTime), e = _toMinutes(o.endTime);
      if (h < e && s < hEnd) return true;
    }
    return false;
  }

  String _dayLabel(DateTime d) {
    const days = ['Isnin','Selasa','Rabu','Khamis','Jumaat','Sabtu','Ahad'];
    return days[d.weekday - 1];
  }

  InputDecoration _dec({String? hint}) => InputDecoration(
    hintText: hint,
    filled: true, fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: const BorderSide(color: Color(0xFF8B1538), width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth       = context.watch<AuthController>();
    final courseCtrl  = context.watch<CourseController>();
    final ttCtrl     = context.watch<TimetableController>();
    final bkCtrl     = context.watch<BookingController>();
    final user       = auth.currentUser;

    final myCourses = _lecturerCourses(courseCtrl, user?.id ?? '');
    final venues    = _getVenues(ttCtrl);

    // Occupied slots for selected venue + date
    List<_OccupiedSlot> occupied = [];
    if (_selectedVenue != null && _date != null) {
      occupied = _getOccupied(_selectedVenue!, _date!, ttCtrl, bkCtrl);
    }

    final bool conflict = _startTime != null && _endTime != null && occupied.isNotEmpty
        ? _hasConflict(_startTime!, _endTime!, occupied)
        : false;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 780),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(children: [
                const Expanded(child: Text('Tempahan Baharu',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
            ),
            const Divider(height: 1),

            // ── Form ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Auto-filled lecturer name ──────────────────
                      const _Label('Nama Pensyarah'),
                      _AutoFilledField(value: user?.name ?? 'Pensyarah', icon: Icons.person_outline),
                      const SizedBox(height: 14),

                      // ── Booking type ───────────────────────────────
                      const _Label('Jenis Tempahan'),
                      DropdownButtonFormField<String>(
                        value: _type,
                        decoration: _dec(),
                        items: const [
                          DropdownMenuItem(value: BookingType.tempahanBilik, child: Text('Tempahan Bilik')),
                          DropdownMenuItem(value: BookingType.kelasGanti,    child: Text('Kelas Ganti')),
                        ],
                        onChanged: (v) => setState(() => _type = v ?? _type),
                      ),
                      const SizedBox(height: 14),

                      // ── Course selection (auto-fetch subject + programme) ──
                      const _Label('Subjek / Kursus'),
                      if (myCourses.isEmpty)
                        Container(
                          width: double.infinity, padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Row(children: [
                            Icon(Icons.info_outline, size: 16, color: Color(0xFFD97706)),
                            SizedBox(width: 8),
                            Expanded(child: Text('Tiada kursus ditemui untuk akaun anda. Sila hubungi admin.',
                                style: TextStyle(fontSize: 12, color: Color(0xFF92400E)))),
                          ]),
                        )
                      else
                        DropdownButtonFormField<String>(
                          value: _selectedCourse?.id,
                          decoration: _dec(hint: 'Pilih kursus yang diajar'),
                          isExpanded: true,
                          items: myCourses.map((c) => DropdownMenuItem<String>(
                            value: c.id,
                            child: Text('${c.code} — ${c.name}', style: const TextStyle(fontSize: 13)),
                          )).toList(),
                          validator: (v) => v == null ? 'Sila pilih kursus' : null,
                          onChanged: (v) {
                            if (v == null) return;
                            setState(() => _selectedCourse = myCourses.firstWhere((c) => c.id == v));
                          },
                        ),

                      // Auto-filled programme info
                      if (_selectedCourse != null) ...[
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F9FF), borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFBAE6FD)),
                          ),
                          child: Row(children: [
                            const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF0284C7)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(
                              'Program: ${_selectedCourse!.department}  ·  Seksyen: ${_selectedCourse!.sections}',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF0369A1), fontWeight: FontWeight.w600),
                            )),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(4)),
                              child: const Text('Auto', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                            ),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // ── Venue dropdown (from timetable) ────────────
                      const _Label('Bilik / Venue'),
                      DropdownButtonFormField<String>(
                        value: _selectedVenue,
                        decoration: _dec(hint: 'Pilih bilik'),
                        isExpanded: true,
                        items: venues.map((v) => DropdownMenuItem<String>(
                          value: v,
                          child: Row(children: [
                            const Icon(Icons.meeting_room_outlined, size: 16, color: Color(0xFF6B7280)),
                            const SizedBox(width: 8),
                            Text(v, style: const TextStyle(fontSize: 13)),
                          ]),
                        )).toList(),
                        validator: (v) => v == null ? 'Sila pilih bilik' : null,
                        onChanged: (v) => setState(() {
                          _selectedVenue = v;
                          _startTime = null;
                          _endTime = null;
                        }),
                      ),
                      const SizedBox(height: 14),

                      // ── Date picker ────────────────────────────────
                      const _Label('Tarikh'),
                      InkWell(
                        onTap: () async {
                          final now = DateTime.now();
                          final d = await showDatePicker(
                            context: context,
                            initialDate: _date ?? now,
                            firstDate: now,
                            lastDate: now.add(const Duration(days: 365)),
                          );
                          if (d != null) setState(() { _date = d; _startTime = null; _endTime = null; });
                        },
                        child: InputDecorator(
                          decoration: _dec(),
                          child: Row(children: [
                            Icon(Icons.calendar_today, size: 16,
                                color: _date == null ? const Color(0xFF9CA3AF) : const Color(0xFF8B1538)),
                            const SizedBox(width: 8),
                            Text(
                              _date == null ? 'Pilih tarikh' : '${_fmtDate(_date!)} (${_dayLabel(_date!)})',
                              style: TextStyle(color: _date == null ? const Color(0xFF9CA3AF) : const Color(0xFF111827)),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ── Room occupancy timeline ────────────────────
                      if (_selectedVenue != null && _date != null) ...[
                        _RoomTimeline(occupied: occupied, selStart: _startTime, selEnd: _endTime),
                        const SizedBox(height: 14),
                      ],

                      // ── Start + End time ───────────────────────────
                      Row(children: [
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _Label('Waktu Mula'),
                            DropdownButtonFormField<String>(
                              value: _startTime,
                              decoration: _dec(hint: 'Pilih'),
                              isExpanded: true,
                              items: _startOptions.map((t) {
                                final blocked = _isHourBlocked(t, occupied);
                                return DropdownMenuItem<String>(
                                  value: t, enabled: !blocked,
                                  child: Row(children: [
                                    Icon(blocked ? Icons.block : Icons.access_time, size: 14,
                                        color: blocked ? const Color(0xFFDC2626) : const Color(0xFF059669)),
                                    const SizedBox(width: 6),
                                    Text(t, style: TextStyle(
                                      fontSize: 13,
                                      color: blocked ? const Color(0xFF9CA3AF) : const Color(0xFF111827),
                                      decoration: blocked ? TextDecoration.lineThrough : null,
                                    )),
                                    if (blocked) ...[
                                      const SizedBox(width: 6),
                                      const Text('Ditempah', style: TextStyle(fontSize: 10, color: Color(0xFFDC2626), fontWeight: FontWeight.w600)),
                                    ],
                                  ]),
                                );
                              }).toList(),
                              validator: (v) => v == null ? 'Wajib' : null,
                              onChanged: (v) => setState(() {
                                _startTime = v;
                                if (v != null) {
                                  final idx = _allHours.indexOf(v);
                                  if (idx != -1 && idx + 1 < _allHours.length) _endTime = _allHours[idx + 1];
                                }
                              }),
                            ),
                          ],
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _Label('Waktu Tamat'),
                            DropdownButtonFormField<String>(
                              value: _endTime,
                              decoration: _dec(hint: 'Pilih'),
                              isExpanded: true,
                              items: _endOptions.map((t) => DropdownMenuItem<String>(
                                value: t, child: Text(t, style: const TextStyle(fontSize: 13)),
                              )).toList(),
                              validator: (v) => v == null ? 'Wajib' : null,
                              onChanged: (v) => setState(() => _endTime = v),
                            ),
                          ],
                        )),
                      ]),

                      // ── Conflict warning ───────────────────────────
                      if (conflict) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity, padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: const Row(children: [
                            Icon(Icons.warning_amber_outlined, size: 18, color: Color(0xFFDC2626)),
                            SizedBox(width: 8),
                            Expanded(child: Text(
                              'Konflik masa dikesan! Bilik ini sudah ditempah pada waktu yang dipilih. Sila pilih waktu lain.',
                              style: TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w600),
                            )),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 14),

                      // ── Purpose ────────────────────────────────────
                      const _Label('Tujuan'),
                      TextFormField(
                        controller: _purpose,
                        decoration: _dec(hint: 'cth. Kuliah ganti untuk minggu ke-5'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 14),

                      // ── Remarks ────────────────────────────────────
                      const _Label('Catatan (pilihan)'),
                      TextFormField(
                        controller: _remarks, maxLines: 2,
                        decoration: _dec(hint: 'Maklumat tambahan untuk Ketua Program'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // ── Footer ──
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  onPressed: _submitting ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: conflict ? const Color(0xFF9CA3AF) : const Color(0xFF8B1538),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  ),
                  onPressed: (_submitting || conflict) ? null : _submit,
                  child: _submitting
                      ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Hantar Tempahan'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null)                      { _toast('Sila pilih tarikh.');                  return; }
    if (_startTime == null || _endTime == null) { _toast('Sila pilih waktu mula dan tamat.'); return; }
    if (_selectedCourse == null)             { _toast('Sila pilih kursus.');                  return; }

    setState(() => _submitting = true);
    final user = context.read<AuthController>().currentUser;
    final err = await context.read<BookingController>().createBooking(
      lecturerId:   user?.id ?? '',
      lecturerName: user?.name ?? '',
      type:         _type,
      venue:        _selectedVenue ?? '',
      date:         _date!,
      startTime:    _startTime!,
      endTime:      _endTime!,
      programme:    _selectedCourse!.department,
      subject:      '${_selectedCourse!.code} — ${_selectedCourse!.name}',
      purpose:      _purpose.text,
      remarks:      _remarks.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (err != null) { _toast(err); return; }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Tempahan dihantar. Menunggu kelulusan Ketua Program.'),
      backgroundColor: Color(0xFF059669),
    ));
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

// ─────────────────────────────────────────────────────────────────
// Auto-filled read-only field widget
// ─────────────────────────────────────────────────────────────────
class _AutoFilledField extends StatelessWidget {
  final String value;
  final IconData icon;
  const _AutoFilledField({required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: const Color(0xFF8B1538)),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: const Color(0xFFD1FAE5), borderRadius: BorderRadius.circular(4)),
          child: const Text('Auto', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Room Occupancy Timeline
// ─────────────────────────────────────────────────────────────────
class _RoomTimeline extends StatelessWidget {
  final List<_OccupiedSlot> occupied;
  final String? selStart;
  final String? selEnd;
  const _RoomTimeline({required this.occupied, this.selStart, this.selEnd});

  static const int _h0 = 8, _h1 = 18, _span = _h1 - _h0;

  int _toMin(String hm) {
    final p = hm.split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Title + legend
        Row(children: [
          const Icon(Icons.schedule_outlined, size: 16, color: Color(0xFF8B1538)),
          const SizedBox(width: 6),
          const Text('Status Ketersediaan Bilik',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const Spacer(),
          _dot(const Color(0xFFDCFCE7), 'Kosong'),
          const SizedBox(width: 10),
          _dot(const Color(0xFFFEE2E2), 'Ditempah'),
          const SizedBox(width: 10),
          _dot(const Color(0xFFFEF3C7), 'Menunggu'),
        ]),
        const SizedBox(height: 14),

        // Timeline
        LayoutBuilder(builder: (_, box) {
          final w = box.maxWidth;
          final hw = w / _span;

          return Column(children: [
            // Hour labels
            Row(children: List.generate(_span + 1, (i) {
              return SizedBox(
                width: i < _span ? hw : 0,
                child: Text('${(_h0 + i).toString().padLeft(2, '0')}',
                    style: TextStyle(fontSize: 9, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
              );
            })),
            const SizedBox(height: 4),

            // Bar
            SizedBox(height: 36, child: Stack(children: [
              // Green background
              Container(decoration: BoxDecoration(
                color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4),
              )),

              // Grid lines
              ...List.generate(_span - 1, (i) {
                return Positioned(left: (i + 1) * hw, top: 0, bottom: 0,
                    child: Container(width: 1, color: Colors.white.withValues(alpha: 0.6)));
              }),

              // Occupied blocks
              ...occupied.map((s) => _block(s, w)),

              // Selection highlight
              if (selStart != null && selEnd != null)
                _selectionBlock(w),
            ])),
          ]);
        }),

        // Detail list
        if (occupied.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...occupied.map((s) {
            final pending = s.source == 'Menunggu';
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(
                  color: pending ? const Color(0xFFD97706) : const Color(0xFFDC2626),
                  shape: BoxShape.circle,
                )),
                const SizedBox(width: 8),
                Text('${s.startTime}–${s.endTime}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                const SizedBox(width: 8),
                Expanded(child: Text('${s.label} (${s.lecturer})',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: pending ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(s.source, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                      color: pending ? const Color(0xFFD97706) : const Color(0xFFDC2626))),
                ),
              ]),
            );
          }),
        ] else ...[
          const SizedBox(height: 10),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF059669)),
            SizedBox(width: 6),
            Text('Bilik ini kosong sepanjang hari.',
                style: TextStyle(fontSize: 12, color: Color(0xFF059669), fontWeight: FontWeight.w600)),
          ]),
        ],
      ]),
    );
  }

  Widget _block(_OccupiedSlot s, double totalW) {
    final sMin = _toMin(s.startTime).clamp(_h0 * 60, _h1 * 60);
    final eMin = _toMin(s.endTime).clamp(_h0 * 60, _h1 * 60);
    if (sMin >= eMin) return const SizedBox.shrink();
    final range = (_h1 - _h0) * 60;
    final left  = (sMin - _h0 * 60) / range * totalW;
    final width = (eMin - sMin) / range * totalW;
    final pending = s.source == 'Menunggu';

    return Positioned(left: left, width: width, top: 0, bottom: 0,
      child: Tooltip(
        message: '${s.label}\n${s.startTime}–${s.endTime}\n${s.lecturer}\n(${s.source})',
        child: Container(
          decoration: BoxDecoration(
            color: pending ? const Color(0xFFFEF3C7) : const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: pending ? const Color(0xFFFDE68A) : const Color(0xFFFCA5A5)),
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(s.label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
                  color: pending ? const Color(0xFF92400E) : const Color(0xFFDC2626))),
        ),
      ),
    );
  }

  Widget _selectionBlock(double totalW) {
    final sMin = _toMin(selStart!);
    final eMin = _toMin(selEnd!);
    final range = (_h1 - _h0) * 60;
    final left  = (sMin - _h0 * 60) / range * totalW;
    final width = (eMin - sMin) / range * totalW;

    bool clash = false;
    for (final o in occupied) {
      final os = _toMin(o.startTime), oe = _toMin(o.endTime);
      if (sMin < oe && os < eMin) { clash = true; break; }
    }

    return Positioned(left: left, width: width, top: 0, bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: (clash ? const Color(0xFFDC2626) : const Color(0xFF8B1538)).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: clash ? const Color(0xFFDC2626) : const Color(0xFF8B1538), width: 2),
        ),
        alignment: Alignment.center,
        child: Text(clash ? 'KONFLIK' : 'Pilihan Anda',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800,
                color: clash ? const Color(0xFFDC2626) : const Color(0xFF8B1538))),
      ),
    );
  }

  Widget _dot(Color c, String label) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(
      color: c, borderRadius: BorderRadius.circular(2), border: Border.all(color: Colors.grey.shade300),
    )),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 9, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
  ]);
}

// ─────────────────────────────────────────────────────────────────
// Shared sub-widgets
// ─────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w600)),
  );
}

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color, bg;
  final IconData icon;
  const _StatPill({required this.label, required this.value, required this.color, required this.bg, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Row(children: [
        Container(width: 38, height: 38, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(4)),
            child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, letterSpacing: 1.1, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ])),
      ]),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onCancel;
  const _BookingCard({required this.booking, this.onCancel});
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(booking.subject, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              _TypeBadge(type: booking.type),
            ]),
            const SizedBox(height: 4),
            Text('${booking.programme}  •  ${booking.venue}  •  ${_fmtDate(booking.date)}  •  ${booking.startTime}–${booking.endTime}',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
          ])),
          _StatusBadge(status: booking.status),
        ]),
        const SizedBox(height: 12), const Divider(height: 1), const SizedBox(height: 12),
        _Field('Tujuan', booking.purpose),
        if (booking.remarks.isNotEmpty) _Field('Catatan', booking.remarks),
        if (booking.reviewerNotes != null && booking.reviewerNotes!.isNotEmpty)
          _Field(booking.isRejected ? 'Sebab Penolakan' : 'Nota Ketua Program', booking.reviewerNotes!,
              color: booking.isRejected ? const Color(0xFFDC2626) : const Color(0xFF059669)),
        if (onCancel != null) ...[
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(
            onPressed: onCancel, style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC2626)),
            icon: const Icon(Icons.delete_outline, size: 16), label: const Text('Batalkan'),
          )),
        ],
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final String label, value;
  final Color? color;
  const _Field(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: RichText(text: TextSpan(
      style: const TextStyle(color: Color(0xFF374151), fontSize: 13, height: 1.4),
      children: [
        TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w700)),
        TextSpan(text: value, style: TextStyle(color: color ?? const Color(0xFF374151))),
      ],
    )),
  );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    late final Color fg, bg;
    switch (status) {
      case BookingStatus.diluluskan: fg = const Color(0xFF059669); bg = const Color(0xFFD1FAE5); break;
      case BookingStatus.ditolak:    fg = const Color(0xFFDC2626); bg = const Color(0xFFFEE2E2); break;
      default:                       fg = const Color(0xFFD97706); bg = const Color(0xFFFEF3C7);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});
  @override
  Widget build(BuildContext context) {
    final r = type == BookingType.kelasGanti;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: r ? const Color(0xFFFDE8ED) : const Color(0xFFE0F2FE), borderRadius: BorderRadius.circular(6)),
      child: Text(type, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: r ? const Color(0xFF8B1538) : const Color(0xFF0891B2))),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  final VoidCallback onCreate;
  const _EmptyState({required this.filter, required this.onCreate});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFE5E7EB))),
      child: Column(children: [
        const Icon(Icons.event_busy_outlined, size: 48, color: Color(0xFF9CA3AF)),
        const SizedBox(height: 12),
        Text(filter == 'Semua' ? 'Belum ada tempahan.' : 'Tiada tempahan berstatus "$filter".',
            style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
        if (filter == 'Semua') ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8B1538)),
            onPressed: onCreate, icon: const Icon(Icons.add, size: 16),
            label: const Text('Cipta tempahan pertama anda'),
          ),
        ],
      ]),
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';