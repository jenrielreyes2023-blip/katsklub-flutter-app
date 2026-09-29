import 'dart:math' as math;
import 'package:flutter/material.dart';

class DashedBorderPainter extends CustomPainter {
  const DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.borderRadius = 12.0,
  });

  final Color color;
  final double strokeWidth;
  final double borderRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(borderRadius),
      ));

    final dashWidth = 5.0;
    final dashSpace = 3.0;
    
    final pms = path.computeMetrics();
    for (final pm in pms) {
      double distance = 0.0;
      while (distance < pm.length) {
        final len = dashWidth;
        canvas.drawPath(
          pm.extractPath(distance, distance + len),
          paint,
        );
        distance += len + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.borderRadius != borderRadius;
  }
}

class GhostBubblePainter extends CustomPainter {
  GhostBubblePainter({required this.isDark});
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..color = isDark
          ? Colors.black.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = isDark
          ? Colors.black.withValues(alpha: 0.25)
          : Colors.black.withValues(alpha: 0.10)
      ..style = PaintingStyle.fill;

    final bubbles = [
      Bubble(x: size.width * 0.12, y: size.height * 0.18, radius: 22),
      Bubble(x: size.width * 0.88, y: size.height * 0.15, radius: 30),
      Bubble(x: size.width * 0.76, y: size.height * 0.72, radius: 25),
      Bubble(x: size.width * 0.20, y: size.height * 0.78, radius: 28),
      Bubble(x: size.width * 0.52, y: size.height * 0.45, radius: 38),
      Bubble(x: size.width * 0.09, y: size.height * 0.52, radius: 18),
      Bubble(x: size.width * 0.91, y: size.height * 0.48, radius: 24),
    ];

    for (final bubble in bubbles) {
      canvas.drawCircle(Offset(bubble.x, bubble.y), bubble.radius, fillPaint);

      final double circumference = 2 * math.pi * bubble.radius;
      final int dotCount = (circumference / 6.5).floor().clamp(10, 80);
      for (int i = 0; i < dotCount; i++) {
        final double angle = (i * 2 * math.pi) / dotCount;
        final double dx = bubble.x + bubble.radius * math.cos(angle);
        final double dy = bubble.y + bubble.radius * math.sin(angle);
        canvas.drawCircle(Offset(dx, dy), 1.4, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GhostBubblePainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}

class Bubble {
  const Bubble({required this.x, required this.y, required this.radius});
  final double x;
  final double y;
  final double radius;
}

class DottedChatBubblePainter extends CustomPainter {
  DottedChatBubblePainter({
    required this.fillColor,
    required this.dotColor,
  });

  final Color fillColor;
  final Color dotColor;

  static final Map<Size, Path> _dashedPathCache = {};

  @override
  void paint(Canvas canvas, Size size) {
    final double r = 16.0;
    final double tailTop = 8.0;

    final path = Path()
      ..moveTo(32, tailTop)
      ..lineTo(size.width - r, tailTop)
      ..arcToPoint(Offset(size.width, tailTop + r), radius: Radius.circular(r))
      ..lineTo(size.width, size.height - r)
      ..arcToPoint(Offset(size.width - r, size.height), radius: Radius.circular(r))
      ..lineTo(r, size.height)
      ..arcToPoint(Offset(0, size.height - r), radius: Radius.circular(r))
      ..lineTo(0, tailTop + r)
      ..arcToPoint(Offset(r, tailTop), radius: Radius.circular(r))
      ..lineTo(12, tailTop)
      ..lineTo(20, 0)
      ..lineTo(26, tailTop)
      ..close();

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final dashPaint = Paint()
      ..color = dotColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    Path? dashedPath = _dashedPathCache[size];
    if (dashedPath == null) {
      dashedPath = Path();
      final double dashLength = 6.0;
      final double dashSpace = 4.0;
      final metrics = path.computeMetrics();
      for (final metric in metrics) {
        double distance = 0.0;
        while (distance < metric.length) {
          final double end = (distance + dashLength).clamp(0.0, metric.length);
          dashedPath.addPath(metric.extractPath(distance, end), Offset.zero);
          distance += dashLength + dashSpace;
        }
      }
      _dashedPathCache[size] = dashedPath;
    }

    canvas.drawPath(dashedPath, dashPaint);
  }

  @override
  bool shouldRepaint(covariant DottedChatBubblePainter oldDelegate) =>
      oldDelegate.fillColor != fillColor || oldDelegate.dotColor != dotColor;
}
