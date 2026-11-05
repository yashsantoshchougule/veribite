import 'package:flutter/material.dart';

/// Ephemeral animated focus ring that pulses and fades out after a tap.
/// Replicates native iOS / Pixel camera tap-to-focus ergonomics with zero persistent clutter.
class TransientFocusRing extends StatefulWidget {
  final Offset position;
  final VoidCallback onComplete;

  const TransientFocusRing({
    super.key,
    required this.position,
    required this.onComplete,
  });

  @override
  State<TransientFocusRing> createState() => _TransientFocusRingState();
}

class _TransientFocusRingState extends State<TransientFocusRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _scaleAnimation = Tween<double>(begin: 1.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward().then((_) {
      if (mounted) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 52.0;

    return Positioned(
      left: widget.position.dx - (size / 2),
      top: widget.position.dy - (size / 2),
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: CustomPaint(
                  size: const Size(size, size),
                  painter: _FocusRingPainter(),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 1.8;
    final paint = Paint()
      ..color = const Color(0xFF0F9D58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(8));

    // Outer focus ring
    canvas.drawRRect(rrect, paint);

    // Subtle 4 center tick marks (like professional viewfinders)
    const tickLen = 5.0;
    final midX = size.width / 2;
    final midY = size.height / 2;

    // Top tick
    canvas.drawLine(Offset(midX, 0), Offset(midX, tickLen), paint);
    // Bottom tick
    canvas.drawLine(Offset(midX, size.height), Offset(midX, size.height - tickLen), paint);
    // Left tick
    canvas.drawLine(Offset(0, midY), Offset(tickLen, midY), paint);
    // Right tick
    canvas.drawLine(Offset(size.width, midY), Offset(size.width - tickLen, midY), paint);

    // Center micro dot
    final dotPaint = Paint()
      ..color = const Color(0xFF0F9D58)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(midX, midY), 2.0, dotPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
