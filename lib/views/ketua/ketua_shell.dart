import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';

class KetuaShell extends StatelessWidget {
  final String currentRoute;
  final Widget child;

  const KetuaShell({
    super.key,
    required this.currentRoute,
    required this.child,
  });

  static const Color _bg     = Color(0xFF10162E);
  static const Color _card   = Color(0xFF1A2344);
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
                              Text('Portal Ketua Jabatan',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800)),
                              SizedBox(height: 2),
                              Text('KETUA PROGRAM',
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

                // Nav items — scrollable so they never overflow
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // GAMBARAN KESELURUHAN
                        const _Label('GAMBARAN KESELURUHAN'),
                        _Item(
                          icon: Icons.dashboard_outlined,
                          label: 'Papan Pemuka',
                          selected: currentRoute == '/ketua-dashboard',
                          onTap: () => context.go('/ketua-dashboard'),
                        ),

                        // PELAPORAN
                        const _Label('PELAPORAN'),
                        _Item(
                          icon: Icons.bar_chart_outlined,
                          label: 'Modul Pelaporan',
                          selected: currentRoute == '/ketua-pelaporan',
                          onTap: () => context.go('/ketua-pelaporan'),
                        ),
                        _Item(
                          icon: Icons.warning_amber_outlined,
                          label: 'Isu Disiplin',
                          selected: currentRoute == '/ketua-isu-disiplin',
                          onTap: () => context.go('/ketua-isu-disiplin'),
                        ),

                        // TEMPAHAN
                        const _Label('TEMPAHAN'),
                        _Item(
                          icon: Icons.event_available_outlined,
                          label: 'Semakan Tempahan',
                          selected: currentRoute == '/ketua-booking',
                          onTap: () => context.go('/ketua-booking'),
                        ),

                        // SISTEM
                        const _Label('SISTEM'),
                        _Item(
                          icon: Icons.lock_outline,
                          label: 'Pengesahan',
                          selected: false,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),
                ),

                // User card — pinned at bottom
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
                                    : 'K',
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
                                    auth.currentUser?.name ?? 'Ketua Program',
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

          // ── Main content ─────────────────────────────────────────────
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ── Shared sidebar widgets ────────────────────────────────────────────────────

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