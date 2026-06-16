import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../controllers/timetable_controller.dart';
import '../../controllers/admin_controller.dart';
import '../../controllers/course_controller.dart';
import '../../models/timetable_slot_model.dart';
import '../../models/user_model.dart';
import '../../models/course_model.dart';
import 'admin/admin_shell.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Muat Naik Jadual (Admin)
// ─────────────────────────────────────────────────────────────────────────────
class UploadTimeScheduleView extends StatefulWidget {
  const UploadTimeScheduleView({super.key});
  @override
  State<UploadTimeScheduleView> createState() => _UploadState();
}

class _UploadState extends State<UploadTimeScheduleView> {
  final _formKey    = GlobalKey<FormState>();
  final _venueCtrl  = TextEditingController();
  final _csvCtrl    = TextEditingController();

  String? _selectedLecturerId;
  String? _selectedLecturerName;
  String? _selectedCourseId;
  String? _selectedCourseName;
  String? _selectedSection;
  DayOfWeek _day   = DayOfWeek.monday;
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end   = const TimeOfDay(hour: 10, minute: 30);
  bool _saving     = false;

  String _selectedSemester = 'Semester 1';
  String _selectedSession  = '2025/2026';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TimetableController>().loadSlots();
    });
  }

  @override
  void dispose() {
    _venueCtrl.dispose();
    _csvCtrl.dispose();
    super.dispose();
  }

  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final p = t.period == DayPeriod.am ? 'PG' : 'PTG';
    return '$h:$m $p';
  }

  String _fmt24(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _start : _end,
    );
    if (picked != null) setState(() => isStart ? _start = picked : _end = picked);
  }

  Future<void> _addSlot() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLecturerName == null) {
      _snack('Sila pilih pensyarah.', error: true); return;
    }
    if (_selectedCourseName == null) {
      _snack('Sila pilih kursus.', error: true); return;
    }
    if (_selectedSection == null) {
      _snack('Sila pilih seksyen.', error: true); return;
    }
    final sm = _start.hour * 60 + _start.minute;
    final em = _end.hour * 60 + _end.minute;
    if (em <= sm) { _snack('Masa tamat mesti selepas masa mula.', error: true); return; }

    setState(() => _saving = true);
    final error = await context.read<TimetableController>().addSlot(
      TimetableSlotModel(
        id: const Uuid().v4(),
        subject: _selectedCourseName!,
        lecturerName: _selectedLecturerName!,
        lecturerId: _selectedLecturerId ?? '',
        courseId: _selectedCourseId ?? '',
        venue: _venueCtrl.text.trim(),
        day: _day,
        startTime: _fmt24(_start),
        endTime: _fmt24(_end),
        section: _selectedSection!,
        semester: _selectedSemester,
        session: _selectedSession,
      ),
    );
    setState(() => _saving = false);
    if (!mounted) return;
    if (error != null) {
      _snack(error, error: true);
    } else {
      _snack('Slot berjaya ditambah!');
      setState(() {
        _selectedLecturerId = null; _selectedLecturerName = null;
        _selectedCourseId = null; _selectedCourseName = null;
        _selectedSection = null;
        _venueCtrl.clear();
      });
    }
  }

  Future<void> _importCsv() async {
    if (_selectedLecturerId == null) {
      _snack('Sila pilih pensyarah terlebih dahulu sebelum memuat naik CSV.', error: true);
      return;
    }

    final courses = context.read<CourseController>().courses;
    final timetableCtrl = context.read<TimetableController>();
    final existingSlots = timetableCtrl.slots;

    final lines = _csvCtrl.text.trim().split('\n');
    if (lines.isEmpty || (lines.length == 1 && lines[0].trim().isEmpty)) {
      _snack('Sila masukkan kandungan CSV.', error: true);
      return;
    }

    // Accumulator for successful slots to be added
    final List<TimetableSlotModel> batchSlots = [];

    // Parse each line and validate
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Skip CSV header if present (e.g. course_code, course_name, day, ...)
      if (i == 0 && line.toLowerCase().contains('course_code')) {
        continue;
      }

      final p = line.split(',');
      if (p.length < 8) {
        _snack('Baris ${i + 1}: Lajur tidak mencukupi (mesti ada 8 lajur).', error: true);
        return;
      }

      final courseCode = p[0].trim().toUpperCase();
      final rawDay = p[2].trim();
      final startTimeStr = p[3].trim(); // "HH:mm"
      final endTimeStr = p[4].trim();   // "HH:mm"
      final venue = p[5].trim();
      final semester = p[6].trim();
      final academicSession = p[7].trim();

      // 1. Verify course exists
      final course = courses.firstWhere(
        (c) => c.code.toUpperCase() == courseCode,
        orElse: () => const CourseModel(id: '', code: '', name: '', lecturerId: '', lecturerName: '', department: '', sections: 1),
      );
      if (course.id.isEmpty) {
        _snack('Baris ${i + 1}: Kod kursus "$courseCode" tidak wujud dalam Senarai Kursus.', error: true);
        return;
      }

      // 2. Parse and verify day
      final parsedDay = _parseCsvDay(rawDay);
      if (parsedDay == null) {
        _snack('Baris ${i + 1}: Hari "$rawDay" tidak sah (mesti Isnin-Jumaat).', error: true);
        return;
      }

      // 3. Verify start time is earlier than end time
      final sm = _toMinutes(startTimeStr);
      final em = _toMinutes(endTimeStr);
      if (em <= sm) {
        _snack('Baris ${i + 1}: Waktu tamat ($endTimeStr) mesti selepas waktu mula ($startTimeStr).', error: true);
        return;
      }

      // Create model
      final slot = TimetableSlotModel(
        id: const Uuid().v4(),
        subject: course.name,
        lecturerName: _selectedLecturerName!,
        lecturerId: _selectedLecturerId!,
        courseId: course.id,
        venue: venue,
        day: parsedDay,
        startTime: startTimeStr,
        endTime: endTimeStr,
        section: '$courseCode-01', // Default section
        semester: semester,
        session: academicSession,
      );

      // 4. Prevent duplicate / time conflict
      // Check against existing database slots
      final dbConflict = _findConflictInLists(slot, existingSlots);
      if (dbConflict != null) {
        final isVenueConflict = dbConflict.venue.trim().toLowerCase() == slot.venue.trim().toLowerCase();
        if (isVenueConflict) {
          _snack('Baris ${i + 1}: Konflik tempat dengan "${dbConflict.subject}" (${dbConflict.startTime}–${dbConflict.endTime}) di ${dbConflict.venue}.', error: true);
        } else {
          _snack('Baris ${i + 1}: Konflik pensyarah dengan "${dbConflict.subject}" (${dbConflict.startTime}–${dbConflict.endTime}).', error: true);
        }
        return;
      }

      // Check against batch slots (to prevent self-conflicts within the CSV upload)
      final batchConflict = _findConflictInLists(slot, batchSlots);
      if (batchConflict != null) {
        final isVenueConflict = batchConflict.venue.trim().toLowerCase() == slot.venue.trim().toLowerCase();
        if (isVenueConflict) {
          _snack('Baris ${i + 1}: Konflik tempat sesama CSV dengan "${batchConflict.subject}" (${batchConflict.startTime}–${batchConflict.endTime}) di ${batchConflict.venue}.', error: true);
        } else {
          _snack('Baris ${i + 1}: Konflik pensyarah sesama CSV dengan "${batchConflict.subject}" (${batchConflict.startTime}–${batchConflict.endTime}).', error: true);
        }
        return;
      }

      batchSlots.add(slot);
    }

    // If all pass validation, add them to DB!
    setState(() => _saving = true);
    int successfullyAdded = 0;
    for (final slot in batchSlots) {
      final err = await timetableCtrl.addSlot(slot);
      if (err == null) {
        successfullyAdded++;
      } else {
        _snack('Ralat semasa menyimpan ke pangkalan data: $err', error: true);
        setState(() => _saving = false);
        return;
      }
    }
    setState(() => _saving = false);
    _csvCtrl.clear();
    _snack('$successfullyAdded slot berjaya dimuat naik untuk $_selectedLecturerName.');
  }

  int _toMinutes(String hhmm) {
    final parts = hhmm.trim().split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  DayOfWeek? _parseCsvDay(String raw) {
    final clean = raw.trim().toLowerCase();
    if (clean == 'monday' || clean == 'isnin' || clean == '0') return DayOfWeek.monday;
    if (clean == 'tuesday' || clean == 'selasa' || clean == '1') return DayOfWeek.tuesday;
    if (clean == 'wednesday' || clean == 'rabu' || clean == '2') return DayOfWeek.wednesday;
    if (clean == 'thursday' || clean == 'khamis' || clean == '3') return DayOfWeek.thursday;
    if (clean == 'friday' || clean == 'jumaat' || clean == '4') return DayOfWeek.friday;
    return null;
  }

  TimetableSlotModel? _findConflictInLists(TimetableSlotModel candidate, List<TimetableSlotModel> list) {
    for (final s in list) {
      if (s.id == candidate.id) continue;
      if (s.day != candidate.day) continue;

      // Overlap: NOT (end1 <= start2 OR start1 >= end2)
      final hasOverlap = !(candidate.endTime.compareTo(s.startTime) <= 0 ||
          candidate.startTime.compareTo(s.endTime) >= 0);
      if (!hasOverlap) continue;

      // 1. Same venue conflict
      if (s.venue.trim().toLowerCase() == candidate.venue.trim().toLowerCase()) {
        return s;
      }

      // 2. Same lecturer conflict
      final sameLecturer = (candidate.lecturerId.isNotEmpty && s.lecturerId.isNotEmpty && candidate.lecturerId == s.lecturerId) ||
          (candidate.lecturerName.trim().toLowerCase() == s.lecturerName.trim().toLowerCase());
      if (sameLecturer) {
        return s;
      }
    }
    return null;
  }

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ));

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    final lecturers = context.watch<AdminController>().lecturers;
    final courses   = context.watch<CourseController>().courses;

    return AdminShell(
      currentRoute: '/admin/muat-naik-jadual',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Muat Naik Jadual Waktu',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Tambah slot jadual secara manual atau import CSV.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 20),

            // Dropdown Pilih Pensyarah Sasaran
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FieldLabel('Pilih Pensyarah Sasaran'),
                  DropdownButtonFormField<String>(
                    value: _selectedLecturerId,
                    decoration: _dec('Pilih pensyarah untuk mula menjadualkan'),
                    items: lecturers.map<DropdownMenuItem<String>>((l) => DropdownMenuItem<String>(
                      value: l.id,
                      child: Text(l.name),
                    )).toList(),
                    onChanged: (id) {
                      final l = lecturers.firstWhere((x) => x.id == id);
                      setState(() { 
                        _selectedLecturerId = id; 
                        _selectedLecturerName = l.name; 
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            LayoutBuilder(builder: (_, c) {
              final wide = c.maxWidth >= 800;
              final form = _buildForm(lecturers, courses);
              final csv  = _buildCsv();
              if (wide) {
                return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: form),
                  const SizedBox(width: 20),
                  Expanded(child: csv),
                ]);
              }
              return Column(children: [form, const SizedBox(height: 20), csv]);
            }),

            const SizedBox(height: 32),

            Consumer<TimetableController>(builder: (_, ctrl, __) {
              if (ctrl.isLoading || ctrl.slots.isEmpty) return const SizedBox.shrink();
              return _SlotList(
                slots: ctrl.slots,
                onDelete: (id) async {
                  await ctrl.deleteSlot(id);
                  setState(() {});
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(List<UserModel> lecturers, List<CourseModel> courses) {
    CourseModel? selectedCourse;
    if (_selectedCourseId != null) {
      try {
        selectedCourse = courses.firstWhere((x) => x.id == _selectedCourseId);
      } catch (_) {}
    }

    final List<String> sectionsList = [];
    if (selectedCourse != null) {
      for (int i = 1; i <= selectedCourse.sections; i++) {
        sectionsList.add('${selectedCourse.code}-${i.toString().padLeft(2, '0')}');
      }
    }

    return _Card(
      child: Form(
        key: _formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Entri slot tunggal manual',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // Pensyarah display
          _FieldLabel('Pensyarah Sasaran'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Text(
              _selectedLecturerName ?? 'Sila pilih pensyarah di menu atas',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: _selectedLecturerId == null ? Colors.red : const Color(0xFF1F2937),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Kursus dropdown
          _FieldLabel('Kursus'),
          DropdownButtonFormField<String>(
            value: _selectedCourseId,
            decoration: _dec('Pilih kursus'),
            items: courses.map<DropdownMenuItem<String>>((c) => DropdownMenuItem<String>(
              value: c.id,
              child: Text('${c.code} – ${c.name}'),
            )).toList(),
            onChanged: (id) {
              final c = courses.firstWhere((x) => x.id == id);
              setState(() { 
                _selectedCourseId = id; 
                _selectedCourseName = c.name; 
                _selectedSection = null; // Reset section when course changes
              });
            },
          ),
          const SizedBox(height: 14),

          // Seksyen dropdown
          _FieldLabel('Seksyen'),
          DropdownButtonFormField<String>(
            value: _selectedSection,
            decoration: _dec(_selectedCourseId == null ? 'Sila pilih kursus dahulu' : 'Pilih seksyen'),
            items: sectionsList.map<DropdownMenuItem<String>>((s) => DropdownMenuItem<String>(value: s, child: Text(s))).toList(),
            onChanged: _selectedCourseId == null ? null : (v) => setState(() => _selectedSection = v),
          ),
          const SizedBox(height: 14),

          // Semester & Sesi Akademik
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _FieldLabel('Semester'),
              DropdownButtonFormField<String>(
                value: _selectedSemester,
                decoration: _dec(''),
                items: const [
                  DropdownMenuItem(value: 'Semester 1', child: Text('Semester 1')),
                  DropdownMenuItem(value: 'Semester 2', child: Text('Semester 2')),
                  DropdownMenuItem(value: 'Semester 3', child: Text('Semester 3')),
                ],
                onChanged: (v) => setState(() => _selectedSemester = v!),
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _FieldLabel('Sesi Akademik'),
              DropdownButtonFormField<String>(
                value: _selectedSession,
                decoration: _dec(''),
                items: const [
                  DropdownMenuItem(value: '2025/2026', child: Text('2025/2026')),
                  DropdownMenuItem(value: '2026/2027', child: Text('2026/2027')),
                  DropdownMenuItem(value: '2027/2028', child: Text('2027/2028')),
                ],
                onChanged: (v) => setState(() => _selectedSession = v!),
              ),
            ])),
          ]),
          const SizedBox(height: 14),

          // Hari
          _FieldLabel('Hari'),
          DropdownButtonFormField<DayOfWeek>(
            value: _day,
            decoration: _dec(''),
            items: DayOfWeek.values.map<DropdownMenuItem<DayOfWeek>>((d) => DropdownMenuItem<DayOfWeek>(
              value: d,
              child: Text(_dayLabel(d)),
            )).toList(),
            onChanged: (v) => setState(() => _day = v!),
          ),
          const SizedBox(height: 14),

          // Masa
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _FieldLabel('Masa mula'),
              InkWell(
                onTap: () => _pickTime(true),
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: _dec(''),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_fmt(_start)),
                    const Icon(Icons.access_time, size: 17, color: Colors.grey),
                  ]),
                ),
              ),
            ])),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _FieldLabel('Masa tamat'),
              InkWell(
                onTap: () => _pickTime(false),
                borderRadius: BorderRadius.circular(4),
                child: InputDecorator(
                  decoration: _dec(''),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text(_fmt(_end)),
                    const Icon(Icons.access_time, size: 17, color: Colors.grey),
                  ]),
                ),
              ),
            ])),
          ]),
          const SizedBox(height: 14),

          // Tempat
          _FieldLabel('Lokasi / Bilik'),
          TextFormField(
            controller: _venueCtrl,
            decoration: _dec('cth. Blok A, Bilik 201'),
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _addSlot,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111827),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4)),
              ),
              child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Tambah Slot',
                      style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCsv() {
    return _Card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Muat naik CSV pukal',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('Format: course_code, course_name, day, start_time, end_time, venue, semester, academic_session',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: TextField(
            controller: _csvCtrl,
            maxLines: 9,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'course_code,course_name,day,start_time,end_time,venue,semester,academic_session\nCS101,Software Engineering,Monday,09:00,10:30,A201,Semester 1,2025/2026',
              hintStyle: TextStyle(color: Colors.grey, fontSize: 12),
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(14),
            ),
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: _importCsv,
            icon: const Icon(Icons.upload_outlined, size: 18),
            label: const Text('Import CSV',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF111827),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text('Tip: Pastikan kod kursus wujud dalam Senarai Kursus.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
      ]),
    );
  }

  String _dayLabel(DayOfWeek d) {
    const labels = {
      DayOfWeek.monday: 'Isnin',
      DayOfWeek.tuesday: 'Selasa',
      DayOfWeek.wednesday: 'Rabu',
      DayOfWeek.thursday: 'Khamis',
      DayOfWeek.friday: 'Jumaat',
    };
    return labels[d]!;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Slot Jadual Waktu (Admin baca sahaja)
// ─────────────────────────────────────────────────────────────────────────────
class ShowTimetableSlotView extends StatefulWidget {
  const ShowTimetableSlotView({super.key});
  @override
  State<ShowTimetableSlotView> createState() => _ShowState();
}

class _ShowState extends State<ShowTimetableSlotView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _query = '';

  static const _dayLabels = ['Isnin','Selasa','Rabu','Khamis','Jumaat'];

  int get _todayIndex {
    final wd = DateTime.now().weekday;
    return (wd >= 1 && wd <= 5) ? wd - 1 : 0;
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
        length: DayOfWeek.values.length, vsync: this, initialIndex: _todayIndex);
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TimetableController>().loadSlots();
    });
  }

  @override
  void dispose() { _tabCtrl.dispose(); _searchCtrl.dispose(); super.dispose(); }

  List<TimetableSlotModel> _filtered(TimetableController ctrl, DayOfWeek day) {
    var list = ctrl.slotsForDay(day);
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((s) =>
          s.subject.toLowerCase().contains(q) ||
          s.lecturerName.toLowerCase().contains(q) ||
          s.venue.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return AdminShell(
      currentRoute: '/admin/jadual',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Slot Jadual Waktu',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Lihat semua slot jadual mengikut hari.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              const SizedBox(height: 16),
              SizedBox(
                width: 400,
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Cari subjek, pensyarah, tempat…',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => _searchCtrl.clear())
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ]),
          ),
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              indicatorColor: const Color(0xFF8B1538),
              indicatorWeight: 2,
              labelColor: const Color(0xFF8B1538),
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              tabs: List.generate(DayOfWeek.values.length, (i) {
                final isToday = i == _todayIndex;
                return Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_dayLabels[i]),
                    if (isToday) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B1538),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('HARI INI',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ],
                  ]),
                );
              }),
            ),
          ),
          Expanded(
            child: Consumer<TimetableController>(builder: (_, ctrl, __) {
              if (ctrl.isLoading) return const Center(child: CircularProgressIndicator());
              return TabBarView(
                controller: _tabCtrl,
                children: DayOfWeek.values.map((day) {
                  final slots = _filtered(ctrl, day);
                  if (slots.isEmpty) {
                    return Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.event_busy_outlined, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _query.isNotEmpty ? 'Tiada hasil ditemui' : 'Tiada kelas pada hari ini',
                          style: TextStyle(color: Colors.grey[500], fontSize: 15),
                        ),
                      ]),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: slots.length,
                    itemBuilder: (_, i) => _SlotCard(slot: slots[i]),
                  );
                }).toList(),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0xFFE5E7EB))),
    color: Colors.white,
    child: Padding(padding: const EdgeInsets.all(24), child: child),
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
  );
}

class _SlotList extends StatelessWidget {
  final List<TimetableSlotModel> slots;
  final ValueChanged<String> onDelete;
  const _SlotList({required this.slots, required this.onDelete});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        const Text('Slot Sedia Ada', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(color: const Color(0xFFFDE8ED), borderRadius: BorderRadius.circular(20)),
          child: Text('${slots.length}', style: const TextStyle(color: Color(0xFF8B1538), fontWeight: FontWeight.w700, fontSize: 13)),
        ),
      ]),
      const SizedBox(height: 14),
      ...slots.map((s) => _SlotCard(slot: s, onDelete: () => onDelete(s.id))),
    ],
  );
}

class _SlotCard extends StatelessWidget {
  final TimetableSlotModel slot;
  final VoidCallback? onDelete;
  const _SlotCard({required this.slot, this.onDelete});

  static const _dayLabels = ['Isnin','Selasa','Rabu','Khamis','Jumaat'];

  Color get _accent {
    const colors = [Color(0xFF8B1538),Color(0xFF0891B2),Color(0xFF7C3AED),Color(0xFFDC2626),Color(0xFF059669)];
    return colors[slot.subject.length % colors.length];
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    elevation: 0,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0xFFE5E7EB))),
    color: Colors.white,
    child: IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          width: 4,
          decoration: BoxDecoration(
            color: _accent,
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(slot.subject,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14))),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _accent.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _accent.withOpacity(0.3)),
                    ),
                    child: Text(slot.section,
                        style: TextStyle(fontSize: 11, color: _accent, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 6),
                Wrap(spacing: 14, runSpacing: 6, children: [
                  _Tag(Icons.access_time_rounded, '${slot.startTime} – ${slot.endTime}'),
                  _Tag(Icons.location_on_outlined, slot.venue),
                  _Tag(Icons.person_outline_rounded, slot.lecturerName),
                  _Tag(Icons.calendar_today_outlined, _dayLabels[slot.day.index]),
                  _Tag(Icons.school_outlined, '${slot.semester} (${slot.session})'),
                ]),
              ])),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                  tooltip: 'Padam',
                ),
            ]),
          ),
        ),
      ]),
    ),
  );
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tag(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, size: 12, color: Colors.grey[500]),
    const SizedBox(width: 4),
    Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
  ]);
}