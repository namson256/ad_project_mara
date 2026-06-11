import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import 'lecturer_shell.dart';

/// LecturerDashboardView
/// ----------------
/// Minimal welcome screen for lecturers. Centered card, max-width for web.
class LecturerDashboardView extends StatefulWidget {
  const LecturerDashboardView({super.key});

  @override
  State<LecturerDashboardView> createState() => _LecturerDashboardViewState();
}

class _LecturerDashboardViewState extends State<LecturerDashboardView>
    with SingleTickerProviderStateMixin {
  bool _isNavigating = false;
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

  void _navigateWithLoading(BuildContext context, String route) {
    setState(() => _isNavigating = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) context.go(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;

    return LecturerShell(
      currentRoute: '/lecturer-dashboard',
      child: Stack(
        children: [
          SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Papan Pemuka Pensyarah',
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
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final cardWidth = isWide
                    ? (constraints.maxWidth - 48) / 4
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: cardWidth,
                      child: const _MetricCard(
                        label: 'KURSUS AKTIF',
                        value: '5',
                        icon: Icons.menu_book_outlined,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: const _MetricCard(
                        label: 'PELAJAR BERDAFTAR',
                        value: '12',
                        icon: Icons.groups_outlined,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: const _MetricCard(
                        label: 'KADAR KEHADIRAN',
                        value: '85%',
                        icon: Icons.event_available_outlined,
                      ),
                    ),
                    SizedBox(
                      width: cardWidth,
                      child: const _MetricCard(
                        label: 'ISU DISIPLIN',
                        value: '8',
                        valueColor: Color(0xFFEF4444),
                        icon: Icons.warning_amber_outlined,
                        iconColor: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                final leftWidth = isWide
                    ? constraints.maxWidth * 0.68
                    : constraints.maxWidth;
                final rightWidth = isWide
                    ? constraints.maxWidth * 0.32 - 16
                    : constraints.maxWidth;

                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: leftWidth,
                      child: const _PanelCard(
                        title: 'Jadual Hari Ini',
                        trailing: Text(
                          'Lihat jadual',
                          style: TextStyle(
                            color: Color(0xFF8B1538),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: SizedBox(
                          height: 260,
                          child: Center(
                            child: Text(
                              'Tiada kelas dijadualkan hari ini.',
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: rightWidth,
                      child: _PanelCard(
                        title: 'Tindakan Pantas',
                        child: Column(
                          children: [
                            _QuickActionButton(
                              label: 'Tanda kehadiran',
                              onTap: () => _navigateWithLoading(context, '/lecturer-attendance'),
                            ),
                            _QuickActionButton(
                              label: 'Lapor isu disiplin',
                              onTap: () => context.go('/lecturer-isu-disiplin'),
                            ),
                            _QuickActionButton(
                              label: 'Tempah kelas ganti',
                              onTap: () => context.go('/lecturer-dashboard'),
                            ),
                            _QuickActionButton(
                              label: 'Lihat laporan',
                              onTap: () => context.go('/lecturer-pelaporan'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
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
                padding: const EdgeInsets.all(22),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: const Color(0xFFF3F4F6),
                      child: Text(
                        user?.name.isNotEmpty == true
                            ? user!.name[0].toUpperCase()
                            : 'P',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF111827),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.name ?? 'Pensyarah',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user?.email ?? '',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFDE8ED),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Pensyarah',
                          style: TextStyle(
                            color: Color(0xFF8B1538),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
          // Loading overlay
          if (_isNavigating)
            Container(
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
                          borderRadius: BorderRadius.circular(24),
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
                              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B1538)),
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
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color valueColor;
  final Color iconColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor = const Color(0xFF111827),
    this.iconColor = const Color(0xFF8B1538),
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                Icon(icon, color: iconColor, size: 22),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: valueColor,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const _PanelCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.all(18), child: child),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _QuickActionButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(label),
        ),
      ),
    );
  }
}
