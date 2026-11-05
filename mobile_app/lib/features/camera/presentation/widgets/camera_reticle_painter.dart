import 'package:flutter/material.dart';
import '../../domain/camera_scan_state.dart';

class CameraReticleOverlay extends StatelessWidget {
  final CameraScanStatus status;
  final bool hasGlareAlert;
  final double reticleWidth;
  final double reticleHeight;
  final Offset? focusPoint;
  final bool isFocusLocked;

  const CameraReticleOverlay({
    super.key,
    required this.status,
    required this.hasGlareAlert,
    this.reticleWidth = 340,
    this.reticleHeight = 340,
    this.focusPoint,
    this.isFocusLocked = false,
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
        focusPoint: focusPoint,
        isFocusLocked: isFocusLocked,
      ),
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final CameraScanStatus status;
  final bool hasGlareAlert;
  final double reticleWidth;
  final double reticleHeight;
  final Offset? focusPoint;
  final bool isFocusLocked;

  _ReticlePainter({
    required this.status,
    required this.hasGlareAlert,
    required this.reticleWidth,
    required this.reticleHeight,
    this.focusPoint,
    this.isFocusLocked = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCenter(
      center: center,
      width: reticleWidth,
      height: reticleHeight,
    );

    // 1. Dark translucent background outside the large reticle box
    final bgPaint = Paint()..color = Colors.black.withValues(alpha: 0.45);
    final bgPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(20)))
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(bgPath, bgPaint);

    // 2. Pick reticle corner stroke color based on scan status
    final Color strokeColor;
    if (status == CameraScanStatus.barcodeLocked) {
      strokeColor = const Color(0xFF0F9D58); // Green
    } else if (hasGlareAlert) {
      strokeColor = const Color(0xFFF4B400); // Amber/Yellow
    } else {
      strokeColor = Colors.white.withValues(alpha: 0.85); // Neutral White
    }

    final cornerPaint = Paint()
      ..color = strokeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    const cornerLength = 32.0;

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
