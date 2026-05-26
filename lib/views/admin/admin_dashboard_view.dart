import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/admin_controller.dart';

/// AdminDashboardView
/// ----------------
/// Responsive web layout:
///   * Wide screens (≥900 px): permanent sidebar on the left.
///   * Narrow screens: sidebar collapses into a Drawer behind a menu button.
///
/// Main content has two sections side-by-side on wide screens, stacked
/// vertically on narrow ones:
///   * "Add New Lecturer" form
///   * Existing lecturers list
class AdminDashboardView extends StatelessWidget {
  const AdminDashboardView({super.key});

  static const _wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: isWide
          ? null
          : AppBar(
              title: const Text('Admin Dashboard'),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
      drawer: isWide ? null : const Drawer(child: _Sidebar()),
      body: Row(
        children: [
          if (isWide)
            const SizedBox(
              width: 240,
              child: Material(
                color: Color(0xFF1A237E),
                child: _Sidebar(),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isWide) ...[
                      const Text(
                        'Admin Dashboard',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage lecturer accounts',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 24),
                    ],
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final twoColumn = constraints.maxWidth >= 800;
                        if (twoColumn) {
                          return const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 2, child: _AddLecturerCard()),
                              SizedBox(width: 24),
                              Expanded(flex: 3, child: _LecturersListCard()),
                            ],
                          );
                        }
                        return const Column(
                          children: [
                            _AddLecturerCard(),
                            SizedBox(height: 24),
                            _LecturersListCard(),
                          ],
                        );
                      },
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

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------
class _Sidebar extends StatelessWidget {
  const _Sidebar();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 16),
          child: Row(
            children: [
              const Icon(Icons.school, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Text(
                'Portal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 8),
        _SidebarTile(
          icon: Icons.dashboard_outlined,
          label: 'Dashboard',
          selected: true,
          onTap: () {},
        ),
        _SidebarTile(
          icon: Icons.people_outline,
          label: 'Lecturers',
          onTap: () {},
        ),
        _SidebarTile(
          icon: Icons.settings_outlined,
          label: 'Settings',
          onTap: () {},
        ),
        const Spacer(),
        const Divider(color: Colors.white24, height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                auth.currentUser?.name ?? '',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                auth.currentUser?.email ?? '',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
        _SidebarTile(
          icon: Icons.logout,
          label: 'Logout',
          onTap: () {
            context.read<AuthController>().logout();
            // Router's redirect will catch this and route to /login.
            context.go('/login');
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SidebarTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: selected ? Colors.white.withOpacity(0.1) : null,
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add Lecturer card
// ---------------------------------------------------------------------------
class _AddLecturerCard extends StatefulWidget {
  const _AddLecturerCard();

  @override
  State<_AddLecturerCard> createState() => _AddLecturerCardState();
}

class _AddLecturerCardState extends State<_AddLecturerCard> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final ok = context.read<AdminController>().addLecturer(
          name: _nameCtrl.text,
          email: _emailCtrl.text,
          password: _passwordCtrl.text,
        );

    if (!mounted) return;

    if (ok) {
      _nameCtrl.clear();
      _emailCtrl.clear();
      _passwordCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lecturer added successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A lecturer with this email already exists'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add New Lecturer',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                'Create a new lecturer account',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Required';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Temporary password',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (v.length < 6) return 'Min 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Lecturer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lecturers list card
// ---------------------------------------------------------------------------
class _LecturersListCard extends StatelessWidget {
  const _LecturersListCard();

  @override
  Widget build(BuildContext context) {
    final admin = context.watch<AdminController>();
    final lecturers = admin.lecturers;

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Lecturers',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                Chip(
                  label: Text('${lecturers.length}'),
                  backgroundColor: Colors.indigo.shade50,
                  labelStyle: const TextStyle(color: Colors.indigo),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (lecturers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.people_outline,
                        size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 12),
                    Text(
                      'No lecturers yet',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lecturers.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final l = lecturers[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.shade100,
                      child: Text(
                        l.name.isNotEmpty ? l.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.indigo),
                      ),
                    ),
                    title: Text(l.name),
                    subtitle: Text(l.email),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.redAccent),
                      tooltip: 'Remove',
                      onPressed: () =>
                          context.read<AdminController>().removeLecturer(l.id),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}