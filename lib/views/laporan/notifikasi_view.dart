import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../controllers/notification_controller.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/discipline_controller.dart';
import '../../models/user_model.dart';
import '../../models/notification_model.dart';
import '../../views/admin/admin_shell.dart';
import '../../views/lecturer/lecturer_shell.dart';
import '../../views/ketua/ketua_shell.dart';
import 'widgets/notification_banner.dart';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class NotifikasiView extends StatelessWidget {
  const NotifikasiView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.currentUser;
    final role = user?.role ?? UserRole.pensyarah;

    final content = const _NotifikasiBody();

    if (role == UserRole.staff) {
      return AdminShell(
        currentRoute: '/admin/pelaporan/notifikasi',
        child: content,
      );
    }

    if (role == UserRole.pensyarah) {
      return LecturerShell(
        currentRoute: '/lecturer-pelaporan/notifikasi',
        child: content,
      );
    }

    return KetuaShell(
      currentRoute: '/ketua-pelaporan/notifikasi',
      child: content,
    );
  }
}

class _NotifikasiBody extends StatefulWidget {
  const _NotifikasiBody();

  @override
  State<_NotifikasiBody> createState() => _NotifikasiBodyState();
}

class _NotifikasiBodyState extends State<_NotifikasiBody> {
  OverlayEntry? _overlayEntry;

  @override
  void dispose() {
    _overlayEntry?.remove();
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

    Overlay.of(context).insert(entry);
    _overlayEntry = entry;

    Future.delayed(const Duration(seconds: 3), () {
      if (_overlayEntry == entry) {
        _overlayEntry?.remove();
        _overlayEntry = null;
      }
    });
  }

  void _showSuratAmaranDialog(NotificationRecord n) {
    final warningLabel = n.warningLabel ?? 'Amaran Kehadiran';
    final attendance = n.attendancePercentage?.toStringAsFixed(1) ?? '-';
    final today = DateTime.now();
    final dateStr = '${today.day}/${today.month}/${today.year}';
    final refNo = 'AMARAN/${n.matricNo}/${today.year}';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 80, vertical: 30),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Container(
            width: 720,
            constraints: const BoxConstraints(maxHeight: 760),
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Dokumen Surat Amaran',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDEF7EC),
                    border: Border.all(color: const Color(0xFFBCF0DA)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Color(0xFF03543F)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'E-mel amaran telah disediakan untuk pensyarah dan Ketua Program.',
                          style: TextStyle(
                            color: Color(0xFF03543F),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Center(
                            child: Column(
                              children: [
                                Text(
                                  'PORTAL AKADEMIK MARA',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Color(0xFF1F3A8A),
                                    letterSpacing: 1,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Bahagian Hal Ehwal Pelajar (HEP)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 12),
                                Divider(
                                  thickness: 2,
                                  color: Color(0xFF1F3A8A),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'No Ruj: $refNo',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Tarikh: $dateStr',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          const Text(
                            'Kepada/Untuk:',
                            style: TextStyle(
                              color: Colors.grey,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            n.studentName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            'No. Matrik: ${n.matricNo}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            'SURAT AMARAN KEHADIRAN: ${warningLabel.toUpperCase()}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text('Tuan/Puan,'),
                          const SizedBox(height: 16),
                          Text(
                            'Merujuk kepada perkara di atas, dimaklumkan bahawa rekod kehadiran anda bagi kursus ini telah mencapai tahap $warningLabel dengan peratus kehadiran semasa sebanyak $attendance%.',
                            textAlign: TextAlign.justify,
                            style: const TextStyle(height: 1.6),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Sehubungan itu, surat amaran ini dijana secara automatik oleh sistem bagi tujuan pemantauan dan tindakan lanjut. Pelajar dinasihatkan untuk memperbaiki kehadiran serta memberikan alasan yang munasabah sekiranya terdapat ketidakhadiran yang tidak dapat dielakkan.',
                            textAlign: TextAlign.justify,
                            style: TextStyle(height: 1.6),
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Kegagalan memperbaiki rekod kehadiran boleh menyebabkan tindakan akademik atau disiplin diambil mengikut peraturan institusi.',
                            textAlign: TextAlign.justify,
                            style: TextStyle(height: 1.6),
                          ),
                          const SizedBox(height: 28),
                          const Text('Sekian, terima kasih.'),
                          const SizedBox(height: 38),
                          const Text('Yang benar,'),
                          const SizedBox(height: 50),
                          const Text(
                            'Unit Akademik',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _downloadSuratAmaranPdf(n),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Muat Turun PDF'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.check_rounded),
                      label: const Text('Tutup'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8B1538),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _downloadSuratAmaranPdf(NotificationRecord n) async {
    final pdf = pw.Document();

    final warningLabel = n.warningLabel ?? 'Amaran Kehadiran';
    final attendance = n.attendancePercentage?.toStringAsFixed(1) ?? '-';
    final today = DateTime.now();
    final dateStr = '${today.day}/${today.month}/${today.year}';
    final refNo = 'AMARAN/${n.matricNo}/${today.year}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Column(
                  children: [
                    pw.Text(
                      'PORTAL AKADEMIK MARA',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text('Bahagian Hal Ehwal Pelajar (HEP)'),
                  ],
                ),
              ),
              pw.Divider(thickness: 2),
              pw.SizedBox(height: 20),

              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('No Ruj: $refNo'),
                  pw.Text('Tarikh: $dateStr'),
                ],
              ),

              pw.SizedBox(height: 25),
              pw.Text('Kepada/Untuk:'),
              pw.Text(n.studentName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('No. Matrik: ${n.matricNo}'),

              pw.SizedBox(height: 25),
              pw.Text(
                'SURAT AMARAN KEHADIRAN: ${warningLabel.toUpperCase()}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  decoration: pw.TextDecoration.underline,
                ),
              ),

              pw.SizedBox(height: 20),
              pw.Text('Tuan/Puan,'),
              pw.SizedBox(height: 12),

              pw.Text(
                'Merujuk kepada perkara di atas, dimaklumkan bahawa rekod kehadiran anda telah mencapai tahap $warningLabel dengan peratus kehadiran semasa sebanyak $attendance%.',
                textAlign: pw.TextAlign.justify,
              ),

              pw.SizedBox(height: 12),
              pw.Text(
                'Sehubungan itu, surat amaran ini dijana secara automatik oleh sistem bagi tujuan pemantauan dan tindakan lanjut. Pelajar dinasihatkan untuk memperbaiki kehadiran serta memberikan alasan yang munasabah sekiranya terdapat ketidakhadiran yang tidak dapat dielakkan.',
                textAlign: pw.TextAlign.justify,
              ),

              pw.SizedBox(height: 12),
              pw.Text(
                'Kegagalan memperbaiki rekod kehadiran boleh menyebabkan tindakan akademik atau disiplin diambil mengikut peraturan institusi.',
                textAlign: pw.TextAlign.justify,
              ),

              pw.SizedBox(height: 30),
              pw.Text('Sekian, terima kasih.'),
              pw.SizedBox(height: 40),
              pw.Text('Yang benar,'),
              pw.SizedBox(height: 45),
              pw.Text(
                'Unit Akademik',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          );
        },
      ),
    );

    final Uint8List bytes = await pdf.save();

    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute(
        'download',
        'Surat_Amaran_${n.matricNo}_${warningLabel.replaceAll(' ', '_')}.pdf',
      )
      ..click();

    html.Url.revokeObjectUrl(url);

    _showTopNotification('Surat amaran berjaya dimuat turun.', 'success');
  }

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
    final currentUser = context.watch<AuthController>().currentUser;
    final userId = currentUser?.id ?? '';
    final role = currentUser?.role ?? UserRole.pensyarah;
    final visibleItems = notifCtrl.visibleForUser(userId, role);

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Notifikasi',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Senarai notifikasi amaran kehadiran dan berkaitan disiplin.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: notifCtrl.isLoading
                ? const Center(child: CircularProgressIndicator())
                : visibleItems.isEmpty
                    ? Center(
                        child: Text(
                          'Tiada notifikasi.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: visibleItems.length,
                        itemBuilder: (ctx, i) {
                          final n = visibleItems[i];
                          final isRead =
                              userId.isNotEmpty && n.readBy.contains(userId);
                          final dateStr =
                              '${n.createdAt.day}/${n.createdAt.month}/${n.createdAt.year} ${n.createdAt.hour.toString().padLeft(2, '0')}:${n.createdAt.minute.toString().padLeft(2, '0')}';

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

                          final Future<List<String>> recipientFuture =
                              (() async {
                            final db = FirebaseFirestore.instance;
                            final List<String> names = [];

                            try {
                              if (n.recipientIds.isNotEmpty) {
                                for (final id in n.recipientIds) {
                                  final doc =
                                      await db.collection('users').doc(id).get();
                                  if (doc.exists) {
                                    final d = doc.data() ?? {};
                                    final name = (d['displayName'] ??
                                            d['name'] ??
                                            d['fullName'] ??
                                            d['email'] ??
                                            id)
                                        .toString();
                                    names.add(name);
                                  } else {
                                    names.add(id);
                                  }
                                }
                                return names;
                              }

                              return List<String>.from(n.recipients);
                            } catch (_) {
                              return n.recipients.isNotEmpty
                                  ? List<String>.from(n.recipients)
                                  : <String>[];
                            }
                          })();

                          final emailStatusText = n.emailStatus;
                          final isEmailSuccess =
                              emailStatusText == 'Berjaya Dihantar';

                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: isRead
                                    ? const Color(0xFFE5E7EB)
                                    : const Color(0xFF8B1538).withOpacity(0.3),
                                width: isRead ? 1 : 2,
                              ),
                            ),
                            color: isRead
                                ? Colors.white
                                : const Color(0xFFFFF5F5),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isRead
                                              ? Colors.grey.shade100
                                              : const Color(0xFFFFEAEA),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          isRead ? 'Dibaca' : 'Belum Dibaca',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: isRead
                                                ? Colors.grey.shade600
                                                : const Color(0xFFE53E3E),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          Icons.delete_outline,
                                          color: Colors.red.shade400,
                                          size: 20,
                                        ),
                                        tooltip: 'Padam Notifikasi',
                                        onPressed: () async {
                                          final confirmed =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (dctx) => AlertDialog(
                                              title:
                                                  const Text('Sahkan Padam'),
                                              content: const Text(
                                                'Adakah anda pasti mahu memadam notifikasi ini?',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(dctx)
                                                          .pop(false),
                                                  child: const Text('Batal'),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(dctx)
                                                          .pop(true),
                                                  child: const Text(
                                                    'Padam',
                                                    style: TextStyle(
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirmed == true) {
                                            final err = await context
                                                .read<NotificationController>()
                                                .deleteNotification(n.id);
                                            if (err == null) {
                                              _showTopNotification(
                                                'Notifikasi berjaya dipadam.',
                                                'success',
                                              );
                                            } else {
                                              _showTopNotification(
                                                'Gagal memadam notifikasi.',
                                                'error',
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  if (n.message != null &&
                                      n.message!.isNotEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDEF7EC),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFBCF0DA),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            color: Color(0xFF03543F),
                                            size: 18,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              n.message!,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                                color: Color(0xFF03543F),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const Divider(
                                    height: 24,
                                    color: Color(0xFFF3F4F6),
                                  ),
                                  Wrap(
                                    spacing: 24,
                                    runSpacing: 12,
                                    children: [
                                      _buildDetailItem(
                                        'Peratus Kehadiran',
                                        '${n.attendancePercentage?.toStringAsFixed(1) ?? '-'}%',
                                      ),
                                      _buildDetailItem(
                                        'Tahap Amaran',
                                        n.warningLabel ?? 'Tiada Amaran',
                                      ),
                                      _buildDetailItem('Kategori', n.category),
                                      _buildDetailItem('Tarikh', dateStr),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF9FAFB),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFF3F4F6),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Penerima Notifikasi:',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.grey.shade500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              FutureBuilder<List<String>>(
                                                future: recipientFuture,
                                                builder: (ctx2, snap) {
                                                  final text =
                                                      snap.connectionState ==
                                                              ConnectionState
                                                                  .done
                                                          ? (snap.data == null ||
                                                                  snap.data!
                                                                      .isEmpty
                                                              ? '-'
                                                              : snap.data!
                                                                  .join(', '))
                                                          : 'Memuat...';
                                                  return Text(
                                                    text,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Color(0xFF374151),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              'Status Emel:',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Row(
                                              children: [
                                                Icon(
                                                  isEmailSuccess
                                                      ? Icons
                                                          .check_circle_rounded
                                                      : Icons.error_rounded,
                                                  color: isEmailSuccess
                                                      ? Colors.green
                                                      : Colors.red,
                                                  size: 14,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  emailStatusText,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: isEmailSuccess
                                                        ? Colors.green.shade700
                                                        : Colors.red.shade700,
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
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Wrap(
                                      spacing: 8,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () =>
                                              _showSuratAmaranDialog(n),
                                          icon: const Icon(
                                            Icons.description_rounded,
                                            size: 16,
                                          ),
                                          label:
                                              const Text('Lihat Surat Amaran'),
                                        ),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            if (userId.isNotEmpty) {
                                              context
                                                  .read<
                                                      NotificationController>()
                                                  .markRead(n.id, userId);
                                            }

                                            context
                                                .read<DisciplineController>()
                                                .selectRecord(
                                                    n.disciplineRecordId);

                                            final role = context
                                                .read<AuthController>()
                                                .currentUser
                                                ?.role;

                                            if (role == UserRole.staff) {
                                              context.go('/admin/isu-disiplin');
                                            } else if (role ==
                                                UserRole.ketuaProgram) {
                                              context.go('/ketua-isu-disiplin');
                                            } else {
                                              context.go(
                                                  '/lecturer-isu-disiplin');
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.arrow_forward_rounded,
                                            size: 16,
                                          ),
                                          label: const Text('Lihat Rekod'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                const Color(0xFF8B1538),
                                            foregroundColor: Colors.white,
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                          ),
                                        ),
                                      ],
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
