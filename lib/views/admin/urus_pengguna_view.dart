import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/admin_controller.dart';
import '../../models/user_model.dart';
import 'admin_shell.dart';

/// UrusPenggunaView
/// ----------------
/// Skrin pengurusan pengguna (pensyarah) untuk admin.
/// Membolehkan admin menambah, mengemaskini (edit), dan memadam akaun pensyarah.
class UrusPenggunaView extends StatefulWidget {
  const UrusPenggunaView({super.key});

  @override
  State<UrusPenggunaView> createState() => _UrusPenggunaViewState();
}

class _UrusPenggunaViewState extends State<UrusPenggunaView> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _emailCtrl  = TextEditingController();
  final _passCtrl   = TextEditingController();

  UserModel? _editing;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _startEdit(UserModel u) {
    setState(() {
      _editing = u;
      _nameCtrl.text = u.name;
      _emailCtrl.text = u.email;
      _passCtrl.clear(); // Kata laluan kosong melainkan mereka mahu tukar
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = null;
      _nameCtrl.clear();
      _emailCtrl.clear();
      _passCtrl.clear();
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final adminCtrl = context.read<AdminController>();
    
    if (_editing == null) {
      final error = await adminCtrl.addLecturer(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim(),
      );
      if (!mounted) return;
      if (error == null) {
        _cancelEdit();
        _snack('Pensyarah berjaya ditambah.');
      } else {
        _snack(error, error: true);
      }
    } else {
      final error = await adminCtrl.updateLecturer(
        id: _editing!.id,
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text.trim().isNotEmpty ? _passCtrl.text.trim() : null,
      );
      if (!mounted) return;
      if (error == null) {
        _cancelEdit();
        _snack('Maklumat pensyarah berjaya dikemaskini.');
      } else {
        _snack(error, error: true);
      }
    }
  }

  Future<void> _confirmDelete(UserModel u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Padam Pensyarah'),
        content: Text('Padam akaun pensyarah "${u.name}"?\nTindakan ini tidak boleh dibatalkan.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Padam'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final error = await context.read<AdminController>().removeLecturer(u.id);
      if (!mounted) return;
      if (error == null) {
        _snack('Akaun pensyarah berjaya dipadam.');
      } else {
        _snack(error, error: true);
      }
    }
  }

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ));

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: const Color(0xFF8B1538)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(4),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    final lecturers = context.watch<AdminController>().lecturers;
    final isLoading = context.watch<AdminController>().isLoading;

    return AdminShell(
      currentRoute: '/admin/urus-pengguna',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tajuk ──────────────────────────────────────────────────
            const Text('Pengurusan Pengguna',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Tambah, edit dan buang akaun pensyarah untuk sistem.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 28),

            LayoutBuilder(builder: (_, constraints) {
              final wide = constraints.maxWidth >= 800;
              final formCard = _buildFormCard(isLoading);
              final listCard = _buildListCard(lecturers);

              if (wide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 2, child: formCard),
                    const SizedBox(width: 20),
                    Expanded(flex: 3, child: listCard),
                  ],
                );
              }
              return Column(
                children: [
                  formCard,
                  const SizedBox(height: 20),
                  listCard,
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(bool isLoading) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0xFFE5E7EB))),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(
                  _editing == null ? Icons.person_add_outlined : Icons.edit_outlined,
                  size: 18,
                  color: const Color(0xFF8B1538),
                ),
                const SizedBox(width: 8),
                Text(
                  _editing == null ? 'Tambah Pensyarah Baharu' : 'Edit Akaun: ${_editing!.name}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ]),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameCtrl,
                decoration: _dec('Nama penuh', Icons.person_outline),
                validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                decoration: _dec('E-mel', Icons.email_outlined),
                validator: (v) {
                  if (v!.trim().isEmpty) return 'Wajib diisi';
                  if (!v.contains('@')) return 'E-mel tidak sah';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passCtrl,
                obscureText: true,
                decoration: _dec(
                  _editing == null ? 'Kata laluan sementara' : 'Kata laluan baharu (opsional)',
                  Icons.lock_outline,
                ),
                validator: (v) {
                  if (_editing == null && v!.isEmpty) return 'Wajib diisi';
                  if (v!.isNotEmpty && v.length < 6) return 'Sekurang-kurangnya 6 aksara';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF111827),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(_editing == null ? 'Cipta Pensyarah' : 'Simpan Perubahan'),
                    ),
                  ),
                  if (_editing != null) ...[
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _cancelEdit,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Batal'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCard(List<UserModel> lecturers) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0xFFE5E7EB))),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Text('Senarai Pensyarah',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDE8ED),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${lecturers.length}',
                    style: const TextStyle(
                        color: Color(0xFF8B1538), fontWeight: FontWeight.w700)),
              ),
            ]),
            const SizedBox(height: 16),
            if (lecturers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Column(children: [
                    Icon(Icons.people_outline, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text('Tiada pensyarah didaftarkan lagi.',
                        style: TextStyle(color: Colors.grey.shade500)),
                  ]),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: lecturers.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF3F4F6)),
                itemBuilder: (_, i) {
                  final l = lecturers[i];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFFDE8ED),
                      child: Text(
                        l.name.isNotEmpty ? l.name[0].toUpperCase() : '?',
                        style: const TextStyle(color: Color(0xFF8B1538), fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text(l.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(l.email, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, color: Colors.grey, size: 20),
                          tooltip: 'Edit',
                          onPressed: () => _startEdit(l),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          tooltip: 'Padam',
                          onPressed: () => _confirmDelete(l),
                        ),
                      ],
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
