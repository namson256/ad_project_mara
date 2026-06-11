import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/admin_controller.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/discipline_controller.dart';
import '../../controllers/attendance_controller.dart';
import '../../controllers/timetable_controller.dart';
import '../../models/attendance_model.dart';
import 'ketua_shell.dart';

class KetuaDashboardView extends StatelessWidget {
  const KetuaDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth       = context.watch<AuthController>();
    final admin      = context.watch<AdminController>();
    final courses    = context.watch<CourseController>();
    final discipline = context.watch<DisciplineController>();
    final attendance = context.watch<AttendanceController>();
    final timetable  = context.watch<TimetableController>();

    final user = auth.currentUser;

    // ── Derived stats ────────────────────────────────────────────────
    final totalPensyarah  = admin.lecturers.length;
    final totalKursus     = courses.courses.length;
    const totalPelajar    = 19; // hardcoded cohort in AttendanceController
    final totalSlot       = timetable.slots.length;

    final combined = discipline.getCombinedRecords(
        courses.courses, attendance);
    final openCases = combined
        .where((r) => r.status == 'Belum Selesai')
        .length;
    final resolvedCases = combined
        .where((r) => r.status == 'Selesai')
        .length;
    final totalCases = combined
        .where((r) => r.status != 'Dipadam')
        .length;

    // attendance rate across all loaded courses
    double avgAttendance = 0;
    int studentCount = 0;
    for (final course in courses.courses) {
      final students = attendance.studentsForCourse(course.id);
      for (final s in students) {
        final total = s.weeklyStatus.length;
        if (total == 0) continue;
        final present = s.weeklyStatus.values
            .where((st) =>
                st == AttendanceStatus.hadir ||
                st == AttendanceStatus.lewat)
            .length;
        avgAttendance += present / total;
        studentCount++;
      }
    }
    final attendanceRate = studentCount > 0
        ? (avgAttendance / studentCount * 100).toStringAsFixed(1)
        : '--';

    return KetuaShell(
      currentRoute: '/ketua-dashboard',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Header ─────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Selamat Datang, ${user?.name ?? 'Ketua Program'}',
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ringkasan keseluruhan program — paparan baca sahaja.',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFDE8ED),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFFDA4AF)),
                  ),
                  child: const Text('Ketua Program',
                      style: TextStyle(
                          color: Color(0xFF8B1538),
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ),
              ],
            ),

            const SizedBox(height: 28),

            // ── Row 1: Pelajar · Pensyarah · Kursus · Slot ─────────────
            LayoutBuilder(builder: (_, constraints) {
              final wide = constraints.maxWidth >= 680;
              final row1 = [
                _StatCard(
                  label: 'JUMLAH PELAJAR',
                  value: '$totalPelajar',
                  icon: Icons.groups_outlined,
                  color: const Color(0xFF8B1538),
                  bg: const Color(0xFFFDE8ED),
                ),
                _StatCard(
                  label: 'JUMLAH PENSYARAH',
                  value: '$totalPensyarah',
                  icon: Icons.school_outlined,
                  color: const Color(0xFF0891B2),
                  bg: const Color(0xFFE0F2FE),
                ),
                _StatCard(
                  label: 'JUMLAH KURSUS',
                  value: '$totalKursus',
                  icon: Icons.menu_book_outlined,
                  color: const Color(0xFF059669),
                  bg: const Color(0xFFD1FAE5),
                ),
                _StatCard(
                  label: 'SLOT JADUAL',
                  value: '$totalSlot',
                  icon: Icons.calendar_month_outlined,
                  color: const Color(0xFFD97706),
                  bg: const Color(0xFFFEF3C7),
                ),
              ];
              return wide
                  ? Row(
                      children: row1
                          .map((c) => Expanded(
                              child: Padding(
                                  padding: const EdgeInsets.only(right: 14),
                                  child: c)))
                          .toList(),
                    )
                  : Column(
                      children: row1
                          .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: c))
                          .toList(),
                    );
            }),

            const SizedBox(height: 16),

            // ── Row 2: Disiplin · Kadar Hadir ──────────────────────────
            LayoutBuilder(builder: (_, constraints) {
              final wide = constraints.maxWidth >= 680;
              final row2 = [
                _StatCard(
                  label: 'KES DISIPLIN TERBUKA',
                  value: '$openCases',
                  icon: Icons.warning_amber_outlined,
                  color: const Color(0xFFDC2626),
                  bg: const Color(0xFFFEE2E2),
                  subtitle: '$totalCases jumlah kes · $resolvedCases selesai',
                ),
                _StatCard(
                  label: 'KES DISIPLIN SELESAI',
                  value: '$resolvedCases',
                  icon: Icons.check_circle_outline,
                  color: const Color(0xFF059669),
                  bg: const Color(0xFFD1FAE5),
                  subtitle: 'daripada $totalCases jumlah kes',
                ),
                _StatCard(
                  label: 'KADAR KEHADIRAN PURATA',
                  value: studentCount > 0 ? '$attendanceRate%' : '--',
                  icon: Icons.how_to_reg_outlined,
                  color: const Color(0xFF7C3AED),
                  bg: const Color(0xFFEDE9FE),
                  subtitle: studentCount > 0
                      ? 'merentasi ${courses.courses.length} kursus'
                      : 'tiada data lagi',
                ),
              ];
              return wide
                  ? Row(
                      children: row2
                          .map((c) => Expanded(
                              child: Padding(
                                  padding: const EdgeInsets.only(right: 14),
                                  child: c)))
                          .toList(),
                    )
                  : Column(
                      children: row2
                          .map((c) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: c))
                          .toList(),
                    );
            }),

            const SizedBox(height: 28),

            // ── Senarai Kursus ──────────────────────────────────────────
            _SectionCard(
              title: 'Senarai Kursus Aktif',
              icon: Icons.menu_book_outlined,
              child: courses.isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : courses.courses.isEmpty
                      ? _EmptyHint('Tiada kursus didaftarkan lagi.')
                      : Column(
                          children: courses.courses.map((c) {
                            return _ListRow(
                              leading: Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFDE8ED),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.menu_book_outlined,
                                    color: Color(0xFF8B1538), size: 18),
                              ),
                              title: c.name,
                              subtitle: '${c.code}  ·  ${c.lecturerName}',
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(c.department,
                                    style: const TextStyle(
                                        color: Color(0xFF059669),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ),
                            );
                          }).toList(),
                        ),
            ),

            const SizedBox(height: 20),

            // ── Kes Disiplin Terbaru ────────────────────────────────────
            _SectionCard(
              title: 'Kes Disiplin Terbaru',
              icon: Icons.warning_amber_outlined,
              actionLabel: 'Lihat Semua →',
              onAction: () => context.go('/ketua-isu-disiplin'),
              child: discipline.isLoading
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : combined.isEmpty
                      ? _EmptyHint('Tiada kes disiplin direkodkan.')
                      : Column(
                          children: combined
                              .where((r) => r.status != 'Dipadam')
                              .take(5)
                              .map((r) {
                            final isOpen = r.status == 'Belum Selesai';
                            return _ListRow(
                              leading: Container(
                                width: 38, height: 38,
                                decoration: BoxDecoration(
                                  color: isOpen
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  isOpen
                                      ? Icons.warning_amber_outlined
                                      : Icons.check_circle_outline,
                                  color: isOpen
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFF059669),
                                  size: 18,
                                ),
                              ),
                              title: r.studentName,
                              subtitle: r.category,
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isOpen
                                      ? const Color(0xFFFEE2E2)
                                      : const Color(0xFFD1FAE5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(r.status,
                                    style: TextStyle(
                                        color: isOpen
                                            ? const Color(0xFFDC2626)
                                            : const Color(0xFF059669),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600)),
                              ),
                            );
                          }).toList(),
                        ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;
  final String? subtitle;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE5E7EB))),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label,
                    style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1)),
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: color, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(value,
                style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    height: 1)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: TextStyle(
                      color: Colors.grey.shade500, fontSize: 11)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE5E7EB))),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF8B1538), size: 18),
                const SizedBox(width: 8),
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (actionLabel != null && onAction != null)
                  TextButton(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8B1538),
                        padding: EdgeInsets.zero,
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    child: Text(actionLabel!),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Divider(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final Widget trailing;

  const _ListRow({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String message;
  const _EmptyHint(this.message);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(message,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
      ),
    );
  }
}