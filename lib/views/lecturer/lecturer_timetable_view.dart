import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/timetable_controller.dart';
import '../../controllers/course_controller.dart';
import '../../models/timetable_slot_model.dart';
import 'lecturer_shell.dart';

class LecturerTimetableView extends StatefulWidget {
  const LecturerTimetableView({super.key});

  @override
  State<LecturerTimetableView> createState() => _LecturerTimetableState();
}

class _LecturerTimetableState extends State<LecturerTimetableView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();

  String _query = '';
  String? _selectedCourseId;
  String _selectedSemester = 'Semua';
  String _selectedSession = 'Semua';

  static const _dayLabels = ['Isnin', 'Selasa', 'Rabu', 'Khamis', 'Jumaat'];

  int get _todayIndex {
    final wd = DateTime.now().weekday;
    return (wd >= 1 && wd <= 5) ? wd - 1 : 0;
  }

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(
      length: DayOfWeek.values.length,
      vsync: this,
      initialIndex: _todayIndex,
    );
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
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<TimetableSlotModel> _getFilteredSlots(
    List<TimetableSlotModel> slots,
    DayOfWeek day,
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

    // 2. Filter by day
    list = list.where((s) => s.day == day).toList();

    // 3. Filter by search query
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      list = list.where((s) =>
          s.subject.toLowerCase().contains(q) ||
          s.venue.toLowerCase().contains(q) ||
          s.section.toLowerCase().contains(q)).toList();
    }

    // 4. Filter by course
    if (_selectedCourseId != null) {
      list = list.where((s) => s.courseId == _selectedCourseId).toList();
    }

    // 5. Filter by semester
    if (_selectedSemester != 'Semua') {
      list = list.where((s) => s.semester == _selectedSemester).toList();
    }

    // 6. Filter by session
    if (_selectedSession != 'Semua') {
      list = list.where((s) => s.session == _selectedSession).toList();
    }

    // Sort by start time
    return list..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  void _resetFilters() {
    setState(() {
      _searchCtrl.clear();
      _selectedCourseId = null;
      _selectedSemester = 'Semua';
      _selectedSession = 'Semua';
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
                          'Slot Jadual Waktu Saya',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Urus dan semak semua jadual waktu pengajaran anda.',
                          style: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                        ),
                      ],
                    ),
                    if (_query.isNotEmpty ||
                        _selectedCourseId != null ||
                        _selectedSemester != 'Semua' ||
                        _selectedSession != 'Semua')
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
                  final wide = constraints.maxWidth >= 900;
                  final filters = [
                    // Search text field
                    SizedBox(
                      width: wide ? 280 : double.infinity,
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: _filterInputDec(
                          'Cari bilik, subjek, seksyen...',
                          prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                          suffixIcon: _query.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18),
                                  onPressed: () => _searchCtrl.clear())
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10, height: 10),

                    // Course filter dropdown
                    SizedBox(
                      width: wide ? 220 : double.infinity,
                      child: DropdownButtonFormField<String?>(
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
                    const SizedBox(width: 10, height: 10),

                    // Semester filter dropdown
                    SizedBox(
                      width: wide ? 150 : double.infinity,
                      child: DropdownButtonFormField<String>(
                        value: _selectedSemester,
                        decoration: _filterInputDec('Semester'),
                        items: const [
                          DropdownMenuItem(value: 'Semua', child: Text('Semua Sem')),
                          DropdownMenuItem(value: 'Semester 1', child: Text('Semester 1')),
                          DropdownMenuItem(value: 'Semester 2', child: Text('Semester 2')),
                          DropdownMenuItem(value: 'Semester 3', child: Text('Semester 3')),
                        ],
                        onChanged: (v) => setState(() => _selectedSemester = v!),
                      ),
                    ),
                    const SizedBox(width: 10, height: 10),

                    // Session filter dropdown
                    SizedBox(
                      width: wide ? 150 : double.infinity,
                      child: DropdownButtonFormField<String>(
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
                  ];

                  if (wide) {
                    return Row(children: filters..removeWhere((w) => w is SizedBox && w.width == null && w.height != null));
                  } else {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: filters..removeWhere((w) => w is SizedBox && w.width != null && w.height == null),
                    );
                  }
                }),
                const SizedBox(height: 18),
              ],
            ),
          ),

          // ── Day TabBar ──────────────────────────────────────────────
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
              labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              tabs: List.generate(DayOfWeek.values.length, (i) {
                final isToday = i == _todayIndex;
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_dayLabels[i]),
                      if (isToday) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B1538),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'HARI INI',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ),
          ),

          // ── Tab Contents ─────────────────────────────────────────────
          Expanded(
            child: timetableCtrl.isLoading
                ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B1538))))
                : TabBarView(
                    controller: _tabCtrl,
                    children: DayOfWeek.values.map((day) {
                      final slots = _getFilteredSlots(timetableCtrl.slots, day, lecturerName, lecturerId);
                      if (slots.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.event_busy_outlined, size: 60, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                _query.isNotEmpty ||
                                        _selectedCourseId != null ||
                                        _selectedSemester != 'Semua' ||
                                        _selectedSession != 'Semua'
                                    ? 'Tiada hasil ditemui untuk penapis ini'
                                    : 'Tiada kelas dijadualkan pada hari ini.',
                                style: TextStyle(color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(24),
                        itemCount: slots.length,
                        itemBuilder: (_, i) => _LecturerSlotCard(slot: slots[i]),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _LecturerSlotCard extends StatelessWidget {
  final TimetableSlotModel slot;
  const _LecturerSlotCard({required this.slot});

  Color get _accent {
    const colors = [
      Color(0xFF8B1538), // MARA Maroon
      Color(0xFF0D9488), // Teal
      Color(0xFF4F46E5), // Indigo
      Color(0xFFEA580C), // Orange
      Color(0xFF0891B2), // Cyan
    ];
    return colors[slot.subject.length % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      color: Colors.white,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: _accent,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            slot.subject,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1F2937)),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _accent.withOpacity(0.3)),
                          ),
                          child: Text(
                            slot.section,
                            style: TextStyle(fontSize: 11, color: _accent, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        _LecturerTag(Icons.access_time_rounded, '${slot.startTime} – ${slot.endTime}'),
                        _LecturerTag(Icons.location_on_outlined, slot.venue),
                        _LecturerTag(Icons.school_outlined, '${slot.semester} (${slot.session})'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LecturerTag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _LecturerTag(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: Colors.grey[500]),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(fontSize: 13, color: Colors.grey[700], fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
