import 'package:flutter/material.dart';
import 'package:mobile_app/features/camera/domain/camera_scan_state.dart';

class CameraReticleOverlay extends StatelessWidget {
  final CameraScanStatus status;
  final bool hasGlareAlert;
  final double reticleWidth;
  final double reticleHeight;

  const CameraReticleOverlay({
    super.key,
    required this.status,
    required this.hasGlareAlert,
    this.reticleWidth = 280,
    this.reticleHeight = 280,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _ReticlePainter(
        status: status,
        hasGlareAlert: hasGlareAlert,
        reticleWidth: reticleWidth,
        reticleHeight: reticleHeight,
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final CameraScanStatus status;
  final bool hasGlareAlert;
  final double reticleWidth;
  final double reticleHeight;

  _ReticlePainter({
    required this.status,
    required this.hasGlareAlert,
    required this.reticleWidth,
    required this.reticleHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: reticleWidth,
      height: reticleHeight,
    );

    // Dark translucent background outside the reticle box
    final bgPaint = Paint()..color = Colors.black.withOpacity(0.45);
    final bgPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(bgPath, bgPaint);

    // Pick reticle corner color based on scan status
    final Color strokeColor;
    if (status == CameraScanStatus.barcodeLocked) {
      strokeColor = const Color(0xFF0F9D58); // Green
    } else if (hasGlareAlert) {
      strokeColor = const Color(0xFFF4B400); // Amber/Yellow
    } else {
      strokeColor = Colors.white.withOpacity(0.85); // Neutral White
    }

    final cornerPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 26.0;

    // Top-Left corner
    canvas.drawLine(Offset(rect.left, rect.top + cornerLength), Offset(rect.left, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.top), Offset(rect.left + cornerLength, rect.top), cornerPaint);

    // Top-Right corner
    canvas.drawLine(Offset(rect.right - cornerLength, rect.top), Offset(rect.right, rect.top), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.top), Offset(rect.right, rect.top + cornerLength), cornerPaint);

    // Bottom-Left corner
    canvas.drawLine(Offset(rect.left, rect.bottom - cornerLength), Offset(rect.left, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.left, rect.bottom), Offset(rect.left + cornerLength, rect.bottom), cornerPaint);

    // Bottom-Right corner
    canvas.drawLine(Offset(rect.right - cornerLength, rect.bottom), Offset(rect.right, rect.bottom), cornerPaint);
    canvas.drawLine(Offset(rect.right, rect.bottom), Offset(rect.right, rect.bottom - cornerLength), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _ReticlePainter oldDelegate) {
    return oldDelegate.status != status ||
        oldDelegate.hasGlareAlert != hasGlareAlert ||
        oldDelegate.reticleWidth != reticleWidth ||
        oldDelegate.reticleHeight != reticleHeight;
  }
}
