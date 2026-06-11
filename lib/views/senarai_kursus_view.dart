import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/admin_controller.dart';
import '../../models/course_model.dart';
import 'admin/admin_shell.dart';

/// SenaraiKursusView
/// -----------------
/// Skrin senarai kursus untuk admin.
/// Reka bentuk sepadan dengan prototaip ScholarTrack.
class SenaraiKursusView extends StatefulWidget {
  const SenaraiKursusView({super.key});

  @override
  State<SenaraiKursusView> createState() => _SenaraiKursusViewState();
}

class _SenaraiKursusViewState extends State<SenaraiKursusView> {
  final _codeCtrl  = TextEditingController();
  final _nameCtrl  = TextEditingController();
  final _deptCtrl  = TextEditingController();
  final _sectionsCtrl = TextEditingController(text: '1');
  final _formKey   = GlobalKey<FormState>();

  String? _selectedLecturerId;
  String? _selectedLecturerName;

  // Edit mode
  CourseModel? _editing;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _deptCtrl.dispose();
    _sectionsCtrl.dispose();
    super.dispose();
  }

  void _startEdit(CourseModel c, List lecturers) {
    setState(() {
      _editing = c;
      _codeCtrl.text = c.code;
      _nameCtrl.text = c.name;
      _deptCtrl.text = c.department;
      _sectionsCtrl.text = c.sections.toString();
      _selectedLecturerId = c.lecturerId.isEmpty ? null : c.lecturerId;
      _selectedLecturerName = c.lecturerName.isEmpty ? null : c.lecturerName;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editing = null;
      _codeCtrl.clear();
      _nameCtrl.clear();
      _deptCtrl.clear();
      _sectionsCtrl.text = '1';
      _selectedLecturerId = null;
      _selectedLecturerName = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ctrl = context.read<CourseController>();
    final sectionsVal = int.tryParse(_sectionsCtrl.text.trim()) ?? 1;
    final course = CourseModel(
      id: _editing?.id ?? '',
      code: _codeCtrl.text.trim().toUpperCase(),
      name: _nameCtrl.text.trim(),
      lecturerId: _selectedLecturerId ?? '',
      lecturerName: _selectedLecturerName ?? '',
      department: _deptCtrl.text.trim().toUpperCase(),
      sections: sectionsVal,
    );

    String? error;
    if (_editing == null) {
      error = await ctrl.addCourse(course);
    } else {
      error = await ctrl.updateCourse(course);
    }

    if (!mounted) return;
    if (error != null) {
      _snack(error, error: true);
    } else {
      _snack(_editing == null ? 'Kursus berjaya ditambah!' : 'Kursus berjaya dikemaskini!');
      _cancelEdit();
    }
  }

  Future<void> _confirmDelete(CourseModel c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Padam Kursus'),
        content: Text('Padam "${c.code} – ${c.name}"?\nTindakan ini tidak boleh dibatalkan.'),
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
      await context.read<CourseController>().deleteCourse(c.id);
      _snack('Kursus berjaya dipadam.');
    }
  }

  void _snack(String msg, {bool error = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red : Colors.green[700],
        behavior: SnackBarBehavior.floating,
      ));

  InputDecoration _dec(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    final courses   = context.watch<CourseController>().courses;
    final lecturers = context.watch<AdminController>().lecturers;
    final isLoading = context.watch<CourseController>().isLoading;

    return AdminShell(
      currentRoute: '/admin/senarai-kursus',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Tajuk ──────────────────────────────────────────────────
            const Text('Senarai Kursus',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Tambah, edit dan buang kursus tersedia untuk penjadualan.',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 24),

            // ── Borang tambah / edit ─────────────────────────────────
            Card(
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
                            _editing == null
                                ? Icons.add_circle_outline
                                : Icons.edit_outlined,
                            size: 18,
                            color: const Color(0xFF8B1538)),
                        const SizedBox(width: 8),
                        Text(
                          _editing == null
                              ? '+ Tambah kursus baharu'
                              : 'Edit kursus: ${_editing!.code}',
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      // Row: Kod | Nama kursus | Pensyarah | Jabatan | Butang
                      LayoutBuilder(builder: (_, c) {
                        final wide = c.maxWidth >= 700;
                        final fields = [
                          SizedBox(
                            width: wide ? 110 : double.infinity,
                            child: TextFormField(
                              controller: _codeCtrl,
                              decoration: _dec('Kod (cth. CS101)'),
                              textCapitalization: TextCapitalization.characters,
                              validator: (v) =>
                                  v!.trim().isEmpty ? 'Wajib' : null,
                            ),
                          ),
                          SizedBox(
                            width: wide ? null : double.infinity,
                            child: TextFormField(
                              controller: _nameCtrl,
                              decoration: _dec('Nama kursus'),
                              validator: (v) =>
                                  v!.trim().isEmpty ? 'Wajib' : null,
                            ),
                          ),
                          SizedBox(
                            width: wide ? 200 : double.infinity,
                            child: DropdownButtonFormField<String>(
                              value: _selectedLecturerId,
                              decoration: _dec('Pensyarah'),
                              items: [
                                const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('Tidak ditetapkan',
                                        style: TextStyle(color: Colors.grey))),
                                ...lecturers.map<DropdownMenuItem<String>>((l) => DropdownMenuItem<String>(
                                    value: l.id, child: Text(l.name))),
                              ],
                              onChanged: (id) {
                                setState(() {
                                  _selectedLecturerId = id;
                                  _selectedLecturerName = id == null
                                      ? null
                                      : lecturers
                                          .firstWhere((l) => l.id == id)
                                          .name;
                                });
                              },
                            ),
                          ),
                          SizedBox(
                            width: wide ? 90 : double.infinity,
                            child: TextFormField(
                              controller: _deptCtrl,
                              decoration: _dec('Jabatan'),
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                          SizedBox(
                            width: wide ? 80 : double.infinity,
                            child: TextFormField(
                              controller: _sectionsCtrl,
                              decoration: _dec('Seksyen'),
                              keyboardType: TextInputType.number,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Wajib';
                                final val = int.tryParse(v);
                                if (val == null || val <= 0) return 'Min 1';
                                return null;
                              },
                            ),
                          ),
                        ];

                        if (wide) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              fields[0],
                              const SizedBox(width: 10),
                              Expanded(child: fields[1]),
                              const SizedBox(width: 10),
                              fields[2],
                              const SizedBox(width: 10),
                              fields[3],
                              const SizedBox(width: 10),
                              fields[4],
                              const SizedBox(width: 10),
                              _SubmitBtn(
                                  isEdit: _editing != null,
                                  onSubmit: _submit,
                                  onCancel: _cancelEdit),
                            ],
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ...fields.map((f) =>
                                Padding(padding: const EdgeInsets.only(bottom: 10), child: f)),
                            _SubmitBtn(
                                isEdit: _editing != null,
                                onSubmit: _submit,
                                onCancel: _cancelEdit),
                          ],
                        );
                      }),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── Jadual kursus ────────────────────────────────────────
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                  side: const BorderSide(color: Color(0xFFE5E7EB))),
              color: Colors.white,
              clipBehavior: Clip.antiAlias,
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()))
                  : courses.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(children: [
                            Icon(Icons.menu_book_outlined,
                                size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('Tiada kursus lagi.',
                                style: TextStyle(color: Colors.grey.shade500)),
                          ]),
                        )
                      : _CourseTable(
                          courses: courses,
                          onEdit: (c) => _startEdit(c, lecturers),
                          onDelete: _confirmDelete,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Butang hantar ─────────────────────────────────────────────────────────────
class _SubmitBtn extends StatelessWidget {
  final bool isEdit;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  const _SubmitBtn(
      {required this.isEdit,
      required this.onSubmit,
      required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF111827),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: Text(isEdit ? 'Simpan' : 'Tambah kursus'),
        ),
        if (isEdit) ...[
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Batal'),
          ),
        ],
      ],
    );
  }
}

// ── Jadual kursus ─────────────────────────────────────────────────────────────
class _CourseTable extends StatelessWidget {
  final List<CourseModel> courses;
  final ValueChanged<CourseModel> onEdit;
  final ValueChanged<CourseModel> onDelete;

  const _CourseTable(
      {required this.courses,
      required this.onEdit,
      required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(90),
        1: FlexColumnWidth(3),
        2: FlexColumnWidth(2),
        3: FixedColumnWidth(80),
        4: FixedColumnWidth(70),
        5: FixedColumnWidth(100),
      },
      children: [
        // Header
        TableRow(
          decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: Color(0xFFE5E7EB)))),
          children: [
            _TH('Kod'),
            _TH('Nama'),
            _TH('Pensyarah'),
            _TH('Jabatan'),
            _TH('Seksyen'),
            _TH('Tindakan'),
          ],
        ),
        // Rows
        ...courses.map(
          (c) => TableRow(
            decoration: BoxDecoration(
                border: Border(
                    bottom: BorderSide(color: Colors.grey.shade100))),
            children: [
              _TC(
                child: Text(c.code,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              _TC(child: Text(c.name)),
              _TC(
                child: Text(
                  c.hasLecturer ? c.lecturerName : 'Tidak ditetapkan',
                  style: TextStyle(
                      color: c.hasLecturer ? null : Colors.grey),
                ),
              ),
              _TC(
                child: Text(
                  c.department.isEmpty ? '—' : c.department,
                  style: TextStyle(
                      color:
                          c.department.isEmpty ? Colors.grey : null),
                ),
              ),
              _TC(
                child: Text('${c.sections}'),
              ),
              _TC(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _IconBtn(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit',
                      onTap: () => onEdit(c),
                    ),
                    const SizedBox(width: 4),
                    _IconBtn(
                      icon: Icons.delete_outline,
                      tooltip: 'Padam',
                      color: Colors.red,
                      onTap: () => onDelete(c),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(text,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade500,
                letterSpacing: 0.3)),
      );
}

class _TC extends StatelessWidget {
  final Widget child;
  const _TC({required this.child});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: child,
      );
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = const Color(0xFF374151),
  });

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      );
}