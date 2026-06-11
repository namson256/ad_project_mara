import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/booking_controller.dart';
import '../../models/booking_model.dart';
import 'lecturer_shell.dart';

class LecturerBookingView extends StatefulWidget {
  const LecturerBookingView({super.key});

  @override
  State<LecturerBookingView> createState() => _LecturerBookingViewState();
}

class _LecturerBookingViewState extends State<LecturerBookingView> {
  String _filter = 'Semua'; // Semua, Menunggu, Diluluskan, Ditolak

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingController>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthController>();
    final booking = context.watch<BookingController>();
    final me      = auth.currentUser?.id ?? '';

    var myBookings = booking.forLecturer(me);
    if (_filter != 'Semua') {
      myBookings = myBookings.where((b) => b.status == _filter).toList();
    }

    return LecturerShell(
      currentRoute: '/lecturer-booking',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tempahan Bilik & Kelas Ganti',
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.w800)),
                      SizedBox(height: 4),
                      Text(
                          'Mohon tempahan bilik atau kelas ganti. Permohonan akan disemak oleh Ketua Program.',
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 14)),
                    ],
                  ),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF8B1538),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                  onPressed: () => _openCreateDialog(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Tempahan Baharu'),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Status summary cards ───────────────────────────────
            Row(
              children: [
                Expanded(child: _StatPill(
                  label: 'JUMLAH',
                  value: '${booking.forLecturer(me).length}',
                  color: const Color(0xFF8B1538),
                  bg: const Color(0xFFFDE8ED),
                  icon: Icons.event_available_outlined,
                )),
                const SizedBox(width: 12),
                Expanded(child: _StatPill(
                  label: 'MENUNGGU',
                  value: '${booking.forLecturer(me).where((b) => b.isPending).length}',
                  color: const Color(0xFFD97706),
                  bg: const Color(0xFFFEF3C7),
                  icon: Icons.schedule_outlined,
                )),
                const SizedBox(width: 12),
                Expanded(child: _StatPill(
                  label: 'DILULUSKAN',
                  value: '${booking.forLecturer(me).where((b) => b.isApproved).length}',
                  color: const Color(0xFF059669),
                  bg: const Color(0xFFD1FAE5),
                  icon: Icons.check_circle_outline,
                )),
                const SizedBox(width: 12),
                Expanded(child: _StatPill(
                  label: 'DITOLAK',
                  value: '${booking.forLecturer(me).where((b) => b.isRejected).length}',
                  color: const Color(0xFFDC2626),
                  bg: const Color(0xFFFEE2E2),
                  icon: Icons.cancel_outlined,
                )),
              ],
            ),

            const SizedBox(height: 24),

            // ── Filter chips ───────────────────────────────────────
            Wrap(
              spacing: 8,
              children: ['Semua', 'Menunggu', 'Diluluskan', 'Ditolak']
                  .map((s) => ChoiceChip(
                        label: Text(s),
                        selected: _filter == s,
                        onSelected: (_) => setState(() => _filter = s),
                        selectedColor: const Color(0xFFFDE8ED),
                        labelStyle: TextStyle(
                          color: _filter == s
                              ? const Color(0xFF8B1538)
                              : const Color(0xFF374151),
                          fontWeight: FontWeight.w600,
                        ),
                      ))
                  .toList(),
            ),

            const SizedBox(height: 16),

            // ── List ────────────────────────────────────────────────
            if (booking.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (myBookings.isEmpty)
              _EmptyState(filter: _filter,
                onCreate: () => _openCreateDialog(context))
            else
              ...myBookings.map((b) => _BookingCard(
                    booking: b,
                    onCancel: b.isPending
                        ? () => _confirmCancel(context, b)
                        : null,
                  )),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  void _openCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => const _CreateBookingDialog(),
    );
  }

  Future<void> _confirmCancel(BuildContext context, BookingModel b) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan tempahan?'),
        content: Text(
            'Tempahan untuk ${b.subject} pada ${_fmtDate(b.date)} akan dipadam.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Tidak')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Ya, batalkan')),
        ],
      ),
    );
    if (yes != true) return;
    final err =
        await context.read<BookingController>().cancelBooking(b.id);
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }
}

// ────────────────────────────────────────────────────────────────────
// Create dialog
// ────────────────────────────────────────────────────────────────────

class _CreateBookingDialog extends StatefulWidget {
  const _CreateBookingDialog();

  @override
  State<_CreateBookingDialog> createState() => _CreateBookingDialogState();
}

class _CreateBookingDialogState extends State<_CreateBookingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _venue = TextEditingController();
  final _programme = TextEditingController();
  final _subject = TextEditingController();
  final _purpose = TextEditingController();
  final _remarks = TextEditingController();

  String _type = BookingType.tempahanBilik;
  DateTime? _date;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _submitting = false;

  @override
  void dispose() {
    _venue.dispose();
    _programme.dispose();
    _subject.dispose();
    _purpose.dispose();
    _remarks.dispose();
    super.dispose();
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text('Tempahan Baharu',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
            ),
            const Divider(height: 1),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type
                      const _Label('Jenis Tempahan'),
                      DropdownButtonFormField<String>(
                        value: _type,
                        items: const [
                          DropdownMenuItem(
                              value: BookingType.tempahanBilik,
                              child: Text('Tempahan Bilik')),
                          DropdownMenuItem(
                              value: BookingType.kelasGanti,
                              child: Text('Kelas Ganti')),
                        ],
                        onChanged: (v) =>
                            setState(() => _type = v ?? _type),
                      ),
                      const SizedBox(height: 14),

                      // Venue
                      const _Label('Bilik / Venue'),
                      TextFormField(
                        controller: _venue,
                        decoration: const InputDecoration(
                            hintText: 'cth. BK-2, Lab Komputer 3'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Wajib diisi'
                                : null,
                      ),
                      const SizedBox(height: 14),

                      // Date + Start + End
                      Row(
                        children: [
                          Expanded(child: _DateField(
                            label: 'Tarikh',
                            value: _date,
                            onPick: (d) => setState(() => _date = d),
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: _TimeField(
                            label: 'Waktu Mula',
                            value: _startTime,
                            onPick: (t) => setState(() => _startTime = t),
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: _TimeField(
                            label: 'Waktu Tamat',
                            value: _endTime,
                            onPick: (t) => setState(() => _endTime = t),
                          )),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Programme
                      const _Label('Program / Kelas'),
                      TextFormField(
                        controller: _programme,
                        decoration: const InputDecoration(
                            hintText: 'cth. DSK 2A'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Wajib diisi'
                                : null,
                      ),
                      const SizedBox(height: 14),

                      // Subject
                      const _Label('Subjek'),
                      TextFormField(
                        controller: _subject,
                        decoration: const InputDecoration(
                            hintText: 'cth. Pengaturcaraan Mudah Alih'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Wajib diisi'
                                : null,
                      ),
                      const SizedBox(height: 14),

                      // Purpose
                      const _Label('Tujuan'),
                      TextFormField(
                        controller: _purpose,
                        decoration: const InputDecoration(
                            hintText:
                                'cth. Kuliah ganti untuk minggu ke-5'),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty)
                                ? 'Wajib diisi'
                                : null,
                      ),
                      const SizedBox(height: 14),

                      // Remarks
                      const _Label('Catatan (pilihan)'),
                      TextFormField(
                        controller: _remarks,
                        maxLines: 3,
                        decoration: const InputDecoration(
                            hintText: 'Maklumat tambahan untuk Ketua Program'),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1),

            // Footer buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Batal'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF8B1538),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                    ),
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Hantar Tempahan'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null) {
      _toast('Sila pilih tarikh.');
      return;
    }
    if (_startTime == null || _endTime == null) {
      _toast('Sila pilih waktu mula dan waktu tamat.');
      return;
    }

    setState(() => _submitting = true);

    final auth = context.read<AuthController>();
    final user = auth.currentUser;
    final err = await context.read<BookingController>().createBooking(
          lecturerId:   user?.id ?? '',
          lecturerName: user?.name ?? '',
          type:         _type,
          venue:        _venue.text,
          date:         _date!,
          startTime:    _fmtTime(_startTime!),
          endTime:      _fmtTime(_endTime!),
          programme:    _programme.text,
          subject:      _subject.text,
          purpose:      _purpose.text,
          remarks:      _remarks.text,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (err != null) {
      _toast(err);
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Tempahan dihantar. Menunggu kelulusan Ketua Program.'),
        backgroundColor: Color(0xFF059669),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }
}

// ────────────────────────────────────────────────────────────────────
// Sub-widgets
// ────────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w600)),
      );
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPick;
  const _DateField(
      {required this.label, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        InkWell(
          onTap: () async {
            final now = DateTime.now();
            final d = await showDatePicker(
              context: context,
              initialDate: value ?? now,
              firstDate: now,
              lastDate: now.add(const Duration(days: 365)),
            );
            if (d != null) onPick(d);
          },
          child: InputDecorator(
            decoration: const InputDecoration(),
            child: Text(
              value == null ? 'Pilih tarikh' : _fmtDate(value!),
              style: TextStyle(
                color: value == null
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF111827),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final TimeOfDay? value;
  final ValueChanged<TimeOfDay> onPick;
  const _TimeField(
      {required this.label, required this.value, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Label(label),
        InkWell(
          onTap: () async {
            final t = await showTimePicker(
              context: context,
              initialTime: value ?? TimeOfDay.now(),
            );
            if (t != null) onPick(t);
          },
          child: InputDecorator(
            decoration: const InputDecoration(),
            child: Text(
              value == null
                  ? 'Pilih waktu'
                  : '${value!.hour.toString().padLeft(2, '0')}:${value!.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                color: value == null
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF111827),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bg;
  final IconData icon;
  const _StatPill(
      {required this.label,
      required this.value,
      required this.color,
      required this.bg,
      required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(4)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.1,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onCancel;
  const _BookingCard({required this.booking, this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(booking.subject,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        _TypeBadge(type: booking.type),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                        '${booking.programme}  •  ${booking.venue}  •  ${_fmtDate(booking.date)}  •  ${booking.startTime}–${booking.endTime}',
                        style: const TextStyle(
                            color: Color(0xFF6B7280), fontSize: 13)),
                  ],
                ),
              ),
              _StatusBadge(status: booking.status),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          _Field('Tujuan', booking.purpose),
          if (booking.remarks.isNotEmpty) _Field('Catatan', booking.remarks),
          if (booking.reviewerNotes != null &&
              booking.reviewerNotes!.isNotEmpty)
            _Field(
                booking.isRejected
                    ? 'Sebab Penolakan'
                    : 'Nota Ketua Program',
                booking.reviewerNotes!,
                color: booking.isRejected
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF059669)),

          if (onCancel != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onCancel,
                style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626)),
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Batalkan'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _Field(this.label, this.value, {this.color});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(
                color: Color(0xFF374151), fontSize: 13, height: 1.4),
            children: [
              TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(
                  text: value,
                  style: TextStyle(color: color ?? const Color(0xFF374151))),
            ],
          ),
        ),
      );
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});
  @override
  Widget build(BuildContext context) {
    late final Color fg;
    late final Color bg;
    switch (status) {
      case BookingStatus.diluluskan:
        fg = const Color(0xFF059669); bg = const Color(0xFFD1FAE5); break;
      case BookingStatus.ditolak:
        fg = const Color(0xFFDC2626); bg = const Color(0xFFFEE2E2); break;
      default:
        fg = const Color(0xFFD97706); bg = const Color(0xFFFEF3C7);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(status,
          style: TextStyle(
              color: fg, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String type;
  const _TypeBadge({required this.type});
  @override
  Widget build(BuildContext context) {
    final isReplacement = type == BookingType.kelasGanti;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isReplacement
            ? const Color(0xFFFDE8ED)
            : const Color(0xFFE0F2FE),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(type,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: isReplacement
                  ? const Color(0xFF8B1538)
                  : const Color(0xFF0891B2))),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String filter;
  final VoidCallback onCreate;
  const _EmptyState({required this.filter, required this.onCreate});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_busy_outlined,
              size: 48, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 12),
          Text(
              filter == 'Semua'
                  ? 'Belum ada tempahan.'
                  : 'Tiada tempahan berstatus "$filter".',
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF6B7280))),
          if (filter == 'Semua') ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B1538)),
              onPressed: onCreate,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Cipta tempahan pertama anda'),
            ),
          ],
        ],
      ),
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';