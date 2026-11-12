import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Animated circular arc health score gauge with color interpolation and Red-Cap badge
class CircularScoreGauge extends StatefulWidget {
  final int? score;
  final bool isRedCapped;
  final String verdictTag;
  final double size;

  const CircularScoreGauge({
    super.key,
    required this.score,
    required this.isRedCapped,
    required this.verdictTag,
    this.size = 180.0,
  });

  @override
  State<CircularScoreGauge> createState() => _CircularScoreGaugeState();
}

class _CircularScoreGaugeState extends State<CircularScoreGauge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _scoreAnimation = Tween<double>(
      begin: 0.0,
      end: (widget.score ?? 0).toDouble(),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant CircularScoreGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _scoreAnimation = Tween<double>(
        begin: _scoreAnimation.value,
        end: (widget.score ?? 0).toDouble(),
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color _getScoreColor(double score) {
    if (widget.score == null) {
      return AppColors.safetyAmber;
    }
    if (widget.isRedCapped || score <= 39) {
      return AppColors.safetyRed;
    } else if (score < 70) {
      return AppColors.safetyAmber;
    } else {
      return AppColors.safetyGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scoreAnimation,
      builder: (context, _) {
        final currentScore = _scoreAnimation.value;
        final animatedColor = _getScoreColor(currentScore);
        final bool isNullScore = widget.score == null;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _ScoreArcPainter(
                  score: isNullScore ? 0.0 : currentScore,
                  maxScore: 100.0,
                  scoreColor: animatedColor,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isNullScore ? '--' : currentScore.round().toString(),
                    style: TextStyle(
                      fontSize: widget.size * (isNullScore ? 0.24 : 0.28),
                      fontWeight: FontWeight.w900,
                      color: animatedColor,
                      height: 1.0,
                      letterSpacing: isNullScore ? 2.0 : -1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (!isNullScore)
                    Text(
                      '/100',
                      style: TextStyle(
                        fontSize: widget.size * 0.08,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textMutedMocha,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: animatedColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: animatedColor.withValues(alpha: 0.3),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      widget.verdictTag,
                      style: TextStyle(
                        fontSize: widget.size * (isNullScore ? 0.055 : 0.065),
                        fontWeight: FontWeight.w800,
                        color: animatedColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ScoreArcPainter extends CustomPainter {
  final double score;
  final double maxScore;
  final Color scoreColor;

  _ScoreArcPainter({
    required this.score,
    required this.maxScore,
    required this.scoreColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.09;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    const startAngle = 135.0 * (math.pi / 180.0);
    const totalSweep = 270.0 * (math.pi / 180.0);

    // 1. Background Arc Track
    final bgPaint = Paint()
      ..color = const Color(0xFFE2DDD5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      totalSweep,
      false,
      bgPaint,
    );

    // 2. Active Progress Arc
    final sweepProgress = (score / maxScore).clamp(0.0, 1.0) * totalSweep;
    if (sweepProgress > 0) {
      final activePaint = Paint()
        ..color = scoreColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepProgress,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreArcPainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.scoreColor != scoreColor;
  }
}
