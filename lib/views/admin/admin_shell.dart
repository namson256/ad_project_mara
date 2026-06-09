import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';

/// AdminShell
/// ----------
/// Sidebar gelap berterusan untuk semua skrin admin.
/// Reka bentuk sepadan dengan LecturerShell.
class AdminShell extends StatelessWidget {
  final String currentRoute;
  final Widget child;

  const AdminShell({
    super.key,
    required this.currentRoute,
    required this.child,
  });

  static const Color _bg   = Color(0xFF10162E);
  static const Color _card = Color(0xFF1A2344);
  static const Color _accent = Color(0xFF4F5BD5);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Row(
        children: [
          // ── Sidebar ──────────────────────────────────────────────────
          Container(
            width: 248,
            color: _bg,
            child: Column(
              children: [
                // Brand
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: _card,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 42, width: 42,
                          decoration: BoxDecoration(
                            color: _accent,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.school_outlined,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Portal Akademik MARA',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800)),
                              SizedBox(height: 2),
                              Text('PORTAL ADMIN',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      letterSpacing: 1.1,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // OVERVIEW
                const _Label('GAMBARAN KESELURUHAN'),
                _Item(
                  icon: Icons.dashboard_outlined,
                  label: 'Papan Pemuka Admin',
                  selected: currentRoute == '/admin',
                  onTap: () => context.go('/admin'),
                ),

                // PENGURUSAN
                const _Label('PENGURUSAN'),
                _Item(
                  icon: Icons.people_outline,
                  label: 'Urus Pengguna',
                  selected: currentRoute == '/admin/urus-pengguna',
                  onTap: () => context.go('/admin/urus-pengguna'),
                ),
                _Item(
                  icon: Icons.menu_book_outlined,
                  label: 'Senarai Kursus',
                  selected: currentRoute == '/admin/senarai-kursus',
                  onTap: () => context.go('/admin/senarai-kursus'),
                ),

                // PENJADUALAN
                const _Label('PENJADUALAN'),
                _Item(
                  icon: Icons.upload_outlined,
                  label: 'Muat Naik Jadual',
                  selected: currentRoute == '/admin/muat-naik-jadual',
                  onTap: () => context.go('/admin/muat-naik-jadual'),
                ),
                _Item(
                  icon: Icons.calendar_month_outlined,
                  label: 'Slot Jadual Waktu',
                  selected: currentRoute == '/admin/jadual',
                  onTap: () => context.go('/admin/jadual'),
                ),

                // LAPORAN
                const _Label('PELAPORAN'),
                _Item(
                  icon: Icons.bar_chart_outlined,
                  label: 'Modul Pelaporan',
                  selected: currentRoute == '/admin/pelaporan',
                  onTap: () => context.go('/admin/pelaporan'),
                ),
                _Item(
                  icon: Icons.warning_amber_outlined,
                  label: 'Isu Disiplin',
                  selected: currentRoute == '/admin/isu-disiplin',
                  onTap: () => context.go('/admin/isu-disiplin'),
                ),

                // SISTEM
                const _Label('SISTEM'),
                _Item(
                  icon: Icons.lock_outline,
                  label: 'Pengesahan',
                  selected: false,
                  onTap: () {},
                ),

                const Spacer(),

                // User card
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                    decoration: BoxDecoration(
                      color: _card,
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
                                    : 'A',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    auth.currentUser?.name ?? 'Admin',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700),
                                  ),
                                  Text(
                                    auth.currentUser?.email ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 11),
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
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            minimumSize: const Size.fromHeight(36),
                            alignment: Alignment.centerLeft,
                          ),
                          icon: const Icon(Icons.logout, size: 16),
                          label: const Text('Log Keluar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Kandungan utama ──────────────────────────────────────────
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 4),
      child: Text(text,
          style: const TextStyle(
              color: Color(0xFF8792C0),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1)),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _Item({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: selected ? const Color(0xFF2C3767) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(icon,
                    color: selected ? Colors.white : Colors.white70,
                    size: 19),
                const SizedBox(width: 13),
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: selected ? Colors.white : Colors.white70,
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w400)),
                ),
                if (selected)
                  const Icon(Icons.circle,
                      color: Color(0xFF5C6BFF), size: 7),
              ],
            ),
          ),
        ),
      ),
    );
  }
}