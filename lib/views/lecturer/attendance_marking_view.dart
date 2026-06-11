import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../controllers/attendance_controller.dart';
import '../../controllers/course_controller.dart';
import '../../models/attendance_model.dart';
import '../../models/course_model.dart';
import 'lecturer_shell.dart';

class AttendanceMarkingView extends StatefulWidget {
  const AttendanceMarkingView({super.key});

  @override
  State<AttendanceMarkingView> createState() => _AttendanceMarkingViewState();
}

class _AttendanceMarkingViewState extends State<AttendanceMarkingView>
    with SingleTickerProviderStateMixin {
  CourseModel? _selectedCourse;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _statusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.hadir:
        return const Color(0xFFE8F5E9);
      case AttendanceStatus.lewat:
        return const Color(0xFFFFF8E1);
      case AttendanceStatus.tidakHadir:
        return const Color(0xFFFFEBEE);
      case AttendanceStatus.mc:
        return const Color(0xFFE3F2FD);
      case AttendanceStatus.ck:
        return const Color(0xFFF3E5F5);
    }
  }

  Color _statusTextColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.hadir:
        return const Color(0xFF2E7D32);
      case AttendanceStatus.lewat:
        return const Color(0xFFF9A825);
      case AttendanceStatus.tidakHadir:
        return const Color(0xFFC62828);
      case AttendanceStatus.mc:
        return const Color(0xFF1565C0);
      case AttendanceStatus.ck:
        return const Color(0xFF6A1B9A);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Auto-select first course as soon as courses are loaded
    if (_selectedCourse == null) {
      final courses = context.read<CourseController>().courses;
      if (courses.isNotEmpty) {
        _selectedCourse = courses.first;
      }
    }
  }

  /// Builds a full-screen loading overlay with animated content
  Widget _buildLoadingOverlay() {
    return Container(
      color: const Color(0xFFF5F7FA),
      child: Center(
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.4, end: 1.0).animate(
            CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.12),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Center(
                  child: SizedBox(
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 3.5,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF8B1538)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Memuatkan rekod kehadiran...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF4B5563),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sila tunggu sebentar',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final attendanceController = context.watch<AttendanceController>();
    final courseController = context.watch<CourseController>();
    final courses = courseController.courses;
    final currentWeek = AttendanceController.currentWeek;

    // Auto-select first course if not yet set (handles late load)
    if (_selectedCourse == null && courses.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _selectedCourse == null) {
          setState(() => _selectedCourse = courses.first);
        }
      });
    }

    final students = _selectedCourse != null
        ? attendanceController.studentsForCourse(_selectedCourse!.id)
        : <AttendanceStudent>[];

    // Show loading overlay when either courses or attendance data is loading
    final isLoading =
        courseController.isLoading || attendanceController.isLoading;

    return LecturerShell(
      currentRoute: '/lecturer-attendance',
      child: Stack(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Compact header: title + badge + legend + back button ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Rekod Kehadiran',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDE8ED),
                        borderRadius: BorderRadius.circular(4),
                        border:
                            Border.all(color: const Color(0xFFC7D2FE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 11, color: Color(0xFF8B1538)),
                          const SizedBox(width: 4),
                          Text(
                            'M$currentWeek',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF8B1538),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _LegendChip(
                      color: const Color(0xFFE0E7FF),
                      borderColor: const Color(0xFF818CF8),
                      label: 'Boleh edit',
                    ),
                    const SizedBox(width: 10),
                    _LegendChip(
                      color: const Color(0xFFF3F4F6),
                      borderColor: const Color(0xFFD1D5DB),
                      label: 'Terkunci',
                      icon: Icons.lock_outline,
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () => context.go('/lecturer-dashboard'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF111827),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text('Kembali', style: TextStyle(fontSize: 13)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Card with course selector + table ──
                Expanded(
                  child: Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Inline course selector ──
                          Row(
                            children: [
                              Icon(Icons.menu_book_rounded,
                                  color: Colors.indigo.shade400, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Kursus:',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (courseController.isLoading) {
                                      return const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      );
                                    }
                                    return PopupMenuButton<String>(
                                      onSelected: (value) {
                                        setState(() {
                                          _selectedCourse =
                                              courses.firstWhere(
                                            (c) => c.id == value,
                                          );
                                        });
                                      },
                                      offset: const Offset(0, 40),
                                      constraints: BoxConstraints(
                                        minWidth: constraints.maxWidth,
                                        maxWidth: constraints.maxWidth,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      itemBuilder: (context) =>
                                          courses.map((course) {
                                        return PopupMenuItem<String>(
                                          value: course.id,
                                          child: Text(
                                            '${course.code} — ${course.name}',
                                            style: const TextStyle(
                                                fontSize: 13),
                                          ),
                                        );
                                      }).toList(),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                              color: Colors.grey.shade300),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _selectedCourse != null
                                                    ? '${_selectedCourse!.code} — ${_selectedCourse!.name}'
                                                    : 'Pilih kursus',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color:
                                                      _selectedCourse != null
                                                          ? Colors.black87
                                                          : Colors
                                                              .grey.shade500,
                                                ),
                                                overflow:
                                                    TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Icon(
                                                Icons
                                                    .keyboard_arrow_down_rounded,
                                                color:
                                                    Colors.grey.shade600,
                                                size: 20),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // ── Table ──
                          Expanded(
                            child: DataTable2(
                              fixedLeftColumns: 2,
                              minWidth: 2400,
                              showCheckboxColumn: false,
                              headingRowColor: WidgetStatePropertyAll(
                                Colors.indigo.shade50,
                              ),
                              columnSpacing: 14,
                              horizontalMargin: 14,
                              dataRowHeight: 50,
                              headingRowHeight: 44,
                              columns: [
                                const DataColumn2(
                                    label: Text('BIL'), fixedWidth: 50),
                                const DataColumn2(
                                    label: Text('NAMA PELAJAR'),
                                    fixedWidth: 320),
                                for (var week = 1;
                                    week <=
                                        AttendanceController.totalWeeks;
                                    week++)
                                  DataColumn2(
                                    label: _WeekColumnHeader(
                                      week: week,
                                      currentWeek: currentWeek,
                                    ),
                                    fixedWidth: 102,
                                  ),
                                const DataColumn2(
                                    label: Text('% KEHADIRAN'),
                                    fixedWidth: 100),
                              ],
                              rows: [
                                for (var index = 0;
                                    index < students.length;
                                    index++)
                                  _buildRow(
                                    context,
                                    _selectedCourse!.id,
                                    students[index],
                                    index,
                                    currentWeek,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Loading overlay
          if (isLoading) _buildLoadingOverlay(),
        ],
      ),
    );
  }

  DataRow _buildRow(
    BuildContext context,
    String courseId,
    AttendanceStudent student,
    int index,
    int currentWeek,
  ) {
    return DataRow(
      cells: [
        DataCell(Text('${index + 1}')),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(
              student.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        for (var week = 1; week <= AttendanceController.totalWeeks; week++)
          DataCell(
            _AttendanceCell(
              courseId: courseId,
              studentId: student.id,
              week: week,
              currentWeek: currentWeek,
            ),
          ),
        // Percentage — only rebuilds when this student's data changes
        DataCell(
          Selector<AttendanceController, double>(
            selector: (_, ctrl) {
              final list = ctrl.studentsForCourse(courseId);
              final s = list.firstWhere((s) => s.id == student.id,
                  orElse: () => student);
              return ctrl.attendancePercentage(s);
            },
            builder: (_, percentage, __) => Text(
              '${percentage.toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Week column header — highlights current week
// ─────────────────────────────────────────────────────────────
class _WeekColumnHeader extends StatelessWidget {
  final int week;
  final int currentWeek;

  const _WeekColumnHeader({required this.week, required this.currentWeek});

  @override
  Widget build(BuildContext context) {
    final isCurrent = week == currentWeek;
    final isPast = week < currentWeek;

    if (isCurrent) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF8B1538),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'M$week',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.edit, color: Colors.white70, size: 11),
          ],
        ),
      );
    }

    if (isPast) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'M$week',
            style: TextStyle(
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(width: 3),
          Icon(Icons.lock_outline, color: Colors.grey.shade400, size: 11),
        ],
      );
    }

    // Future weeks
    return Text(
      'M$week',
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Legend chip for the week indicators
// ─────────────────────────────────────────────────────────────
class _LegendChip extends StatelessWidget {
  final Color color;
  final Color borderColor;
  final String label;
  final IconData? icon;

  const _LegendChip({
    required this.color,
    required this.borderColor,
    required this.label,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: icon != null
              ? Icon(icon, size: 9, color: Colors.grey.shade600)
              : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Isolated cell widget — only rebuilds when its own value changes
// Past weeks: read-only chip with lock styling
// Current week: editable dropdown with highlighted background
// Future weeks: normal editable dropdown
// ─────────────────────────────────────────────────────────────
class _AttendanceCell extends StatelessWidget {
  final String courseId;
  final String studentId;
  final int week;
  final int currentWeek;

  const _AttendanceCell({
    required this.courseId,
    required this.studentId,
    required this.week,
    required this.currentWeek,
  });

  Color _statusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.hadir:
        return const Color(0xFFE8F5E9);
      case AttendanceStatus.lewat:
        return const Color(0xFFFFF8E1);
      case AttendanceStatus.tidakHadir:
        return const Color(0xFFFFEBEE);
      case AttendanceStatus.mc:
        return const Color(0xFFE3F2FD);
      case AttendanceStatus.ck:
        return const Color(0xFFF3E5F5);
    }
  }

  Color _statusTextColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.hadir:
        return const Color(0xFF2E7D32);
      case AttendanceStatus.lewat:
        return const Color(0xFFF9A825);
      case AttendanceStatus.tidakHadir:
        return const Color(0xFFC62828);
      case AttendanceStatus.mc:
        return const Color(0xFF1565C0);
      case AttendanceStatus.ck:
        return const Color(0xFF6A1B9A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPast = week < currentWeek;
    final isCurrent = week == currentWeek;

    // Only listens to this specific course/student/week value
    final status = context.select<AttendanceController, AttendanceStatus>(
      (ctrl) {
        final list = ctrl.studentsForCourse(courseId);
        final student = list.firstWhere((s) => s.id == studentId,
            orElse: () => AttendanceStudent(id: studentId, name: ''));
        return student.weeklyStatus[week] ?? AttendanceStatus.hadir;
      },
    );

    // ── Past week: read-only chip ──
    if (isPast) {
      return Opacity(
        opacity: 0.65,
        child: Container(
          width: 102,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: _statusColor(status).withOpacity(0.5),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  status.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusTextColor(status).withOpacity(0.7),
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Icon(Icons.lock_outline, size: 10, color: Colors.grey.shade500),
            ],
          ),
        ),
      );
    }

    // ── Current week: editable with highlighted border ──
    return Container(
      width: 102,
      decoration: isCurrent
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF818CF8), width: 2),
              color: const Color(0xFFFDE8ED),
            )
          : null,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AttendanceStatus>(
          value: status,
          isDense: true,
          isExpanded: true,
          items: AttendanceStatus.values
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: _statusColor(s),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      s.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusTextColor(s),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            context.read<AttendanceController>().updateStatus(
                  courseId,
                  studentId,
                  week,
                  value,
                );
          },
        ),
      ),
    );
  }
}
