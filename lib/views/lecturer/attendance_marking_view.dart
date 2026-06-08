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

class _AttendanceMarkingViewState extends State<AttendanceMarkingView> {
  CourseModel? _selectedCourse;

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

  @override
  Widget build(BuildContext context) {
    final attendanceController = context.watch<AttendanceController>();
    final courseController = context.watch<CourseController>();
    final courses = courseController.courses;

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

    return LecturerShell(
      currentRoute: '/lecturer-attendance',
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rekod Kehadiran',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Semester 25/26',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton(
                      onPressed: () => context.go('/lecturer-dashboard'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF111827),
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Kembali'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            Expanded(
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Course selection dropdown ──
                    Row(
                      children: [
                        Icon(Icons.menu_book_rounded, color: Colors.indigo.shade400, size: 22),
                        const SizedBox(width: 12),
                        Text(
                          'Kursus:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              if (courseController.isLoading) {
                                return const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                );
                              }
                              return PopupMenuButton<String>(
                                  onSelected: (value) {
                                    setState(() {
                                      _selectedCourse = courses.firstWhere(
                                        (c) => c.id == value,
                                      );
                                    });
                                  },
                                  offset: const Offset(0, 48),
                                  constraints: BoxConstraints(
                                    minWidth: constraints.maxWidth,
                                    maxWidth: constraints.maxWidth,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  itemBuilder: (context) => courses.map((course) {
                                    return PopupMenuItem<String>(
                                      value: course.id,
                                      child: Text(
                                        '${course.code} — ${course.name}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    );
                                  }).toList(),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.grey.shade300),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedCourse != null
                                                ? '${_selectedCourse!.code} — ${_selectedCourse!.name}'
                                                : 'Pilih kursus',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: _selectedCourse != null
                                                  ? Colors.black87
                                                  : Colors.grey.shade500,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Icon(Icons.keyboard_arrow_down_rounded,
                                            color: Colors.grey.shade600),
                                      ],
                                    ),
                                  ),
                                );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // ── Table header ──
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Jadual Kehadiran 18 Minggu',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              if (_selectedCourse != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${_selectedCourse!.code} — ${_selectedCourse!.name}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.indigo.shade400,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          'Semua status bermula sebagai Hadir',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: DataTable2(
                        minWidth: 2400,
                        showCheckboxColumn: false,
                        headingRowColor: WidgetStatePropertyAll(
                          Colors.indigo.shade50,
                        ),
                        columnSpacing: 14,
                        horizontalMargin: 16,
                        dataRowHeight: 66,
                        headingRowHeight: 56,
                        columns: [
                          const DataColumn2(label: Text('BIL'), fixedWidth: 50),
                          const DataColumn2(label: Text('NAMA PELAJAR'), fixedWidth: 320),
                          for (var week = 1;
                              week <= AttendanceController.totalWeeks;
                              week++)
                            DataColumn2(label: Text('M$week'), fixedWidth: 102),
                          const DataColumn2(label: Text('% KEHADIRAN'), fixedWidth: 100),
                        ],
                        rows: [
                          for (var index = 0; index < students.length; index++)
                            _buildRow(
                              context,
                              _selectedCourse!.id,
                              students[index],
                              index,
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
    );
  }

  DataRow _buildRow(
    BuildContext context,
    String courseId,
    AttendanceStudent student,
    int index,
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
// Isolated cell widget — only rebuilds when its own value changes
// ─────────────────────────────────────────────────────────────
class _AttendanceCell extends StatelessWidget {
  final String courseId;
  final String studentId;
  final int week;

  const _AttendanceCell({
    required this.courseId,
    required this.studentId,
    required this.week,
  });

  Color _statusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.hadir:      return const Color(0xFFE8F5E9);
      case AttendanceStatus.lewat:      return const Color(0xFFFFF8E1);
      case AttendanceStatus.tidakHadir: return const Color(0xFFFFEBEE);
      case AttendanceStatus.mc:         return const Color(0xFFE3F2FD);
      case AttendanceStatus.ck:         return const Color(0xFFF3E5F5);
    }
  }

  Color _statusTextColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.hadir:      return const Color(0xFF2E7D32);
      case AttendanceStatus.lewat:      return const Color(0xFFF9A825);
      case AttendanceStatus.tidakHadir: return const Color(0xFFC62828);
      case AttendanceStatus.mc:         return const Color(0xFF1565C0);
      case AttendanceStatus.ck:         return const Color(0xFF6A1B9A);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Only listens to this specific course/student/week value
    final status = context.select<AttendanceController, AttendanceStatus>(
      (ctrl) {
        final list = ctrl.studentsForCourse(courseId);
        final student = list.firstWhere((s) => s.id == studentId,
            orElse: () => AttendanceStudent(id: studentId, name: ''));
        return student.weeklyStatus[week] ?? AttendanceStatus.hadir;
      },
    );

    return SizedBox(
      width: 102,
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
                      borderRadius: BorderRadius.circular(8),
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
