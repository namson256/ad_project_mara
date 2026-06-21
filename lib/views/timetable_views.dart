import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
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

  PlatformFile? _selectedFile;
  bool _isUploading = false;

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

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        if (file.name.toLowerCase().endsWith('.csv')) {
          setState(() {
            _selectedFile = file;
          });
        } else {
          _snack('Muat Naik Gagal: Hanya fail CSV dibenarkan.', error: true);
        }
      }
    } catch (e) {
      _snack('Muat Naik Gagal: Ralat memilih fail: $e', error: true);
    }
  }

  void _clearFile() {
    setState(() {
      _selectedFile = null;
    });
  }

  Future<void> _importCsv() async {
    if (_selectedLecturerId == null) {
      _snack('Muat Naik Gagal: Sila pilih pensyarah terlebih dahulu sebelum memuat naik CSV.', error: true);
      return;
    }
    if (_selectedFile == null) {
      _snack('Muat Naik Gagal: Sila pilih fail CSV terlebih dahulu.', error: true);
      return;
    }

    final courses = context.read<CourseController>().courses;
    final timetableCtrl = context.read<TimetableController>();
    final existingSlots = timetableCtrl.slots;

    final bytes = _selectedFile!.bytes;
    if (bytes == null) {
      _snack('Muat Naik Gagal: Kandungan fail tidak dapat dibaca.', error: true);
      return;
    }

    String csvContent;
    try {
      csvContent = utf8.decode(bytes);
    } catch (e) {
      _snack('Muat Naik Gagal: Gagal menyahkod kandungan fail CSV.', error: true);
      return;
    }

    final lines = csvContent.split(RegExp(r'\r?\n')).map((line) => line.trim()).toList();
    lines.removeWhere((line) => line.isEmpty);

    if (lines.isEmpty) {
      _snack('Muat Naik Gagal: Fail CSV kosong.', error: true);
      return;
    }

    // Validate headers
    final headerLine = lines[0];
    final headers = headerLine.split(',').map((h) => h.trim().toLowerCase()).toList();

    final requiredColumns = [
      'course_code',
      'course_name',
      'day',
      'start_time',
      'end_time',
      'venue',
      'semester',
      'academic_session'
    ];

    for (final col in requiredColumns) {
      if (!headers.contains(col)) {
        _snack('Muat Naik Gagal: Lajur wajib "$col" tidak ditemui dalam fail CSV.', error: true);
        return;
      }
    }

    final courseCodeIdx = headers.indexOf('course_code');
    final courseNameIdx = headers.indexOf('course_name');
    final dayIdx = headers.indexOf('day');
    final startTimeIdx = headers.indexOf('start_time');
    final endTimeIdx = headers.indexOf('end_time');
    final venueIdx = headers.indexOf('venue');
    final semesterIdx = headers.indexOf('semester');
    final sessionIdx = headers.indexOf('academic_session');

    final List<TimetableSlotModel> batchSlots = [];

    // Parse each line and validate
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final p = line.split(',');
      if (p.length < headers.length) {
        _snack('Muat Naik Gagal: Baris ${i + 1} tidak mempunyai lajur yang mencukupi.', error: true);
        return;
      }

      final courseCode = p[courseCodeIdx].trim().toUpperCase();
      final courseNameVal = p[courseNameIdx].trim();
      final rawDay = p[dayIdx].trim();
      final startTimeStr = p[startTimeIdx].trim(); // "HH:mm"
      final endTimeStr = p[endTimeIdx].trim();   // "HH:mm"
      final venue = p[venueIdx].trim();
      final semester = p[semesterIdx].trim();
      final academicSession = p[sessionIdx].trim();

      if (courseCode.isEmpty || courseNameVal.isEmpty || rawDay.isEmpty ||
          startTimeStr.isEmpty || endTimeStr.isEmpty || venue.isEmpty ||
          semester.isEmpty || academicSession.isEmpty) {
        _snack('Muat Naik Gagal: Baris ${i + 1} mengandungi maklumat kosong.', error: true);
        return;
      }

      // 1. Verify course exists
      final course = courses.firstWhere(
        (c) => c.code.toUpperCase() == courseCode,
        orElse: () => const CourseModel(id: '', code: '', name: '', lecturerId: '', lecturerName: '', department: '', sections: 1),
      );
      if (course.id.isEmpty) {
        _snack('Muat Naik Gagal: Kod kursus "$courseCode" tidak wujud dalam Senarai Kursus.', error: true);
        return;
      }

      // 2. Parse and verify day
      final parsedDay = _parseCsvDay(rawDay);
      if (parsedDay == null) {
        _snack('Muat Naik Gagal: Hari "$rawDay" pada baris ${i + 1} tidak sah.', error: true);
        return;
      }

      // 3. Verify start time is earlier than end time
      final sm = _toMinutes(startTimeStr);
      final em = _toMinutes(endTimeStr);
      if (em <= sm) {
        _snack('Muat Naik Gagal: Masa mula mesti lebih awal daripada masa tamat pada baris ${i + 1}.', error: true);
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

      // 4. Prevent duplicate record
      final isDbDuplicate = _checkIsDuplicate(slot, existingSlots);
      if (isDbDuplicate) {
        _snack('Rekod jadual telah wujud.', error: true);
        return;
      }
      final isBatchDuplicate = _checkIsDuplicate(slot, batchSlots);
      if (isBatchDuplicate) {
        _snack('Rekod jadual telah wujud.', error: true);
        return;
      }

      // 5. Prevent time conflict for the same lecturer
      final dbConflict = _findLecturerConflict(slot, existingSlots);
      if (dbConflict != null) {
        _snack('Pertindihan Masa Dikesan.', error: true);
        return;
      }
      final batchConflict = _findLecturerConflict(slot, batchSlots);
      if (batchConflict != null) {
        _snack('Pertindihan Masa Dikesan.', error: true);
        return;
      }

      batchSlots.add(slot);
    }

    // If all pass validation, add them to DB!
    setState(() => _isUploading = true);
    int successfullyAdded = 0;
    for (final slot in batchSlots) {
      final err = await timetableCtrl.addSlot(slot);
      if (err == null) {
        successfullyAdded++;
      } else {
        _snack('Muat Naik Gagal: Ralat semasa menyimpan ke pangkalan data: $err', error: true);
        setState(() => _isUploading = false);
        return;
      }
    }
    setState(() {
      _isUploading = false;
      _selectedFile = null;
    });
    _snack('Muat Naik Berjaya: $successfullyAdded slot telah disimpan.');
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

  bool _checkIsDuplicate(TimetableSlotModel a, List<TimetableSlotModel> list) {
    return list.any((s) =>
        s.lecturerId == a.lecturerId &&
        s.courseId == a.courseId &&
        s.day == a.day &&
        s.startTime == a.startTime &&
        s.endTime == a.endTime);
  }

  TimetableSlotModel? _findLecturerConflict(TimetableSlotModel a, List<TimetableSlotModel> list) {
    for (final s in list) {
      if (s.id == a.id) continue;
      if (s.lecturerId != a.lecturerId) continue;
      if (s.day != a.day) continue;

      // Overlap: NOT (end1 <= start2 OR start1 >= end2)
      final hasOverlap = !(a.endTime.compareTo(s.startTime) <= 0 ||
          a.startTime.compareTo(s.endTime) >= 0);
      if (hasOverlap) return s;
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Muat Naik Jadual',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Format lajur wajib: course_code, course_name, day, start_time, end_time, venue, semester, academic_session',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 20),
          
          // File selector section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: [
                if (_selectedFile == null) ...[
                  Icon(Icons.upload_file_rounded, size: 48, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  const Text(
                    'Tiada fail dipilih',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: _pickFile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE5E7EB),
                      foregroundColor: const Color(0xFF374151),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Pilih Fail CSV', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ] else ...[
                  Icon(Icons.insert_drive_file_rounded, size: 48, color: const Color(0xFF8B1538)),
                  const SizedBox(height: 12),
                  Text(
                    _selectedFile!.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(_selectedFile!.size / 1024).toStringAsFixed(1)} KB',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Tukar Fail'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4B5563),
                          side: const BorderSide(color: Color(0xFFD1D5DB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      IconButton(
                        onPressed: _clearFile,
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                        tooltip: 'Padam',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Action button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (_isUploading || _selectedFile == null) ? null : _importCsv,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B1538), // MARA Maroon
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Muat Naik',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          
          const SizedBox(height: 10),
          Text(
            'Tip: Pastikan kod kursus wujud dalam Senarai Kursus.',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
          ),
        ],
      ),
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

class _ShowState extends State<ShowTimetableSlotView> {
  String? _selectedLecturerId;
  String? _selectedLecturerName;
  String _selectedDayFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TimetableController>().loadSlots();
      context.read<AdminController>().loadLecturers();
      context.read<CourseController>().loadCourses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lecturers = context.watch<AdminController>().lecturers;
    final courses = context.watch<CourseController>().courses;
    final timetableCtrl = context.watch<TimetableController>();

    final List<TimetableSlotModel> displaySlots;
    if (_selectedLecturerId != null) {
      displaySlots = timetableCtrl.slots
          .where((s) => s.lecturerId == _selectedLecturerId)
          .toList();
    } else {
      displaySlots = [];
    }

    return AdminShell(
      currentRoute: '/admin/jadual',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Jadual Waktu Pensyarah',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lihat keseluruhan jadual mingguan mengikut pensyarah.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
                const SizedBox(height: 24),

                // Controls row
                LayoutBuilder(builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 600;
                  final children = [
                    // Lecturer selector dropdown
                    SizedBox(
                      width: wide ? (constraints.maxWidth - 16) * 0.6 : double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Pilih Pensyarah'),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedLecturerId,
                            decoration: const InputDecoration(
                              hintText: 'Pilih pensyarah untuk dipaparkan',
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: lecturers.map((l) => DropdownMenuItem(
                              value: l.id,
                              child: Text(l.name),
                            )).toList(),
                            onChanged: (id) {
                              if (id != null) {
                                final l = lecturers.firstWhere((x) => x.id == id);
                                setState(() {
                                  _selectedLecturerId = id;
                                  _selectedLecturerName = l.name;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    if (!wide) const SizedBox(height: 16),
                    // Day filter dropdown
                    SizedBox(
                      width: wide ? (constraints.maxWidth - 16) * 0.4 : double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel('Tapis Hari'),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedDayFilter,
                            decoration: const InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'Semua', child: Text('Semua Hari')),
                              DropdownMenuItem(value: 'Isnin', child: Text('Isnin')),
                              DropdownMenuItem(value: 'Selasa', child: Text('Selasa')),
                              DropdownMenuItem(value: 'Rabu', child: Text('Rabu')),
                              DropdownMenuItem(value: 'Khamis', child: Text('Khamis')),
                              DropdownMenuItem(value: 'Jumaat', child: Text('Jumaat')),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _selectedDayFilter = v;
                                });
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ];

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: children,
                    );
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    );
                  }
                }),
              ],
            ),
          ),

          // Main schedule area
          Expanded(
            child: Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: timetableCtrl.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(Color(0xFF8B1538)),
                      ),
                    )
                  : _selectedLecturerId == null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today_rounded, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              const Text(
                                'Pilih Pensyarah',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Sila pilih pensyarah daripada senarai di atas untuk melihat jadual waktu mingguan.',
                                style: TextStyle(color: Color(0xFF6B7280), fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Paparan Mingguan: $_selectedLecturerName',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF111827),
                                    ),
                                  ),
                                  // Back button
                                  TextButton.icon(
                                    onPressed: () => context.go('/admin'),
                                    icon: const Icon(Icons.arrow_back_rounded, size: 16),
                                    label: const Text('Kembali'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: const Color(0xFF8B1538),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              JadualWaktuGrid(
                                slots: displaySlots,
                                courses: courses,
                                selectedDayFilter: _selectedDayFilter,
                              ),
                            ],
                          ),
                        ),
            ),
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

class JadualWaktuGrid extends StatelessWidget {
  final List<TimetableSlotModel> slots;
  final List<CourseModel> courses;
  final String selectedDayFilter; // 'Semua', 'Isnin', 'Selasa', 'Rabu', 'Khamis', 'Jumaat'

  const JadualWaktuGrid({
    super.key,
    required this.slots,
    required this.courses,
    required this.selectedDayFilter,
  });

  List<TimetableSlotModel> _getUniqueSlots(List<TimetableSlotModel> rawSlots) {
    final Set<String> seen = {};
    final List<TimetableSlotModel> unique = [];
    for (final s in rawSlots) {
      final key = '${s.lecturerId}_${s.courseId}_${s.day.name}_${s.startTime}_${s.endTime}';
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add(s);
      }
    }
    return unique;
  }

  @override
  Widget build(BuildContext context) {
    final uniqueSlots = _getUniqueSlots(slots);

    // Get unique sorted time intervals (e.g. "09:00 - 10:30")
    final uniqueKeys = uniqueSlots
        .map((s) => '${s.startTime}_${s.endTime}')
        .toSet()
        .toList()
      ..sort();
    final List<MapEntry<String, String>> intervals = uniqueKeys.map((key) {
      final parts = key.split('_');
      return MapEntry(parts[0], parts[1]);
    }).toList();

    if (uniqueSlots.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_busy_outlined, size: 64, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text(
                'Tiada Rekod Ditemui',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final daysToShow = <DayOfWeek>[];
    if (selectedDayFilter == 'Semua') {
      daysToShow.addAll([
        DayOfWeek.monday,
        DayOfWeek.tuesday,
        DayOfWeek.wednesday,
        DayOfWeek.thursday,
        DayOfWeek.friday,
      ]);
    } else {
      final day = _parseDay(selectedDayFilter);
      if (day != null) {
        daysToShow.add(day);
      }
    }

    const dayHeaders = {
      DayOfWeek.monday: 'Isnin',
      DayOfWeek.tuesday: 'Selasa',
      DayOfWeek.wednesday: 'Rabu',
      DayOfWeek.thursday: 'Khamis',
      DayOfWeek.friday: 'Jumaat',
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        constraints: const BoxConstraints(
          minWidth: 900,
        ),
        child: Table(
          border: TableBorder.all(
            color: const Color(0xFFE5E7EB),
            width: 1,
            borderRadius: BorderRadius.circular(8),
          ),
          columnWidths: {
            0: const FixedColumnWidth(120), // Time column
            for (int i = 0; i < daysToShow.length; i++)
              i + 1: const FlexColumnWidth(),
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // Header Row
            TableRow(
              decoration: const BoxDecoration(
                color: Color(0xFFF3F4F6),
              ),
              children: [
                const TableCell(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(
                      child: Text(
                        'Masa',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF374151),
                        ),
                      ),
                    ),
                  ),
                ),
                for (final d in daysToShow)
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Center(
                        child: Text(
                          dayHeaders[d]!,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF374151),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Data Rows
            for (final interval in intervals)
              TableRow(
                children: [
                  // Time Slot
                  TableCell(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Center(
                        child: Text(
                          '${interval.key} - ${interval.value}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4B5563),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Day Cells
                  for (final d in daysToShow)
                    TableCell(
                      child: _buildCellContent(context, uniqueSlots, d, interval.key, interval.value),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  DayOfWeek? _parseDay(String label) {
    if (label == 'Isnin') return DayOfWeek.monday;
    if (label == 'Selasa') return DayOfWeek.tuesday;
    if (label == 'Rabu') return DayOfWeek.wednesday;
    if (label == 'Khamis') return DayOfWeek.thursday;
    if (label == 'Jumaat') return DayOfWeek.friday;
    return null;
  }

  Widget _buildCellContent(BuildContext context, List<TimetableSlotModel> uniqueSlots, DayOfWeek day, String start, String end) {
    final matchingSlots = uniqueSlots
        .where((s) => s.day == day && s.startTime == start && s.endTime == end)
        .toList();

    if (matchingSlots.isEmpty) {
      return const SizedBox(
        height: 80,
        child: Center(
          child: Text(
            '-',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: matchingSlots.map((slot) {
        final course = courses.firstWhere(
          (c) => c.id == slot.courseId,
          orElse: () => CourseModel(
            id: '',
            code: slot.section.split('-').first,
            name: slot.subject,
            lecturerId: '',
            lecturerName: '',
            department: '',
            sections: 1,
          ),
        );

        final accentColor = _getAccentColor(slot.subject);

        return Container(
          margin: const EdgeInsets.all(6),
          padding: const EdgeInsets.all(10),
          width: double.infinity,
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accentColor.withOpacity(0.3), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.code,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                course.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on_outlined, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      slot.venue,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${slot.startTime} - ${slot.endTime}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _getAccentColor(String subject) {
    const colors = [
      Color(0xFF8B1538), // MARA Maroon
      Color(0xFF0D9488), // Teal
      Color(0xFF4F46E5), // Indigo
      Color(0xFFEA580C), // Orange
      Color(0xFF0891B2), // Cyan
    ];
    return colors[subject.length % colors.length];
  }
}