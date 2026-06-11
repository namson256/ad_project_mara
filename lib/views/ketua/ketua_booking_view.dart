import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../controllers/auth_controller.dart';
import '../../controllers/booking_controller.dart';
import '../../controllers/timetable_controller.dart';
import '../../models/booking_model.dart';
import 'ketua_shell.dart';

class KetuaBookingView extends StatefulWidget {
  const KetuaBookingView({super.key});

  @override
  State<KetuaBookingView> createState() => _KetuaBookingViewState();
}

class _KetuaBookingViewState extends State<KetuaBookingView> {
  String _filter = 'Menunggu'; // default: show pending first

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookingController>().loadAll();
      context.read<TimetableController>().loadSlots();
    });
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<BookingController>();
    var all = booking.bookings;
    if (_filter != 'Semua') {
      all = all.where((b) => b.status == _filter).toList();
    }

    return KetuaShell(
      currentRoute: '/ketua-booking',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────
            const Text('Semakan Tempahan',
                style:
                    TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text(
                'Lulus atau tolak permohonan tempahan bilik dan kelas ganti daripada pensyarah.',
                style: TextStyle(color: Color(0xFF6B7280), fontSize: 14)),

            const SizedBox(height: 24),

            // ── Status summary ─────────────────────────────────────
            Row(
              children: [
                Expanded(child: _StatPill(
                  label: 'MENUNGGU',
                  value: '${booking.pending.length}',
                  color: const Color(0xFFD97706),
                  bg: const Color(0xFFFEF3C7),
                  icon: Icons.schedule_outlined,
                )),
                const SizedBox(width: 12),
                Expanded(child: _StatPill(
                  label: 'DILULUSKAN',
                  value: '${booking.approved.length}',
                  color: const Color(0xFF059669),
                  bg: const Color(0xFFD1FAE5),
                  icon: Icons.check_circle_outline,
                )),
                const SizedBox(width: 12),
                Expanded(child: _StatPill(
                  label: 'DITOLAK',
                  value: '${booking.rejected.length}',
                  color: const Color(0xFFDC2626),
                  bg: const Color(0xFFFEE2E2),
                  icon: Icons.cancel_outlined,
                )),
                const SizedBox(width: 12),
                Expanded(child: _StatPill(
                  label: 'KELAS GANTI',
                  value:
                      '${booking.approvedReplacements.length}',
                  color: const Color(0xFF8B1538),
                  bg: const Color(0xFFFDE8ED),
                  icon: Icons.swap_horiz_outlined,
                )),
              ],
            ),

            const SizedBox(height: 24),

            // ── Filter chips ───────────────────────────────────────
            Wrap(
              spacing: 8,
              children: ['Menunggu', 'Diluluskan', 'Ditolak', 'Semua']
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

            // ── List ───────────────────────────────────────────────
            if (booking.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (all.isEmpty)
              _EmptyState(filter: _filter)
            else
              ...all.map((b) => _BookingReviewCard(
                    booking: b,
                    onApprove: b.isPending
                        ? () => _handleApprove(context, b)
                        : null,
                    onReject: b.isPending
                        ? () => _handleReject(context, b)
                        : null,
                  )),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Future<void> _handleApprove(
      BuildContext context, BookingModel booking) async {
    final timetable = context.read<TimetableController>();
    final auth = context.read<AuthController>();
    final bookingCtrl = context.read<BookingController>();

    // Pre-check conflict so we can show it before opening dialog
    final preCheck = bookingCtrl.detectConflict(
      venue:     booking.venue,
      date:      booking.date,
      startTime: booking.startTime,
      endTime:   booking.endTime,
      slots:     timetable.slots,
      excludeBookingId: booking.id,
    );

    final notesCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Luluskan tempahan?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Subjek: ${booking.subject}'),
              Text(
                  'Tarikh: ${_fmtDate(booking.date)} ${booking.startTime}–${booking.endTime}'),
              Text('Bilik: ${booking.venue}'),
              const SizedBox(height: 12),
              if (preCheck != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE2E2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_outlined,
                          color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(preCheck,
                              style: const TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontWeight: FontWeight.w600))),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1FAE5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle_outline,
                          color: Color(0xFF059669), size: 18),
                      SizedBox(width: 8),
                      Expanded(
                          child: Text('Tiada konflik dikesan.',
                              style: TextStyle(
                                  color: Color(0xFF059669),
                                  fontWeight: FontWeight.w600))),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              const Text('Nota (pilihan):',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: notesCtrl,
                decoration: const InputDecoration(
                  hintText: 'Nota tambahan untuk pensyarah',
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF059669)),
            onPressed: preCheck != null
                ? null // disable approve when conflict exists
                : () => Navigator.pop(context, true),
            child: const Text('Luluskan'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final err = await bookingCtrl.approveBooking(
      bookingId:      booking.id,
      reviewerId:     auth.currentUser?.id ?? '',
      notes:          notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
      timetableSlots: timetable.slots,
    );

    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tempahan diluluskan.'),
        backgroundColor: Color(0xFF059669),
      ));
    }
  }

  Future<void> _handleReject(
      BuildContext context, BookingModel booking) async {
    final auth = context.read<AuthController>();
    final bookingCtrl = context.read<BookingController>();
    final reasonCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tolak tempahan?'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tempahan: ${booking.subject}'),
              Text('Pensyarah: ${booking.lecturerName}'),
              const SizedBox(height: 12),
              const Text('Sebab penolakan (wajib):',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  hintText: 'Berikan sebab kepada pensyarah',
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );

    if (ok != true || !mounted) return;

    final err = await bookingCtrl.rejectBooking(
      bookingId:  booking.id,
      reviewerId: auth.currentUser?.id ?? '',
      reason:     reasonCtrl.text,
    );

    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tempahan ditolak.'),
        backgroundColor: Color(0xFFDC2626),
      ));
    }
  }
}

// ────────────────────────────────────────────────────────────────────
// Widgets
// ────────────────────────────────────────────────────────────────────

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

class _BookingReviewCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  const _BookingReviewCard({
    required this.booking,
    this.onApprove,
    this.onReject,
  });

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
          // Title + status badge
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
                    Text('oleh ${booking.lecturerName}',
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

          // Detail grid
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              _Detail('Bilik', booking.venue),
              _Detail('Tarikh', _fmtDate(booking.date)),
              _Detail(
                  'Waktu', '${booking.startTime} – ${booking.endTime}'),
              _Detail('Program / Kelas', booking.programme),
            ],
          ),

          const SizedBox(height: 12),
          _Field('Tujuan', booking.purpose),
          if (booking.remarks.isNotEmpty)
            _Field('Catatan', booking.remarks),
          if (booking.reviewerNotes != null &&
              booking.reviewerNotes!.isNotEmpty)
            _Field(
                booking.isRejected
                    ? 'Sebab Penolakan'
                    : 'Nota Ketua',
                booking.reviewerNotes!,
                color: booking.isRejected
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF059669)),

          if (onApprove != null && onReject != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                  ),
                  icon: const Icon(Icons.close, size: 16),
                  label: const Text('Tolak'),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: onApprove,
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF059669)),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Luluskan'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final String label;
  final String value;
  const _Detail(this.label, this.value);
  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      );
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
        borderRadius: BorderRadius.circular(4),
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
  const _EmptyState({required this.filter});
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
          const Icon(Icons.inbox_outlined,
              size: 48, color: Color(0xFF9CA3AF)),
          const SizedBox(height: 12),
          Text(
              filter == 'Semua'
                  ? 'Belum ada tempahan direkodkan.'
                  : 'Tiada tempahan berstatus "$filter".',
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF6B7280))),
        ],
      ),
    );
  }
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';