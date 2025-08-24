import 'dart:math';
import 'package:flutter/material.dart';

class AnalogSpeedometer extends StatelessWidget {
  final double speed;
  final String unit;

  const AnalogSpeedometer({
    super.key,
    required this.speed,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 250,
            height: 250,
            child: CustomPaint(
              painter: SpeedometerPainter(
                speed: speed,
                theme: Theme.of(context),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                    Text(
                      speed.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      unit,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SpeedometerPainter extends CustomPainter {
  final double speed;
  final ThemeData theme;
  static const double maxSpeed = 120.0;

  const SpeedometerPainter({
    required this.speed,
    required this.theme,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;

    _drawSpeedometerArc(canvas, center, radius);
    _drawTicks(canvas, center, radius);
    _drawNeedle(canvas, center, radius);
    _drawCenterCircle(canvas, center);
  }

  void _drawSpeedometerArc(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = theme.colorScheme.outline.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    const startAngle = pi * 0.75;
    const sweepAngle = pi * 1.5;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      paint,
    );

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    final progress = (speed / maxSpeed).clamp(0.0, 1.0);
    final progressSweep = sweepAngle * progress;

    if (progress > 0) {
      progressPaint.color = _getSpeedColor(speed);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        progressSweep,
        false,
        progressPaint,
      );
    }
  }

  void _drawTicks(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = theme.colorScheme.onSurface
      ..strokeWidth = 2;

    const tickCount = 13;
    const startAngle = pi * 0.75;
    const sweepAngle = pi * 1.5;

    for (int i = 0; i < tickCount; i++) {
      final angle = startAngle + (sweepAngle * i / (tickCount - 1));
      final isMainTick = i % 3 == 0;
      
      final outerRadius = radius - 5;
      final innerRadius = outerRadius - (isMainTick ? 15 : 8);
      
      final outerPoint = Offset(
        center.dx + cos(angle) * outerRadius,
        center.dy + sin(angle) * outerRadius,
      );
      
      final innerPoint = Offset(
        center.dx + cos(angle) * innerRadius,
        center.dy + sin(angle) * innerRadius,
      );
      
      paint.strokeWidth = isMainTick ? 3 : 2;
      canvas.drawLine(outerPoint, innerPoint, paint);

      if (isMainTick) {
        final speed = (maxSpeed * i / (tickCount - 1)).round();
        final textPainter = TextPainter(
          text: TextSpan(
            text: speed.toString(),
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        
        final textRadius = innerRadius - 15;
        final textOffset = Offset(
          center.dx + cos(angle) * textRadius - textPainter.width / 2,
          center.dy + sin(angle) * textRadius - textPainter.height / 2,
        );
        
        textPainter.paint(canvas, textOffset);
      }
    }
  }

  void _drawNeedle(Canvas canvas, Offset center, double radius) {
    final progress = (speed / maxSpeed).clamp(0.0, 1.0);
    const startAngle = pi * 0.75;
    const sweepAngle = pi * 1.5;
    final needleAngle = startAngle + (sweepAngle * progress);

    final needlePaint = Paint()
      ..color = _getSpeedColor(speed)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final needleLength = radius * 0.7;
    final needleEnd = Offset(
      center.dx + cos(needleAngle) * needleLength,
      center.dy + sin(needleAngle) * needleLength,
    );

    canvas.drawLine(center, needleEnd, needlePaint);
  }

  void _drawCenterCircle(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = theme.colorScheme.primary
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 8, paint);
  }

  Color _getSpeedColor(double speed) {
    if (speed < 30) {
      return Colors.green;
    } else if (speed < 60) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is SpeedometerPainter && oldDelegate.speed != speed;
  }
}