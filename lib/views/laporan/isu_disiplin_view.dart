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
import 'widgets/notification_banner.dart';

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
  late final ScrollController _listScrollController;
  OverlayEntry? _overlayEntry;

  final List<String> _categories = [
    'Semua',
    'Isu Kehadiran',
    'Salah Laku Tingkah Laku',
    'Isu Akademik',
    'Pelanggaran Kod Pakaian',
    'Lain-lain',
  ];

  @override
  void initState() {
    super.initState();
    _listScrollController = ScrollController();
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _listScrollController.dispose();
    super.dispose();
  }

  void _showTopNotification(String message, String type) {
    _overlayEntry?.remove();
    _overlayEntry = null;

    final entry = OverlayEntry(
      builder: (_) => NotificationBanner(
        message: message,
        type: type,
        onDismiss: () {
          _overlayEntry?.remove();
          _overlayEntry = null;
        },
      ),
    );

    final overlay = Overlay.of(context);
    if (overlay != null) overlay.insert(entry);
    _overlayEntry = entry;

    Future.delayed(const Duration(seconds: 3), () {
      if (_overlayEntry == entry) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final role = user?.role ?? UserRole.pensyarah;
    final body = _buildBody(context, user);

    switch (role) {
      case UserRole.staff:
        return AdminShell(currentRoute: '/admin/isu-disiplin', child: body);
      case UserRole.pensyarah:
        return LecturerShell(currentRoute: '/lecturer-isu-disiplin', child: body);
      case UserRole.ketuaProgram:
        return KetuaShell(currentRoute: '/ketua-isu-disiplin', child: body);
    }
  }

  Widget _buildBody(BuildContext context, UserModel? user) {
    final disciplineCtrl = context.watch<DisciplineController>();
    final courseCtrl = context.watch<CourseController>();
    final attendanceCtrl = context.watch<AttendanceController>();

    final courses = courseCtrl.courses;
    final allRecords = disciplineCtrl.getCombinedRecords(courses, attendanceCtrl);
    final isReadOnly = user?.role == UserRole.ketuaProgram;

    // Handle auto-expansion requested from Notification View
    final selRecId = disciplineCtrl.selectedRecordId;
    if (selRecId != null) {
      final idx = allRecords.indexWhere((r) => r.id == selRecId);
      if (idx != -1) {
        final targetRecord = allRecords[idx];
        if (!_expandedStudentIds.contains(targetRecord.studentId)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _expandedStudentIds.add(targetRecord.studentId);
            });
          });
        }
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        disciplineCtrl.selectRecord(null);
      });
    }

    final Map<String, List<DisciplineRecord>> grouped = {};
    var filtered = allRecords;

    if (_selectedCategory != 'Semua') filtered = filtered.where((r) => r.category == _selectedCategory).toList();
    if (_onlyLowAttendance) filtered = filtered.where((r) => r.isAutoDetected).toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((r) => r.studentName.toLowerCase().contains(q) || r.matricNo.toLowerCase().contains(q) || r.title.toLowerCase().contains(q)).toList();
    }

    // Group records by studentId
    for (final r in filtered) {
      grouped.putIfAbsent(r.studentId, () => []).add(r);
    }

    // Sort records in each group by reportedDate descending
    for (final key in grouped.keys) {
      grouped[key]!.sort((a, b) => b.reportedDate.compareTo(a.reportedDate));
    }

    // Sort student IDs by the reportedDate of their latest record, descending
    final sortedStudentIds = grouped.keys.toList()
      ..sort((a, b) {
        final dateA = grouped[a]!.first.reportedDate;
        final dateB = grouped[b]!.first.reportedDate;
        return dateB.compareTo(dateA);
      });

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Header
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
            SizedBox(height: 6),
            Text('Pengurusan Isu Disiplin Pelajar', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
            SizedBox(height: 6),
          ])),
          ElevatedButton.icon(
            onPressed: () => setState(() => _onlyLowAttendance = !_onlyLowAttendance),
            icon: Icon(_onlyLowAttendance ? Icons.filter_alt_off_outlined : Icons.filter_alt_outlined),
            label: const Text('Amaran Kehadiran Automatik'),
          ),
          if (!isReadOnly) ...[
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _showAddEditDialog(context, null, user),
              icon: const Icon(Icons.add),
              label: const Text('Tambah Rekod'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B1538),
                foregroundColor: Colors.white,
              ),
            ),
          ]
        ]),

        const SizedBox(height: 18),

        // Category cards
        SizedBox(
          height: 94,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _categories.length,
            itemBuilder: (context, index) {
              final cat = _categories[index];
              final isSelected = _selectedCategory == cat;
              final count = filtered.where((r) => r.category == cat || cat == 'Semua').length;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () => setState(() => _selectedCategory = cat),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    width: 170,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF8B1538) : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isSelected ? Colors.transparent : const Color(0xFFE5E7EB)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(cat, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : const Color(0xFF374151))),
                      const SizedBox(height: 4),
                      Text('$count Rekod', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isSelected ? Colors.white70 : Colors.grey.shade500)),
                    ]),
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(height: 20),

        // Search bar
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4), side: const BorderSide(color: Color(0xFFE5E7EB))),
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

        const SizedBox(height: 16),

        // Records list grouped by student
        Expanded(
          child: sortedStudentIds.isEmpty
              ? Center(child: Text('Tiada rekod isu disiplin ditemui.', style: TextStyle(color: Colors.grey.shade600)))
              : ListView.builder(
                  controller: _listScrollController,
                  itemCount: sortedStudentIds.length,
                  itemBuilder: (ctx, idx) {
                    final sid = sortedStudentIds[idx];
                    final recs = grouped[sid]!;
                    final first = recs.first;
                    final expanded = _expandedStudentIds.contains(sid);
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      color: Colors.white,
                      child: Column(
                        children: [
                          ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF8B1538).withOpacity(0.1),
                              foregroundColor: const Color(0xFF8B1538),
                              child: Text(first.studentName.isNotEmpty ? first.studentName[0].toUpperCase() : 'S'),
                            ),
                            title: Text(
                              first.studentName,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF111827)),
                            ),
                            subtitle: Text(
                              'Matrik: ${first.matricNo} • ${first.programme}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${recs.length} Kes',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                              ],
                            ),
                            onTap: () => setState(() => expanded ? _expandedStudentIds.remove(sid) : _expandedStudentIds.add(sid)),
                          ),
                          if (expanded)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                children: [
                                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
                                  const SizedBox(height: 12),
                                  ...recs.map((r) => _historyTile(r, isReadOnly, user)).toList(),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  Widget _historyTile(DisciplineRecord r, bool isReadOnly, UserModel? currentUser) {
    final discCtrl = context.read<DisciplineController>();
    final formattedDate = '${r.reportedDate.day}/${r.reportedDate.month}/${r.reportedDate.year} ${r.reportedDate.hour.toString().padLeft(2, '0')}:${r.reportedDate.minute.toString().padLeft(2, '0')}';
    final isAuto = r.isAutoDetected;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B1538).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  r.category,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B1538),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAuto ? const Color(0xFFEBF5FF) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isAuto ? 'Dikesan Secara Automatik' : 'Manual',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isAuto ? Colors.blue.shade800 : Colors.grey.shade700,
                  ),
                ),
              ),
              const Spacer(),
              InlineStatusDropdown(
                status: r.status,
                isReadOnly: isReadOnly,
                onChanged: (newStatus) async {
                  final err = await discCtrl.updateStatus(r.id, newStatus);
                  if (err != null) {
                    _showTopNotification('Gagal mengemas kini rekod.', 'error');
                  } else {
                    _showTopNotification('Rekod berjaya dikemas kini.', 'success');
                    setState(() {});
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            r.title,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
          ),
          const SizedBox(height: 4),
          Text(
            r.description,
            style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), height: 1.4),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _buildFieldInfo('Nama Pelajar', r.studentName),
              _buildFieldInfo('No. Matrik', r.matricNo),
              _buildFieldInfo('Program', r.programme),
              _buildFieldInfo('Tarikh Laporan', formattedDate),
              _buildFieldInfo('Tahap Keseriusan', r.severity),
              if (r.warningLabel != null && r.warningLabel!.isNotEmpty)
                _buildFieldInfo('Tahap Amaran', r.warningLabel!),
              _buildFieldInfo('Dilaporkan Oleh', r.reportedBy),
            ],
          ),
          const Divider(height: 24, color: Color(0xFFF3F4F6)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Catatan / Tindakan:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (r.catatan == null || r.catatan!.trim().isEmpty)
                          ? 'Tiada catatan dimasukkan.'
                          : r.catatan!,
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: (r.catatan == null || r.catatan!.trim().isEmpty) ? FontStyle.italic : FontStyle.normal,
                        color: (r.catatan == null || r.catatan!.trim().isEmpty) ? Colors.grey.shade500 : const Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isReadOnly) ...[
                IconButton(
                  icon: const Icon(Icons.note_add_outlined, size: 20, color: Color(0xFF8B1538)),
                  tooltip: 'Tambah Catatan',
                  onPressed: () => _showCatatanDialog(context, r),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20, color: Colors.blue),
                  tooltip: 'Edit Rekod',
                  onPressed: () => _showAddEditDialog(context, r, currentUser),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  tooltip: 'Padam Rekod',
                  onPressed: () => _confirmDeleteRecord(context, r),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFieldInfo(String label, String value) {
    return SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151)), overflow: TextOverflow.ellipsis, maxLines: 2),
        ],
      ),
    );
  }

  Future<void> _showCatatanDialog(BuildContext context, DisciplineRecord r) async {
    final notesCtrl = TextEditingController(text: r.catatan ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kemas Kini Catatan Disiplin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pelajar: ${r.studentName}', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Catatan / Tindakan diambil',
                hintText: 'Contoh: Pelajar telah dihubungi, Sesi kaunseling dijalankan...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF111827), foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final discCtrl = context.read<DisciplineController>();
      final updated = r.copyWith(catatan: notesCtrl.text.trim());
      final err = await discCtrl.updateRecord(updated);
      if (err != null) {
        _showTopNotification('Gagal mengemas kini rekod.', 'error');
      } else {
        _showTopNotification('Rekod berjaya dikemas kini.', 'success');
        setState(() {});
      }
    }
  }

  Future<void> _confirmDeleteRecord(BuildContext context, DisciplineRecord r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Padam Rekod Disiplin'),
        content: Text('Anda pasti untuk memadam rekod "${r.title}" untuk pelajar ${r.studentName}?'),
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

    if (ok == true) {
      final discCtrl = context.read<DisciplineController>();
      final err = await discCtrl.deleteRecord(r.id);
      if (err != null) {
        _showTopNotification('Gagal memadam rekod.', 'error');
      } else {
        _showTopNotification('Rekod berjaya dipadam.', 'success');
        setState(() {});
      }
    }
  }

  Future<void> _showAddEditDialog(BuildContext context, DisciplineRecord? existing, UserModel? currentUser) async {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    String selSeverity = existing?.severity ?? 'Rendah';
    String selStatus = existing?.status ?? 'Belum Selesai';

    String? selStudentId = existing?.studentId;
    if (!isEdit) {
      selStudentId = studentDetailsMap.keys.first;
    }

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        String currentStudentId = selStudentId ?? studentDetailsMap.keys.first;
        String currentSeverity = selSeverity;
        String currentStatus = selStatus;
        String currentCategory = existing?.category ?? 'Isu Kehadiran';

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentStudent = studentDetailsMap[currentStudentId]!;

            return AlertDialog(
              title: Text(isEdit ? 'Kemas Kini Rekod Disiplin' : 'Tambah Rekod Disiplin'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isEdit) ...[
                      DropdownButtonFormField<String>(
                        value: currentStudentId,
                        decoration: const InputDecoration(labelText: 'Nama Pelajar'),
                        onChanged: (v) {
                          if (v != null) {
                            setDialogState(() {
                              currentStudentId = v;
                            });
                          }
                        },
                        items: studentDetailsMap.entries.map((e) {
                          return DropdownMenuItem(
                            value: e.key,
                            child: Text(e.value['name'] ?? ''),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: TextEditingController(text: currentStudent['matric'] ?? ''),
                        decoration: const InputDecoration(labelText: 'No. Matrik (Automata)'),
                        readOnly: true,
                        enabled: false,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: TextEditingController(text: currentStudent['program'] ?? ''),
                        decoration: const InputDecoration(labelText: 'Program (Automata)'),
                        readOnly: true,
                        enabled: false,
                      ),
                      const SizedBox(height: 8),
                    ] else ...[
                      Text('Pelajar: ${existing.studentName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('No. Matrik: ${existing.matricNo}', style: const TextStyle(color: Colors.grey)),
                      const SizedBox(height: 12),
                    ],
                    DropdownButtonFormField<String>(
                      value: currentCategory,
                      decoration: const InputDecoration(labelText: 'Kategori'),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() {
                            currentCategory = v;
                          });
                        }
                      },
                      items: _categories.where((c) => c != 'Semua').map((c) {
                        return DropdownMenuItem(value: c, child: Text(c));
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(labelText: 'Tajuk Isu'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(labelText: 'Keterangan'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: currentSeverity,
                      decoration: const InputDecoration(labelText: 'Tahap Keseriusan'),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() {
                            currentSeverity = v;
                          });
                        }
                      },
                      items: ['Rendah', 'Sederhana', 'Tinggi'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: currentStatus,
                      decoration: const InputDecoration(labelText: 'Status'),
                      onChanged: (v) {
                        if (v != null) {
                          setDialogState(() {
                            currentStatus = v;
                          });
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'Belum Selesai', child: Text('Belum Selesai')),
                        DropdownMenuItem(value: 'Selesai', child: Text('Selesai')),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF111827), foregroundColor: Colors.white),
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) {
                      return;
                    }
                    final discCtrl = context.read<DisciplineController>();

                    final record = DisciplineRecord(
                      id: isEdit ? existing.id : '',
                      studentId: currentStudentId,
                      studentName: isEdit ? existing.studentName : (studentDetailsMap[currentStudentId]?['name'] ?? ''),
                      matricNo: isEdit ? existing.matricNo : (studentDetailsMap[currentStudentId]?['matric'] ?? ''),
                      programme: isEdit ? existing.programme : (studentDetailsMap[currentStudentId]?['program'] ?? ''),
                      category: currentCategory,
                      title: titleCtrl.text.trim(),
                      description: descCtrl.text.trim(),
                      reportedDate: isEdit ? existing.reportedDate : DateTime.now(),
                      severity: currentSeverity,
                      status: currentStatus,
                      reportedBy: currentUser?.name ?? existing?.reportedBy ?? 'Pengguna Portal',
                      isAutoDetected: isEdit ? existing.isAutoDetected : false,
                      catatan: existing?.catatan,
                      warningLevel: existing?.warningLevel,
                      warningLabel: existing?.warningLabel,
                    );

                    String? err;
                    if (isEdit) {
                      err = await discCtrl.updateRecord(record);
                    } else {
                      err = await discCtrl.addRecord(record);
                    }

                    if (err != null) {
                      _showTopNotification('Gagal mengemas kini rekod.', 'error');
                      Navigator.pop(ctx, false);
                    } else {
                      _showTopNotification(
                        isEdit ? 'Rekod berjaya dikemas kini.' : 'Rekod berjaya ditambah.',
                        'success',
                      );
                      Navigator.pop(ctx, true);
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );

    if (res == true) setState(() {});
  }
}

class InlineStatusDropdown extends StatefulWidget {
  final String status;
  final ValueChanged<String> onChanged;
  final bool isReadOnly;

  const InlineStatusDropdown({
    super.key,
    required this.status,
    required this.onChanged,
    required this.isReadOnly,
  });

  @override
  State<InlineStatusDropdown> createState() => _InlineStatusDropdownState();
}

class _InlineStatusDropdownState extends State<InlineStatusDropdown> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final statusColor = widget.status == 'Selesai' ? const Color(0xFFDEF7EC) : const Color(0xFFFDE8E8);
    final textColor = widget.status == 'Selesai' ? const Color(0xFF03543F) : const Color(0xFF9B1C1C);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: widget.isReadOnly
              ? null
              : () => setState(() => _isOpen = !_isOpen),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: textColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.status,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                if (!widget.isReadOnly) ...[
                  const SizedBox(width: 4),
                  Icon(
                    _isOpen ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 16,
                    color: textColor,
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_isOpen && !widget.isReadOnly) ...[
          const SizedBox(height: 4),
          Container(
            width: 130,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildOption('Belum Selesai'),
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                _buildOption('Selesai'),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOption(String value) {
    final isSelected = widget.status == value;
    return InkWell(
      onTap: () {
        setState(() => _isOpen = false);
        widget.onChanged(value);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: isSelected ? const Color(0xFFF3F4F6) : Colors.transparent,
        child: Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}
