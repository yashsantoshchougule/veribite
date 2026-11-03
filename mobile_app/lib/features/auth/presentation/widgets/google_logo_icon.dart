import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Lightweight, offline vector Google 'G' icon matching standard branding guidelines.
class GoogleLogoIcon extends StatelessWidget {
  final double size;

  const GoogleLogoIcon({super.key, this.size = 22.0});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final Offset center = Offset(width / 2, height / 2);
    final double outerRadius = width / 2;
    final double strokeWidth = width * 0.22;
    final double midRadius = outerRadius - (strokeWidth / 2);

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final Rect arcRect = Rect.fromCircle(center: center, radius: midRadius);

    // 1. Red (Top Arc: 200° to 315°)
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(arcRect, -math.pi * 0.85, math.pi * 0.55, false, paint);

    // 2. Yellow (Left Arc: 125° to 200°)
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(arcRect, math.pi * 0.70, math.pi * 0.45, false, paint);

    // 3. Green (Bottom Arc: 45° to 125°)
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(arcRect, math.pi * 0.15, math.pi * 0.55, false, paint);

    // 4. Blue (Right Horizontal Bar & Arc: -45° to 45°)
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(arcRect, -math.pi * 0.30, math.pi * 0.45, false, paint);

    // Blue horizontal bar going into the center
    final Paint fillBlue = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    final double barHeight = strokeWidth;
    final double barLeft = center.dx - strokeWidth * 0.1;
    final double barRight = center.dx + midRadius + strokeWidth / 2;
    final double barTop = center.dy - barHeight / 2;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(barLeft, barTop, barRight, barTop + barHeight),
        Radius.circular(strokeWidth * 0.2),
      ),
      fillBlue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
