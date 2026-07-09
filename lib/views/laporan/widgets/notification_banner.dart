import 'package:flutter/material.dart';

class NotificationBanner extends StatefulWidget {
  final String message;
  final String type;
  final VoidCallback onDismiss;

  const NotificationBanner({
    super.key,
    required this.message,
    required this.type,
    required this.onDismiss,
  });

  @override
  State<NotificationBanner> createState() => _NotificationBannerState();
}

class _NotificationBannerState extends State<NotificationBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slide = Tween<double>(begin: -80, end: 0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _fade = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
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
        builder: (ctx, child) {
          return Opacity(
            opacity: _fade.value,
            child: Transform.translate(
              offset: Offset(0, _slide.value),
              child: child,
            ),
          );
        },
        child: Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isSuccess ? const Color(0xFFDEF7EC) : const Color(0xFFFDE8E8),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isSuccess ? const Color(0xFFBCF0DA) : const Color(0xFFFBD5D5)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.10), blurRadius: 20, offset: const Offset(0, 6))],
              ),
              child: Row(
                children: [
                  Icon(
                    isSuccess ? Icons.check_circle_rounded : Icons.error_rounded,
                    color: isSuccess ? const Color(0xFF03543F) : const Color(0xFF9B1C1C),
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.message,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSuccess ? const Color(0xFF03543F) : const Color(0xFF9B1C1C),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: widget.onDismiss,
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: isSuccess ? const Color(0xFF03543F) : const Color(0xFF9B1C1C),
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
