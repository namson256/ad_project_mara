import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/discipline_controller.dart';
import '../../controllers/course_controller.dart';
import '../../controllers/attendance_controller.dart';
import '../../models/user_model.dart';
import '../../models/discipline_record_model.dart';
import '../admin/admin_shell.dart';
import '../lecturer/lecturer_shell.dart';
import '../ketua/ketua_shell.dart';

class IsuDisiplinView extends StatefulWidget {
  const IsuDisiplinView({super.key});

  @override
  State<IsuDisiplinView> createState() => _IsuDisiplinViewState();
}

class _IsuDisiplinViewState extends State<IsuDisiplinView> {
  String _selectedCategory = 'Semua';
  String _searchQuery = '';
  final Set<String> _expandedStudentIds = {};
  bool _onlyLowAttendance = false;

  // ── Overlay notification ──────────────────────────────────────
  OverlayEntry? _overlayEntry;

  void _showTopNotification(String message, String type) {
    _overlayEntry?.remove();
    _overlayEntry = null;

    final entry = OverlayEntry(
      builder: (ctx) => _NotificationBanner(
        message: message,
        type: type,
        onDismiss: () {
          _overlayEntry?.remove();
          _overlayEntry = null;
        },
      ),
    );
    _overlayEntry = entry;
    Overlay.of(context).insert(entry);

    Future.delayed(const Duration(seconds: 4), () {
      if (_overlayEntry == entry) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }

  final List<String> _categories = [
    'Semua',
    'Isu Kehadiran',
    'Salah Laku Tingkah Laku',
    'Isu Akademik',
    'Pelanggaran Kod Pakaian',
    'Lain-lain',
  ];

  static const List<String> _statusOptions = [
    'Belum Selesai',
    'Dalam Proses',
    'Selesai',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final role = user?.role ?? UserRole.pensyarah;
    final content = _buildBody(context, user);

    switch (role) {
      case UserRole.staff:
        return AdminShell(currentRoute: '/admin/isu-disiplin', child: content);
      case UserRole.pensyarah:
        return LecturerShell(currentRoute: '/lecturer-isu-disiplin', child: content);
      case UserRole.ketuaProgram:
        return KetuaShell(currentRoute: '/ketua-isu-disiplin', child: content);
    }
  }

  Widget _buildBody(BuildContext context, UserModel? user) {
    final disciplineCtrl = context.watch<DisciplineController>();
    final courseCtrl = context.watch<CourseController>();
    final attendanceCtrl = context.watch<AttendanceController>();

    final courses = courseCtrl.courses;
    final allRecords = disciplineCtrl.getCombinedRecords(courses, attendanceCtrl);
    final isReadOnly = user?.role == UserRole.ketuaProgram;

    // Category counts
    final Map<String, int> categoryCounts = {
      'Semua': allRecords.length,
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

    // Apply filters
    var filtered = allRecords;
    if (_selectedCategory != 'Semua') {
      filtered = filtered.where((r) => r.category == _selectedCategory).toList();
    }
    if (_onlyLowAttendance) {
      final lowIds = allRecords
          .where((r) => r.isAutoDetected)
          .map((r) => r.studentId)
          .toSet();
      filtered = filtered.where((r) => lowIds.contains(r.studentId)).toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((r) =>
          r.studentName.toLowerCase().contains(q) ||
          r.matricNo.toLowerCase().contains(q) ||
          r.title.toLowerCase().contains(q)).toList();
    }

    // Group by student
    final Map<String, List<DisciplineRecord>> grouped = {};
    for (final r in filtered) {
      grouped.putIfAbsent(r.studentId, () => []).add(r);
    }

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ───────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        const Text(
                          'Pengurusan Isu Disiplin Pelajar',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pantau, tambah dan kemas kini rekod salah laku serta amaran disiplin.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isReadOnly) ...[
                // Toggle low-attendance filter (moved from search bar)
                ElevatedButton.icon(
                  onPressed: () => setState(() => _onlyLowAttendance = !_onlyLowAttendance),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _onlyLowAttendance ? const Color(0xFFEF4444) : Colors.white,
                    foregroundColor: _onlyLowAttendance ? Colors.white : const Color(0xFF374151),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: _onlyLowAttendance ? Colors.transparent : const Color(0xFFE5E7EB))),
                  ),
                  icon: Icon(
                    _onlyLowAttendance ? Icons.filter_alt_off_outlined : Icons.filter_alt_outlined,
                    size: 18,
                  ),
                  label: const Text('Kesan Kehadiran < 80%', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                const SizedBox(width: 12),
                // Tambah Rekod
                ElevatedButton.icon(
                  onPressed: () => _showAddEditDialog(context, null, user),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Tambah Rekod',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
          const SizedBox(height: 24),

          // ── Category Filter Cards ─────────────────────────────
          SizedBox(
            height: 94,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSelected = _selectedCategory == cat;
                final count = categoryCounts[cat] ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () => setState(() => _selectedCategory = cat),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 170,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF4F46E5) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? Colors.transparent : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(cat,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : const Color(0xFF374151),
                              )),
                          const SizedBox(height: 4),
                          Text('$count Rekod',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: isSelected ? Colors.white70 : Colors.grey.shade500,
                              )),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // ── Search & Filter Bar ───────────────────────────────
          Row(
            children: [
              Expanded(
                child: Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: TextField(
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Cari nama pelajar, no. matrik atau tajuk isu...',
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ),
          const SizedBox(height: 18),

          // ── Records List ──────────────────────────────────────
          Expanded(
            child: grouped.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.assignment_turned_in_outlined,
                            size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('Tiada rekod isu disiplin ditemui.',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: grouped.length,
                    itemBuilder: (ctx, index) {
                      final studentId = grouped.keys.elementAt(index);
                      final recs = grouped[studentId]!;
                      final first = recs.first;
                      final isExpanded = _expandedStudentIds.contains(studentId);
                      return _buildStudentCard(
                        ctx, studentId, first.studentName,
                        first.matricNo, first.programme,
                        recs, isExpanded, isReadOnly, user,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Student Card ──────────────────────────────────────────────
  Widget _buildStudentCard(
    BuildContext context,
    String studentId,
    String name,
    String matric,
    String program,
    List<DisciplineRecord> records,
    bool isExpanded,
    bool isReadOnly,
    UserModel? currentUser,
  ) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedStudentIds.remove(studentId);
                } else {
                  _expandedStudentIds.add(studentId);
                }
              });
            },
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isExpanded ? 0 : 16),
              bottomRight: Radius.circular(isExpanded ? 0 : 16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFEEF2FF),
                    child: Text(
                      name.isNotEmpty ? name[0] : 'S',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF111827))),
                        const SizedBox(height: 3),
                        Row(
                          children: [
                            Text(matric,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(width: 8),
                            Icon(Icons.circle, size: 4, color: Colors.grey.shade400),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(program,
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey.shade500),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${records.length} Kes',
                        style: const TextStyle(
                            color: Color(0xFFD97706),
                            fontWeight: FontWeight.w800,
                            fontSize: 12)),
                  ),
                  const SizedBox(width: 14),
                  Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.grey.shade500),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1),
            Container(
              color: const Color(0xFFFAFBFC),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: records
                    .map((r) => _buildHistoryItem(context, r, isReadOnly, currentUser))
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── History Item ──────────────────────────────────────────────
  Widget _buildHistoryItem(
    BuildContext context,
    DisciplineRecord record,
    bool isReadOnly,
    UserModel? currentUser,
  ) {
    // Severity colours
    Color sevBg, sevText;
    if (record.severity == 'Tinggi') {
      sevBg = const Color(0xFFFEE2E2);
      sevText = const Color(0xFF991B1B);
    } else if (record.severity == 'Sederhana') {
      sevBg = const Color(0xFFFEF3C7);
      sevText = const Color(0xFF92400E);
    } else {
      sevBg = const Color(0xFFEFF6FF);
      sevText = const Color(0xFF1E40AF);
    }

    // Status colours
    Color statusBg, statusFg;
    switch (record.status) {
      case 'Selesai':
        statusBg = const Color(0xFFECFDF5);
        statusFg = const Color(0xFF065F46);
        break;
      case 'Dalam Proses':
        statusBg = const Color(0xFFFFF7ED);
        statusFg = const Color(0xFF92400E);
        break;
      default: // Belum Selesai
        statusBg = const Color(0xFFFFEBEB);
        statusFg = const Color(0xFF9B1C1C);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Badges row ──
          Row(
            children: [
              _badge(record.severity, sevBg, sevText),
              const SizedBox(width: 8),
              _badge(record.status, statusBg, statusFg),
              if (record.isAutoDetected) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    border: Border.all(color: const Color(0xFFFFE8D6)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bolt, color: Colors.orange, size: 12),
                      SizedBox(width: 3),
                      Text('Dikesan Secara Automatik',
                          style: TextStyle(
                              color: Color(0xFFEA580C),
                              fontWeight: FontWeight.w800,
                              fontSize: 10)),
                    ],
                  ),
                ),
              ],
              const Spacer(),
              Text(_formatDateTime(record.reportedDate),
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 14),

          // ── Title ──
          Text(record.title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF374151))),
          const SizedBox(height: 6),

          // ── Description ──
          Text(record.description,
              style: TextStyle(
                  color: Colors.grey.shade700, fontSize: 13, height: 1.5)),

          // ── Catatan block ──
          if (record.catatan != null && record.catatan!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFBAE6FD)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.comment_outlined, color: Color(0xFF0284C7), size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Catatan: ${record.catatan}',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF0369A1),
                          fontStyle: FontStyle.italic,
                          height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // ── Reporter + Actions ──
          Row(
            children: [
              Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 6),
              Text('Dilaporkan oleh: ${record.reportedBy}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const Spacer(),
              if (!isReadOnly) ...[
                // Status dropdown
                _buildStatusDropdown(context, record),
                const SizedBox(width: 8),
                // Edit button — available for ALL records (manual + auto-detected)
                IconButton(
                  tooltip: 'Edit / Tambah Catatan',
                  icon: const Icon(Icons.edit_outlined,
                      size: 16, color: Color(0xFF4F46E5)),
                  onPressed: () => _showAddEditDialog(context, record, currentUser),
                ),
                // Delete button
                IconButton(
                  tooltip: 'Padam Rekod',
                  icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                  onPressed: () => _showDeleteConfirmation(context, record.id),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Status Dropdown widget ────────────────────────────────────
  Widget _buildStatusDropdown(BuildContext context, DisciplineRecord record) {
    Color bg, fg;
    switch (record.status) {
      case 'Selesai':
        bg = const Color(0xFFECFDF5);
        fg = const Color(0xFF065F46);
        break;
      case 'Dalam Proses':
        bg = const Color(0xFFFFF7ED);
        fg = const Color(0xFF92400E);
        break;
      default:
        bg = const Color(0xFFFFEBEB);
        fg = const Color(0xFF9B1C1C);
    }

    // Ensure current status is in options (fallback to first)
    final currentStatus =
        _statusOptions.contains(record.status) ? record.status : _statusOptions.first;

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: currentStatus,
          isDense: true,
          icon: Icon(Icons.keyboard_arrow_down, size: 16, color: fg),
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: fg),
          dropdownColor: Colors.white,
          items: _statusOptions.map((s) {
            return DropdownMenuItem<String>(
              value: s,
              child: Text(s,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151))),
            );
          }).toList(),
          onChanged: (val) async {
            if (val == null || val == record.status) return;
            final err = await context
                .read<DisciplineController>()
                .updateStatus(record.id, val);
            if (err != null && context.mounted) {
              _showTopNotification('Ralat kemas kini status: $err', 'error');
            } else if (context.mounted) {
              _showTopNotification('Status berjaya dikemas kini kepada "$val".', 'success');
            }
          },
        ),
      ),
    );
  }

  // ── Delete confirmation ───────────────────────────────────────
  void _showDeleteConfirmation(BuildContext context, String recordId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Padam Rekod Disiplin'),
        content:
            const Text('Adakah anda pasti mahu memadamkan rekod disiplin ini secara kekal?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final res = await context
                  .read<DisciplineController>()
                  .deleteRecord(recordId);
              nav.pop();
              if (res != null && context.mounted) {
                _showTopNotification('Ralat memadam rekod: $res', 'error');
              } else if (context.mounted) {
                _showTopNotification('Rekod disiplin berjaya dipadam.', 'success');
              }
            },
            child: const Text('Padam',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ── Add / Edit Dialog ─────────────────────────────────────────
  void _showAddEditDialog(
    BuildContext context,
    DisciplineRecord? existing,
    UserModel? currentUser,
  ) {
    final isEdit = existing != null;
    final isAutoEdit = isEdit && existing.isAutoDetected;

    String? selStudentId = existing?.studentId;
    String matricVal = existing?.matricNo ?? '';
    String programVal = existing?.programme ?? '';

    if (!isEdit) {
      selStudentId = studentDetailsMap.keys.first;
      matricVal = studentDetailsMap[selStudentId]!['matric']!;
      programVal = studentDetailsMap[selStudentId]!['program']!;
    }

    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    final catatanCtrl = TextEditingController(text: existing?.catatan ?? '');

    String selCategory = existing?.category ?? 'Isu Kehadiran';
    String selSeverity = existing?.severity ?? 'Rendah';
    String selStatus = (existing != null &&
            _statusOptions.contains(existing.status))
        ? existing.status
        : 'Belum Selesai';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDS) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(isAutoEdit
                ? 'Kemas Kini Rekod Kehadiran Automatik'
                : isEdit
                    ? 'Kemas Kini Rekod Disiplin'
                    : 'Tambah Rekod Disiplin'),
            content: SizedBox(
              width: 570,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Info banner for auto-detected
                    if (isAutoEdit) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF7ED),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFE8D6)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Color(0xFFEA580C), size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Rekod ini dikesan secara automatik. Anda boleh kemaskini status, tahap keseriusan dan menambah catatan/pemerhatian.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF92400E),
                                    height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Student name
                    const Text('Nama Pelajar',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    if (isEdit)
                      _readonlyField(existing.studentName)
                    else
                      DropdownButtonFormField<String>(
                        initialValue: selStudentId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: studentDetailsMap.entries.map((e) {
                          return DropdownMenuItem<String>(
                            value: e.key,
                            child: SizedBox(width: double.infinity, child: Text(e.value['name']!, style: const TextStyle(fontSize: 13))),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val == null) return;
                          setDS(() {
                            selStudentId = val;
                            matricVal = studentDetailsMap[val]!['matric']!;
                            programVal = studentDetailsMap[val]!['program']!;
                          });
                        },
                      ),
                    const SizedBox(height: 12),

                    // Matric + Program
                    Row(children: [
                      Expanded(
                        child: _labeledReadonly('No. Matrik', matricVal),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _labeledReadonly('Program', programVal),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Category
                    const Text('Kategori Isu',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    if (isAutoEdit)
                      _readonlyField('Isu Kehadiran')
                    else
                      DropdownButtonFormField<String>(
                        initialValue: selCategory,
                        isExpanded: true,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.grey.shade50,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: _categories.where((c) => c != 'Semua').map((cat) {
                          return DropdownMenuItem<String>(
                            value: cat,
                            child: SizedBox(width: double.infinity, child: Text(cat, style: const TextStyle(fontSize: 13))),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setDS(() => selCategory = val);
                        },
                      ),
                    const SizedBox(height: 16),

                    // Title
                    const Text('Tajuk Isu',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    if (isAutoEdit)
                      _readonlyField(existing.title)
                    else
                      TextField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Masukkan tajuk ringkas amaran disiplin...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    const SizedBox(height: 16),

                    // Description
                    const Text('Keterangan Isu',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: descCtrl,
                      maxLines: 3,
                      readOnly: isAutoEdit,
                      style: TextStyle(
                          color:
                              isAutoEdit ? Colors.grey.shade600 : Colors.black87),
                      decoration: InputDecoration(
                        hintText: 'Keterangan lengkap tindakan atau pelanggaran...',
                        border: const OutlineInputBorder(),
                        filled: isAutoEdit,
                        fillColor: isAutoEdit ? Colors.grey.shade100 : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Catatan — editable for everyone including auto-detected
                    const Text('Catatan / Pemerhatian',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: catatanCtrl,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText:
                            'Cth: Amaran diberikan / Pelajar telah dihubungi / Sesi kaunseling dijalankan...',
                        hintStyle:
                            TextStyle(color: Colors.grey.shade400, fontSize: 12),
                        border: const OutlineInputBorder(),
                        prefixIcon: const Padding(
                          padding: EdgeInsets.only(left: 12, top: 12, bottom: 40),
                          child: Icon(Icons.comment_outlined,
                              color: Color(0xFF0284C7), size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Severity + Status dropdowns
                    Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Tahap Keseriusan',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              initialValue: selSeverity,
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey.shade50,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              ),
                               items: ['Rendah', 'Sederhana', 'Tinggi'].map((s) {
                                 return DropdownMenuItem<String>(
                                   value: s,
                                   child: SizedBox(width: double.infinity, child: Text(s, style: const TextStyle(fontSize: 13))),
                                 );
                               }).toList(),
                               onChanged: (val) {
                                 if (val != null) setDS(() => selSeverity = val);
                               },
                             ),
                           ],
                         ),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             const Text('Status Kes',
                                 style: TextStyle(
                                     fontWeight: FontWeight.bold, fontSize: 12)),
                             const SizedBox(height: 4),
                             DropdownButtonFormField<String>(
                               initialValue: selStatus,
                               isExpanded: true,
                               decoration: InputDecoration(
                                 filled: true,
                                 fillColor: Colors.grey.shade50,
                                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                 enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
                                 contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                               ),
                               items: _statusOptions.map((s) {
                                 return DropdownMenuItem<String>(
                                   value: s,
                                   child: SizedBox(width: double.infinity, child: Text(s, style: const TextStyle(fontSize: 13))),
                                 );
                               }).toList(),
                               onChanged: (val) {
                                 if (val != null) setDS(() => selStatus = val);
                               },
                             ),
                           ],
                         ),
                       ),
                     ]),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5)),
                onPressed: () async {
                  if (!isAutoEdit &&
                      (titleCtrl.text.trim().isEmpty ||
                          descCtrl.text.trim().isEmpty)) {
                    _showTopNotification(
                        'Sila isi semua ruangan penting.', 'error');
                    return;
                  }

                  final studentName =
                      studentDetailsMap[selStudentId]?['name'] ??
                          existing?.studentName ??
                          '';
                  final catatan = catatanCtrl.text.trim();

                  final record = DisciplineRecord(
                    id: isEdit ? existing.id : '',
                    studentId: selStudentId!,
                    studentName: studentName,
                    matricNo: matricVal,
                    programme: programVal,
                    category: isAutoEdit ? 'Isu Kehadiran' : selCategory,
                    title: isAutoEdit ? existing.title : titleCtrl.text.trim(),
                    description: isAutoEdit
                        ? existing.description
                        : descCtrl.text.trim(),
                    reportedDate:
                        isEdit ? existing.reportedDate : DateTime.now(),
                    severity: selSeverity,
                    status: selStatus,
                    reportedBy: isEdit
                        ? existing.reportedBy
                        : (currentUser?.name ?? 'Pengguna Portal'),
                    isAutoDetected: isEdit ? existing.isAutoDetected : false,
                    attendancePercentage: existing?.attendancePercentage,
                    catatan: catatan.isEmpty ? null : catatan,
                  );

                  final nav = Navigator.of(ctx);
                  String? err;
                  if (isEdit) {
                    err = await context
                        .read<DisciplineController>()
                        .updateRecord(record);
                  } else {
                    err = await context
                        .read<DisciplineController>()
                        .addRecord(record);
                  }

                  nav.pop();
                  if (err != null && context.mounted) {
                    _showTopNotification('Ralat menyimpan: $err', 'error');
                  } else if (context.mounted) {
                    _showTopNotification(
                      isEdit
                          ? 'Rekod berjaya dikemas kini.'
                          : 'Rekod baru berjaya ditambah.',
                      'success',
                    );
                  }
                },
                child: Text(isEdit ? 'Simpan' : 'Tambah',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        });
      },
    );
  }

  // ── Helpers ───────────────────────────────────────────────────
  Widget _badge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }

  Widget _readonlyField(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        value,
        style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey.shade700),
      ),
    );
  }

  Widget _labeledReadonly(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Text(value,
              style: TextStyle(color: Colors.grey.shade700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime dt) {
    final months = [
      'Jan','Feb','Mac','Apr','Mei','Jun',
      'Jul','Ogo','Sep','Okt','Nov','Dis'
    ];
    final d = dt.day.toString().padLeft(2, '0');
    final m = months[dt.month - 1];
    final y = dt.year;
    var h = dt.hour;
    final ampm = h >= 12 ? 'PM' : 'AM';
    h = h % 12;
    if (h == 0) h = 12;
    final hh = h.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d $m $y, $hh:$mm $ampm';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Floating Overlay Notification Banner
// ─────────────────────────────────────────────────────────────────────────────
class _NotificationBanner extends StatefulWidget {
  final String message;
  final String type; // 'success' | 'error'
  final VoidCallback onDismiss;

  const _NotificationBanner({
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<_NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _slide = Tween<double>(begin: -80, end: 0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.type == 'success';
    return Positioned(
      top: 24,
      left: 0,
      right: 0,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, child) => Opacity(
          opacity: _fade.value,
          child: Transform.translate(
            offset: Offset(0, _slide.value),
            child: child,
          ),
        ),
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isSuccess
                    ? const Color(0xFFDEF7EC)
                    : const Color(0xFFFDE8E8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSuccess
                      ? const Color(0xFFBCF0DA)
                      : const Color(0xFFFBD5D5),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isSuccess
                        ? Icons.check_circle_rounded
                        : Icons.error_rounded,
                    color: isSuccess
                        ? const Color(0xFF03543F)
                        : const Color(0xFF9B1C1C),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSuccess
                            ? const Color(0xFF03543F)
                            : const Color(0xFF9B1C1C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: isSuccess
                          ? const Color(0xFF03543F)
                          : const Color(0xFF9B1C1C),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
