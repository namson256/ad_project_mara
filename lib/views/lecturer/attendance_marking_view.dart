import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/attendance_controller.dart';
import '../../models/attendance_model.dart';
import 'lecturer_shell.dart';

class AttendanceMarkingView extends StatelessWidget {
  const AttendanceMarkingView({super.key});

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
    final attendanceController = context.watch<AttendanceController>();
    final students = attendanceController.students;

    return LecturerShell(
      currentRoute: '/lecturer-attendance',
      child: SingleChildScrollView(
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
                        'Selasa, 26 Mei 2026',
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
                      child: const Text('Papan Pemuka'),
                    ),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Tanda Kehadiran'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Jadual Kehadiran 18 Minggu',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade900,
                            ),
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
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        showCheckboxColumn: false,
                        headingRowColor: WidgetStatePropertyAll(
                          Colors.indigo.shade50,
                        ),
                        columnSpacing: 14,
                        horizontalMargin: 16,
                        dataRowMinHeight: 62,
                        dataRowMaxHeight: 72,
                        columns: [
                          const DataColumn(label: Text('BIL')),
                          const DataColumn(label: Text('NAMA PELAJAR')),
                          for (var week = 1;
                              week <= AttendanceController.totalWeeks;
                              week++)
                            DataColumn(label: Text('M$week')),
                          const DataColumn(label: Text('% KEHADIRAN')),
                        ],
                        rows: [
                          for (var index = 0; index < students.length; index++)
                            _buildRow(
                              context,
                              attendanceController,
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
          ],
        ),
      ),
    );
  }

  DataRow _buildRow(
    BuildContext context,
    AttendanceController controller,
    AttendanceStudent student,
    int index,
  ) {
    final percentage = controller.attendancePercentage(student);

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
            SizedBox(
              width: 102,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<AttendanceStatus>(
                  value: student.weeklyStatus[week],
                  isDense: true,
                  isExpanded: true,
                  items: AttendanceStatus.values
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: _statusColor(status),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              status.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: _statusTextColor(status),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    context.read<AttendanceController>().updateStatus(
                          student.id,
                          week,
                          value,
                        );
                  },
                ),
              ),
            ),
          ),
        DataCell(
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
