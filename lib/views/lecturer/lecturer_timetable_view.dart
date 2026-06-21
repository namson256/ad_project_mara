import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/timetable_controller.dart';
import '../../controllers/course_controller.dart';
import '../../models/timetable_slot_model.dart';
import '../timetable_views.dart';
import 'lecturer_shell.dart';

class LecturerTimetableView extends StatefulWidget {
  const LecturerTimetableView({super.key});

  @override
  State<LecturerTimetableView> createState() => _LecturerTimetableState();
}

class _LecturerTimetableState extends State<LecturerTimetableView> {
  final _searchCtrl = TextEditingController();

  String _query = '';
  String? _selectedCourseId;
  String _selectedSemester = 'Semua';
  String _selectedSession = 'Semua';
  String _selectedDayFilter = 'Semua';

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      setState(() {
        _query = _searchCtrl.text;
      });
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TimetableController>().loadSlots();
      context.read<CourseController>().loadCourses();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TimetableSlotModel> _getLecturerSlots(
    List<TimetableSlotModel> slots,
    String currentLecturerName,
    String currentLecturerId,
  ) {
    // 1. Filter by assigned lecturer (by ID or Name fallback)
    var list = slots.where((s) {
      final matchId = currentLecturerId.isNotEmpty && s.lecturerId == currentLecturerId;
      final matchName = currentLecturerName.isNotEmpty &&
          s.lecturerName.trim().toLowerCase() == currentLecturerName.trim().toLowerCase();
      return matchId || matchName;
    }).toList();

    // 2. Filter by search query
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((s) =>
          s.subject.toLowerCase().contains(q) ||
          s.venue.toLowerCase().contains(q) ||
          s.section.toLowerCase().contains(q)).toList();
    }

    // 3. Filter by course
    if (_selectedCourseId != null) {
      list = list.where((s) => s.courseId == _selectedCourseId).toList();
    }

    // 4. Filter by semester
    if (_selectedSemester != 'Semua') {
      list = list.where((s) => s.semester == _selectedSemester).toList();
    }

    // 5. Filter by session
    if (_selectedSession != 'Semua') {
      list = list.where((s) => s.session == _selectedSession).toList();
    }

    return list;
  }

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _selectedCourseId = null;
      _selectedSemester = 'Semua';
      _selectedSession = 'Semua';
      _selectedDayFilter = 'Semua';
    });
  }

  InputDecoration _filterInputDec(String hintText, {Widget? suffixIcon, Widget? prefixIcon}) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF8B1538), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final lecturerName = user?.name ?? '';
    final lecturerId = user?.id ?? '';

    final timetableCtrl = context.watch<TimetableController>();
    final courseCtrl = context.watch<CourseController>();

    final courses = courseCtrl.courses;

    return LecturerShell(
      currentRoute: '/lecturer-timetable',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header & Title ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Jadual Waktu Pensyarah',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Semak semua jadual waktu pengajaran anda.',
                          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                        ),
                      ],
                    ),
                    if (_query.isNotEmpty ||
                        _selectedCourseId != null ||
                        _selectedSemester != 'Semua' ||
                        _selectedSession != 'Semua' ||
                        _selectedDayFilter != 'Semua')
                      OutlinedButton.icon(
                        onPressed: _resetFilters,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Set Semula Penapis'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF8B1538),
                          side: const BorderSide(color: Color(0xFF8B1538)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Filters Controls Row ──────────────────────────────────────
                LayoutBuilder(builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final searchWidth = isMobile ? double.infinity : 220.0;
                  final courseWidth = isMobile ? double.infinity : 220.0;
                  final semWidth = isMobile ? double.infinity : 150.0;
                  final sesWidth = isMobile ? double.infinity : 150.0;
                  final dayWidth = isMobile ? double.infinity : 150.0;

                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.start,
                    children: [
                      // Search text field
                      SizedBox(
                        width: searchWidth,
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: _filterInputDec(
                            'Cari bilik, subjek...',
                            prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                            suffixIcon: _query.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded, size: 18),
                                    onPressed: () => _searchCtrl.clear())
                                : null,
                          ),
                        ),
                      ),

                      // Course filter dropdown
                      SizedBox(
                        width: courseWidth,
                        child: DropdownButtonFormField<String?>(
                          isExpanded: true,
                          value: _selectedCourseId,
                          decoration: _filterInputDec('Semua Kursus'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Semua Kursus', style: TextStyle(color: Colors.grey)),
                            ),
                            ...courses.map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text('${c.code} – ${c.name}', overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (v) => setState(() => _selectedCourseId = v),
                        ),
                      ),

                      // Semester filter dropdown
                      SizedBox(
                        width: semWidth,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedSemester,
                          decoration: _filterInputDec('Semester'),
                          items: const [
                            DropdownMenuItem(value: 'Semua', child: Text('Semua Semester')),
                            DropdownMenuItem(value: 'Semester 1', child: Text('Semester 1')),
                            DropdownMenuItem(value: 'Semester 2', child: Text('Semester 2')),
                            DropdownMenuItem(value: 'Semester 3', child: Text('Semester 3')),
                          ],
                          onChanged: (v) => setState(() => _selectedSemester = v!),
                        ),
                      ),

                      // Session filter dropdown
                      SizedBox(
                        width: sesWidth,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedSession,
                          decoration: _filterInputDec('Sesi'),
                          items: const [
                            DropdownMenuItem(value: 'Semua', child: Text('Semua Sesi')),
                            DropdownMenuItem(value: '2025/2026', child: Text('2025/2026')),
                            DropdownMenuItem(value: '2026/2027', child: Text('2026/2027')),
                            DropdownMenuItem(value: '2027/2028', child: Text('2027/2028')),
                          ],
                          onChanged: (v) => setState(() => _selectedSession = v!),
                        ),
                      ),

                      // Day filter dropdown
                      SizedBox(
                        width: dayWidth,
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedDayFilter,
                          decoration: _filterInputDec('Tapis Hari'),
                          items: const [
                            DropdownMenuItem(value: 'Semua', child: Text('Semua Hari')),
                            DropdownMenuItem(value: 'Isnin', child: Text('Isnin')),
                            DropdownMenuItem(value: 'Selasa', child: Text('Selasa')),
                            DropdownMenuItem(value: 'Rabu', child: Text('Rabu')),
                            DropdownMenuItem(value: 'Khamis', child: Text('Khamis')),
                            DropdownMenuItem(value: 'Jumaat', child: Text('Jumaat')),
                          ],
                          onChanged: (v) => setState(() => _selectedDayFilter = v!),
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: 18),
              ],
            ),
          ),

          // ── Weekly Schedule Table Grid ──────────────────────────────────
          Expanded(
            child: Container(
              color: Colors.white,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
              child: timetableCtrl.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B1538)),
                      ),
                    )
                  : SingleChildScrollView(
                      child: JadualWaktuGrid(
                        slots: _getLecturerSlots(timetableCtrl.slots, lecturerName, lecturerId),
                        courses: courses,
                        selectedDayFilter: _selectedDayFilter,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
