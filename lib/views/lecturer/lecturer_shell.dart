import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/auth_controller.dart';

class LecturerShell extends StatefulWidget {
  final String currentRoute;
  final Widget child;

  const LecturerShell({
    super.key,
    required this.currentRoute,
    required this.child,
  });

  @override
  State<LecturerShell> createState() => _LecturerShellState();
}

class _LecturerShellState extends State<LecturerShell> with SingleTickerProviderStateMixin {
  static const Color _sidebarBg = Color(0xFF10162E);
  static const Color _sidebarCard = Color(0xFF1A2344);
  static const Color _accent = Color(0xFF8B1538); // MARA Maroon

  bool _isNavigating = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _navigateWithLoading(String route) {
    if (widget.currentRoute == route) return;
    setState(() => _isNavigating = true);
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) context.go(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Stack(
        children: [
          Row(
        children: [
          Container(
            width: 248,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0D1B3E), Color(0xFF10162E)],
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _sidebarCard,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 42,
                          width: 42,
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.school_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Portal Akademik MARA',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Pensyarah',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  letterSpacing: 1.1,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const _SectionLabel(label: 'UMUM'),
                _NavItem(
                  icon: Icons.dashboard_outlined,
                  label: 'Papan Pemuka',
                  selected: widget.currentRoute == '/lecturer-dashboard',
                  onTap: () => context.go('/lecturer-dashboard'),
                ),
                const _SectionLabel(label: 'KEHADIRAN'),
                _NavItem(
                  icon: Icons.fact_check_outlined,
                  label: 'Tanda Kehadiran',
                  selected: widget.currentRoute == '/lecturer-attendance',
                  onTap: () => _navigateWithLoading('/lecturer-attendance'),
                ),
                const _SectionLabel(label: 'PELAPORAN'),
                _NavItem(
                  icon: Icons.bar_chart_outlined,
                  label: 'Modul Pelaporan',
                  selected: widget.currentRoute == '/lecturer-pelaporan',
                  onTap: () => context.go('/lecturer-pelaporan'),
                ),
                _NavItem(
                  icon: Icons.warning_amber_outlined,
                  label: 'Isu Disiplin',
                  selected: widget.currentRoute == '/lecturer-isu-disiplin',
                  onTap: () => context.go('/lecturer-isu-disiplin'),
                ),
                const _SectionLabel(label: 'JADUAL'),
                _NavItem(
                  icon: Icons.calendar_month_outlined,
                  label: 'Slot Jadual',
                  selected: false,
                  onTap: () => context.go('/lecturer-dashboard'),
                ),
                _NavItem(
                  icon: Icons.event_available_outlined,
                  label: 'Tempahan',
                  selected: widget.currentRoute == '/lecturer-booking',
                  onTap: () => context.go('/lecturer-booking'),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    decoration: BoxDecoration(
                      color: _sidebarCard,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: _accent,
                              child: Text(
                                auth.currentUser?.name.isNotEmpty == true
                                    ? auth.currentUser!.name[0].toUpperCase()
                                    : 'P',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    auth.currentUser?.name ?? 'Pensyarah Demo',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    auth.currentUser?.email ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        TextButton.icon(
                          onPressed: () {
                            context.read<AuthController>().logout();
                            context.go('/login');
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            minimumSize: const Size.fromHeight(40),
                            alignment: Alignment.centerLeft,
                          ),
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Log keluar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
          // Loading overlay spanning the whole shell
          if (_isNavigating)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.3),
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
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Sila tunggu sebentar',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;

  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF8792C0),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: selected ? const Color(0xFF2D1520) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected ? Colors.white : Colors.white70,
                  size: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white70,
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(Icons.circle, color: Color(0xFFE11D48), size: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}