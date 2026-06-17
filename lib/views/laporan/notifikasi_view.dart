import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../controllers/notification_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/discipline_controller.dart';
import '../../models/user_model.dart';
import '../../views/admin/admin_shell.dart';
import '../../views/lecturer/lecturer_shell.dart';
import '../../views/ketua/ketua_shell.dart';

class NotifikasiView extends StatelessWidget {
  const NotifikasiView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final role = user?.role ?? UserRole.pensyarah;

    final content = const _NotifikasiBody();

    if (role == UserRole.staff) return AdminShell(currentRoute: '/admin/pelaporan/notifikasi', child: content);
    if (role == UserRole.pensyarah) return LecturerShell(currentRoute: '/lecturer-pelaporan/notifikasi', child: content);
    return KetuaShell(currentRoute: '/ketua-pelaporan/notifikasi', child: content);
  }
}

class _NotifikasiBody extends StatelessWidget {
  const _NotifikasiBody();

  Widget _buildDetailItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF374151),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifCtrl = context.watch<NotificationController>();
    final userId = context.watch<AuthController>().currentUser?.id ?? '';

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Notifikasi', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Senarai notifikasi amaran kehadiran dan berkaitan disiplin.', style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          Expanded(
            child: notifCtrl.isLoading
                ? const Center(child: CircularProgressIndicator())
                : notifCtrl.items.isEmpty
                    ? Center(child: Text('Tiada notifikasi.', style: TextStyle(color: Colors.grey.shade600)))
                    : ListView.builder(
                        itemCount: notifCtrl.items.length,
                        itemBuilder: (ctx, i) {
                          final n = notifCtrl.items[i];
                          final isRead = userId.isNotEmpty && n.readBy.contains(userId);
                          final dateStr = '${n.createdAt.day}/${n.createdAt.month}/${n.createdAt.year} ${n.createdAt.hour.toString().padLeft(2, '0')}:${n.createdAt.minute.toString().padLeft(2, '0')}';
                          
                          Color iconColor;
                          switch (n.warningLevel) {
                            case 1:
                              iconColor = Colors.orange.shade600;
                              break;
                            case 2:
                              iconColor = Colors.deepOrange.shade600;
                              break;
                            case 3:
                              iconColor = Colors.red.shade600;
                              break;
                            default:
                              iconColor = Colors.grey;
                          }

                          // Resolve recipient display names. Handle both new docs (recipientIds) and legacy docs
                          final Future<List<String>> _recipientFuture = (() async {
                            final db = FirebaseFirestore.instance;
                            final List<String> names = [];
                            try {
                              if (n.recipientIds.isNotEmpty) {
                                for (final id in n.recipientIds) {
                                  try {
                                    final doc = await db.collection('users').doc(id).get();
                                    if (doc.exists) {
                                      final d = doc.data() ?? {};
                                      final name = (d['displayName'] ?? d['name'] ?? d['fullName'] ?? d['email'] ?? id).toString();
                                      names.add(name);
                                    } else {
                                      names.add(id);
                                    }
                                  } catch (_) {
                                    names.add(id);
                                  }
                                }
                                return names;
                              }

                              // Legacy: recipients array might contain user IDs (garbled) or names/emails.
                              for (final rec in n.recipients) {
                                if (rec == null) continue;
                                final s = rec.toString();
                                final looksLikeId = !s.contains('@') && s.length >= 8; // heuristic
                                if (looksLikeId) {
                                  try {
                                    final doc = await db.collection('users').doc(s).get();
                                    if (doc.exists) {
                                      final d = doc.data() ?? {};
                                      final name = (d['displayName'] ?? d['name'] ?? d['fullName'] ?? d['email'] ?? s).toString();
                                      names.add(name);
                                      continue;
                                    }
                                  } catch (_) {
                                    // fallthrough to add raw
                                  }
                                }
                                names.add(s);
                              }
                              return names;
                            } catch (_) {
                              return n.recipients.isNotEmpty ? List<String>.from(n.recipients) : <String>[];
                            }
                          })();
                          
                          final emailStatusText = n.emailStatus;
                          final isEmailSuccess = emailStatusText == 'Berjaya Dihantar';

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isRead ? const Color(0xFFE5E7EB) : const Color(0xFF8B1538).withOpacity(0.3),
                                width: isRead ? 1 : 2,
                              ),
                            ),
                            color: isRead ? Colors.white : const Color(0xFFFFF5F5),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: iconColor.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.warning_amber_rounded,
                                          color: iconColor,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              n.studentName,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF111827),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'No. Matrik: ${n.matricNo}',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: isRead ? Colors.grey.shade100 : const Color(0xFFFFEAEA),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          isRead ? 'Dibaca' : 'Belum Dibaca',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isRead ? Colors.grey.shade600 : const Color(0xFFE53E3E),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Delete button
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(Icons.delete_outline, color: Colors.red.shade400, size: 20),
                                        tooltip: 'Padam Notifikasi',
                                        onPressed: () async {
                                          final confirmed = await showDialog<bool>(
                                            context: context,
                                            builder: (dctx) => AlertDialog(
                                              title: const Text('Sahkan Padam'),
                                              content: const Text('Adakah anda pasti mahu memadam notifikasi ini?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.of(dctx).pop(false), child: const Text('Batal')),
                                                TextButton(onPressed: () => Navigator.of(dctx).pop(true), child: const Text('Padam', style: TextStyle(color: Colors.red))),
                                              ],
                                            ),
                                          );
                                          if (confirmed == true) {
                                            final err = await context.read<NotificationController>().deleteNotification(n.id);
                                            if (err == null) {
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notifikasi dipadam.'), duration: Duration(seconds: 2)));
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal memadam: $err'), backgroundColor: Colors.redAccent));
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24, color: Color(0xFFF3F4F6)),
                                  
                                  // Details Row
                                  Wrap(
                                    spacing: 24,
                                    runSpacing: 12,
                                    children: [
                                      _buildDetailItem('Peratus Kehadiran', '${n.attendancePercentage?.toStringAsFixed(1) ?? '-'}%'),
                                      _buildDetailItem('Tahap Amaran', n.warningLabel ?? 'Tiada Amaran'),
                                      _buildDetailItem('Kategori', n.category),
                                      _buildDetailItem('Tarikh', dateStr),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Recipients & Email Status
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: const Color(0xFFF3F4F6)),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Penerima Notifikasi:',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                                              ),
                                              const SizedBox(height: 2),
                                              FutureBuilder<List<String>>(
                                                future: _recipientFuture,
                                                builder: (ctx2, snap) {
                                                  final text = snap.connectionState == ConnectionState.done
                                                      ? (snap.data == null || snap.data!.isEmpty ? '-' : snap.data!.join(', '))
                                                      : 'Memuat...';
                                                  return Text(
                                                    text,
                                                    style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w600),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Status Emel:',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(
                                                  isEmailSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                                                  color: isEmailSuccess ? Colors.green : Colors.red,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  emailStatusText,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: isEmailSuccess ? Colors.green.shade700 : Colors.red.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Notification message styled like top success banner in Isu Disiplin
                                  if (n.message != null && n.message!.isNotEmpty) ...[
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE6FFFA),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 20),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              n.message!,
                                              style: TextStyle(fontSize: 13, color: Colors.green.shade800, fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                  ],
                                  
                                  // Lihat Rekod Button
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        // Mark as read
                                        if (userId.isNotEmpty) {
                                          context.read<NotificationController>().markRead(n.id, userId);
                                        }
                                        // Select record in controller
                                        context.read<DisciplineController>().selectRecord(n.disciplineRecordId);
                                        // Navigate to Isu Disiplin
                                        final role = context.read<AuthController>().currentUser?.role;
                                        if (role == UserRole.staff) {
                                          context.go('/admin/isu-disiplin');
                                        } else if (role == UserRole.ketuaProgram) {
                                          context.go('/ketua-isu-disiplin');
                                        } else {
                                          context.go('/lecturer-isu-disiplin');
                                        }
                                      },
                                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                                      label: const Text('Lihat Rekod'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF8B1538),
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
