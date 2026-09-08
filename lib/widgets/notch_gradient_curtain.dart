import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// An elastic, glowing orange gradient curtain that emerges from the device's
/// camera notch and status bar when pulling down to refresh.
/// Stretches downwards following finger drag and springs back up when released.
class NotchGradientCurtain extends StatelessWidget {
  const NotchGradientCurtain({
    required this.pullDistance,
    required this.statusBarHeight,
    required this.isRefreshing,
    super.key,
  });

  final double pullDistance;
  final double statusBarHeight;
  final bool isRefreshing;

  @override
  Widget build(BuildContext context) {
    if (pullDistance <= 0.5 && !isRefreshing) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalHeight = statusBarHeight + pullDistance;

    return Positioned(
      top: -statusBarHeight,
      left: 0,
      right: 0,
      height: totalHeight + 15, // extra room for the curved sag
      child: IgnorePointer(
        child: CustomPaint(
          size: Size(MediaQuery.of(context).size.width, totalHeight),
          painter: _NotchCurtainPainter(
            pullDistance: pullDistance,
            statusBarHeight: statusBarHeight,
            isRefreshing: isRefreshing,
            isDark: isDark,
          ),
        ),
      ),
    );
  }
}

class _NotchCurtainPainter extends CustomPainter {
  _NotchCurtainPainter({
    required this.pullDistance,
    required this.statusBarHeight,
    required this.isRefreshing,
    required this.isDark,
  });

  final double pullDistance;
  final double statusBarHeight;
  final bool isRefreshing;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = statusBarHeight + pullDistance;
    if (w <= 0 || h <= 0) return;

    // Pull progress factor from 0.0 to 1.0+
    final progress = (pullDistance / 90.0).clamp(0.0, 1.6);

    // Parabolic sag in the center (stretches like a fluid drop from the notch)
    final sag = math.min(24.0, pullDistance * 0.22);

    // 1. Build curved curtain path
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(0, h - sag * 0.4)
      ..quadraticBezierTo(
        w * 0.5,
        h + sag,
        w,
        h - sag * 0.4,
      )
      ..lineTo(w, 0)
      ..close();

    // 2. Soft, comfortable sunset orange gradient from notch downwards
    final alphaMultiplier = (0.45 + 0.40 * math.min(1.0, progress));
    final curtainPaint = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * 0.5, 0),
        Offset(w * 0.5, h + sag),
        [
          // At the notch & status bar: smooth warm orange
          const Color(0xFFFF7A45).withValues(
            alpha: (isDark ? 0.55 : 0.45) * alphaMultiplier,
          ),
          // Behind top bar: gentle peach
          const Color(0xFFFF9E66).withValues(
            alpha: (isDark ? 0.35 : 0.28) * alphaMultiplier,
          ),
          // Lower falloff: soft amber
          const Color(0xFFFFB366).withValues(
            alpha: (isDark ? 0.18 : 0.12) * alphaMultiplier,
          ),
          Colors.transparent,
        ],
        const [0.0, 0.45, 0.80, 1.0],
      );

    canvas.drawPath(path, curtainPaint);
  }

  @override
  bool shouldRepaint(covariant _NotchCurtainPainter oldDelegate) {
    return oldDelegate.pullDistance != pullDistance ||
        oldDelegate.statusBarHeight != statusBarHeight ||
        oldDelegate.isRefreshing != isRefreshing ||
        oldDelegate.isDark != isDark;
  }
}
