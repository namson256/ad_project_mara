import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/discipline_controller.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/attendance_controller.dart';
import '../../models/user_model.dart';
import '../admin/admin_shell.dart';
import '../lecturer/lecturer_shell.dart';
import '../ketua/ketua_shell.dart';

class PelaporanView extends StatelessWidget {
  const PelaporanView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final role = user?.role ?? UserRole.pensyarah;

    // Build the main reporting dashboard content
    final content = const _PelaporanDashboardBody();

    // Wrap in the correct shell depending on the current user's role
    switch (role) {
      case UserRole.staff:
        return AdminShell(
          currentRoute: '/admin/pelaporan',
          child: content,
        );
      case UserRole.pensyarah:
        return LecturerShell(
          currentRoute: '/lecturer-pelaporan',
          child: content,
        );
      case UserRole.ketuaProgram:
        return KetuaShell(
          currentRoute: '/ketua-pelaporan',
          child: content,
        );
    }
  }
}

class _PelaporanDashboardBody extends StatelessWidget {
  const _PelaporanDashboardBody();

  @override
  Widget build(BuildContext context) {
    final disciplineCtrl = context.watch<DisciplineController>();
    final courseCtrl = context.watch<CourseController>();
    final attendanceCtrl = context.watch<AttendanceController>();

    final courses = courseCtrl.courses;
    final allRecords = disciplineCtrl.getCombinedRecords(courses, attendanceCtrl);

    // Compute stats
    const totalStudents = 19; // constant 19 students in system
    final totalCases = allRecords.length;

    // Unique students with attendance issues (<80%)
    final lowAttendanceStudentIds = allRecords
        .where((r) => r.isAutoDetected)
        .map((r) => r.studentId)
        .toSet();
    final totalLowAttendanceStudents = lowAttendanceStudentIds.length;

    final unsolvedCases = allRecords.where((r) => r.status == 'Belum Selesai').length;
    final solvedCases = allRecords.where((r) => r.status == 'Selesai').length;

    // Compute counts by category
    final Map<String, int> categoryCounts = {
      'Isu Kehadiran': 0,
      'Salah Laku Tingkah Laku': 0,
      'Isu Akademik': 0,
      'Pelanggaran Kod Pakaian': 0,
      'Lain-lain': 0,
    };
    for (final r in allRecords) {
      if (categoryCounts.containsKey(r.category)) {
        categoryCounts[r.category] = categoryCounts[r.category]! + 1;
      } else {
        categoryCounts['Lain-lain'] = categoryCounts['Lain-lain']! + 1;
      }
    }

    // Compute counts by severity
    final Map<String, int> severityCounts = {
      'Rendah': 0,
      'Sederhana': 0,
      'Tinggi': 0,
    };
    for (final r in allRecords) {
      if (severityCounts.containsKey(r.severity)) {
        severityCounts[r.severity] = severityCounts[r.severity]! + 1;
      }
    }

    // Resolution rate percentage
    final double resolutionRate = totalCases > 0 ? (solvedCases / totalCases) * 100 : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Tajuk Halaman ──
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              const Text(
                'Modul Pelaporan',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Analisis ringkasan statistik kes disiplin dan peratusan kehadiran pelajar.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Kad Statistik Ringkasan (Responsive) ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              final itemWidth = isWide
                  ? (constraints.maxWidth - 64) / 5
                  : (constraints.maxWidth - 16) / 2;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: const _StatCard(
                      label: 'JUMLAH PELAJAR',
                      value: '$totalStudents',
                      icon: Icons.people_outline,
                      color: Color(0xFF8B1538),
                      bgColor: Color(0xFFFDE8ED),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _StatCard(
                      label: 'KES DISIPLIN',
                      value: '$totalCases',
                      icon: Icons.warning_amber_outlined,
                      color: const Color(0xFFF59E0B),
                      bgColor: const Color(0xFFFEF3C7),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _StatCard(
                      label: 'KEHADIRAN < 80%',
                      value: '$totalLowAttendanceStudents',
                      icon: Icons.trending_down_outlined,
                      color: const Color(0xFFEF4444),
                      bgColor: const Color(0xFFFEE2E2),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _StatCard(
                      label: 'KES BELUM SELESAI',
                      value: '$unsolvedCases',
                      icon: Icons.hourglass_empty_outlined,
                      color: const Color(0xFFDC2626),
                      bgColor: const Color(0xFFFEF2F2),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _StatCard(
                      label: 'KES SELESAI',
                      value: '$solvedCases',
                      icon: Icons.done_all_outlined,
                      color: const Color(0xFF10B981),
                      bgColor: const Color(0xFFECFDF5),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 28),

          // ── Bahagian Carta & Visualisasi ──
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _CategoryBreakdownCard(
                        categoryCounts: categoryCounts,
                        totalCases: totalCases,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 2,
                      child: Column(
                        children: [
                          _ResolutionGaugeCard(resolutionRate: resolutionRate),
                          const SizedBox(height: 20),
                          _SeverityBreakdownCard(
                            severityCounts: severityCounts,
                            totalCases: totalCases,
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  _CategoryBreakdownCard(
                    categoryCounts: categoryCounts,
                    totalCases: totalCases,
                  ),
                  const SizedBox(height: 20),
                  _ResolutionGaugeCard(resolutionRate: resolutionRate),
                  const SizedBox(height: 20),
                  _SeverityBreakdownCard(
                    severityCounts: severityCounts,
                    totalCases: totalCases,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Kad Statistik Ringkas
// ─────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bgColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade900,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Pembahagian Mengikut Kategori
// ─────────────────────────────────────────────────────────────
class _CategoryBreakdownCard extends StatelessWidget {
  final Map<String, int> categoryCounts;
  final int totalCases;

  const _CategoryBreakdownCard({
    required this.categoryCounts,
    required this.totalCases,
  });

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Isu Kehadiran':
        return const Color(0xFFEF4444);
      case 'Salah Laku Tingkah Laku':
        return const Color(0xFFF59E0B);
      case 'Isu Akademik':
        return const Color(0xFF3B82F6);
      case 'Pelanggaran Kod Pakaian':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistik Kes Mengikut Kategori',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Jumlah pecahan rekod mengikut kategori masalah.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
            const SizedBox(height: 24),
            ...categoryCounts.entries.map((entry) {
              final catName = entry.key;
              final count = entry.value;
              final double ratio = totalCases > 0 ? count / totalCases : 0.0;
              final percentage = ratio * 100;

              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          catName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF374151),
                          ),
                        ),
                        Text(
                          '$count kes (${percentage.toStringAsFixed(1)}%)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 10,
                        backgroundColor: const Color(0xFFF3F4F6),
                        valueColor: AlwaysStoppedAnimation(
                          _getCategoryColor(catName),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Graf Bulat Kadar Penyelesaian Kes
// ─────────────────────────────────────────────────────────────
class _ResolutionGaugeCard extends StatelessWidget {
  final double resolutionRate;

  const _ResolutionGaugeCard({required this.resolutionRate});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Kadar Penyelesaian Kes',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: SizedBox(
                height: 140,
                width: 140,
                child: CustomPaint(
                  painter: ResolutionGaugePainter(
                    percentage: resolutionRate,
                    color: const Color(0xFF10B981),
                    backgroundColor: const Color(0xFFECFDF5),
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${resolutionRate.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF065F46),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Selesai',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class ResolutionGaugePainter extends CustomPainter {
  final double percentage;
  final Color color;
  final Color backgroundColor;

  ResolutionGaugePainter({
    required this.percentage,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    // Foreground arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth;

    final sweepAngle = 2 * 3.1415926535 * (percentage / 100);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
      -3.1415926535 / 2, // Start at the top
      sweepAngle,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant ResolutionGaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage ||
        oldDelegate.color != color ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

// ─────────────────────────────────────────────────────────────
// Pembahagian Mengikut Tahap Keseriusan
// ─────────────────────────────────────────────────────────────
class _SeverityBreakdownCard extends StatelessWidget {
  final Map<String, int> severityCounts;
  final int totalCases;

  const _SeverityBreakdownCard({
    required this.severityCounts,
    required this.totalCases,
  });

  Color _getSeverityColor(String severity) {
    switch (severity) {
      case 'Tinggi':
        return const Color(0xFFDC2626);
      case 'Sederhana':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF10B981);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pecahan Mengikut Keseriusan',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            ...severityCounts.entries.map((entry) {
              final severity = entry.key;
              final count = entry.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _getSeverityColor(severity),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        severity,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '$count kes',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
           }),
          ],
        ),
      ),
    );
  }
}
