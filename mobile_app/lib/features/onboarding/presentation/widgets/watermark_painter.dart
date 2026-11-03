import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Paints subtle concentric luxury orbital rings in the lower background
class WatermarkPainter extends CustomPainter {
  const WatermarkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.watermarkRing.withValues(alpha: 0.30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Anchor center in the bottom right corner
    final center = Offset(size.width * 0.95, size.height * 0.85);

    // Radii of concentric orbital arcs
    final radii = [
      size.width * 0.30,
      size.width * 0.45,
      size.width * 0.60,
      size.width * 0.75,
      size.width * 0.95,
      size.width * 1.15,
    ];

    for (final radius in radii) {
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

