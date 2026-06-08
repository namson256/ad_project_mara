import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/admin_controller.dart';
import '../../controllers/timetable_controller.dart';
import 'admin_shell.dart';

/// Papan Pemuka Pentadbir
class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    final timetable = context.watch<TimetableController>();

    return AdminShell(
      currentRoute: '/admin',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tajuk ──────────────────────────────────────────────────
            const Text('Papan Pemuka Pentadbir',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Urus pengguna, kursus, jadual dan laporan.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 28),

            // ── Kad ringkasan ──────────────────────────────────────────
            LayoutBuilder(builder: (_, constraints) {
              final wide = constraints.maxWidth >= 700;
              final cards = [
                _SummaryCard(
                  label: 'PENGGUNA',
                  value: '${admin.lecturers.length + 1}',
                  icon: Icons.people_outline_rounded,
                ),
                _SummaryCard(
                  label: 'SLOT JADUAL',
                  value: '${timetable.slots.length}',
                  icon: Icons.calendar_month_outlined,
                ),
                _SummaryCard(
                  label: 'PENSYARAH',
                  value: '${admin.lecturers.length}',
                  icon: Icons.school_outlined,
                ),
              ];
              if (wide) {
                return Row(
                  children: cards
                      .map((c) => Expanded(
                          child: Padding(
                              padding: const EdgeInsets.only(right: 16),
                              child: c)))
                      .toList(),
                );
              }
              return Column(
                  children: cards
                      .map((c) =>
                          Padding(padding: const EdgeInsets.only(bottom: 12), child: c))
                      .toList());
            }),

            const SizedBox(height: 28),

            // ── Tindakan pantas ────────────────────────────────────────
            _QuickActionsCard(context: context),
          ],
        ),
      ),
    );
  }
}

// ── Kad ringkasan ─────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _SummaryCard(
      {required this.label, required this.value, required this.icon});

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
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(label,
                  style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1)),
              Icon(icon, color: const Color(0xFF4F46E5), size: 22),
            ]),
            const SizedBox(height: 12),
            Text(value,
                style: const TextStyle(
                    fontSize: 36, fontWeight: FontWeight.w800, height: 1)),
          ],
        ),
      ),
    );
  }
}

// ── Tindakan pantas ───────────────────────────────────────────────────────────
class _QuickActionsCard extends StatelessWidget {
  final BuildContext context;
  const _QuickActionsCard({required this.context});

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
            const Text('Tindakan Pantas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _ActionBtn(
              label: 'Urus pengguna & peranan →',
              onTap: () => context.go('/admin/urus-pengguna'),
            ),
            _ActionBtn(
              label: 'Tambah atau edit kursus →',
              onTap: () => context.go('/admin/senarai-kursus'),
            ),
            _ActionBtn(
              label: 'Muat naik jadual waktu →',
              onTap: () => context.go('/admin/muat-naik-jadual'),
            ),
            _ActionBtn(
              label: 'Lihat semua slot jadual →',
              onTap: () => context.go('/admin/jadual'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF111827),
          backgroundColor: Colors.white,
          minimumSize: const Size.fromHeight(46),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}