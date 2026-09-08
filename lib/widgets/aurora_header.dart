import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A dynamic, organic Aurora Borealis glowing header widget.
/// Continuously breathes and flows with multi-layer animated waves,
/// frosted glassmorphism, and flares into high-energy aurora ribbons during refresh.
class AuroraHeader extends StatefulWidget {
  const AuroraHeader({
    required this.height,
    required this.isRefreshing,
    required this.child,
    this.idleIntensity = 0.28,
    this.refreshIntensity = 1.0,
    super.key,
  });

  final double height;
  final bool isRefreshing;
  final Widget child;
  final double idleIntensity;
  final double refreshIntensity;

  @override
  State<AuroraHeader> createState() => _AuroraHeaderState();
}

class _AuroraHeaderState extends State<AuroraHeader>
    with TickerProviderStateMixin {
  late final AnimationController _waveController;
  late final AnimationController _sweepController;
  late final AnimationController _intensityController;
  late final Animation<double> _intensityAnimation;

  @override
  void initState() {
    super.initState();
    // Continuous smooth undulating aurora wave
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    )..repeat();

    // Laser beam / aurora filament sweep along the bottom edge
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // Intensity transition controller between idle and active refresh
    _intensityController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
      value: widget.isRefreshing ? 1.0 : 0.0,
    );

    _intensityAnimation = CurvedAnimation(
      parent: _intensityController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void didUpdateWidget(AuroraHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isRefreshing != widget.isRefreshing) {
      if (widget.isRefreshing) {
        _intensityController.forward();
      } else {
        _intensityController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    _sweepController.dispose();
    _intensityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: Listenable.merge([
        _waveController,
        _sweepController,
        _intensityAnimation,
      ]),
      builder: (context, _) {
        final rawProgress = _intensityAnimation.value;
        final currentIntensity = ui.lerpDouble(
          widget.idleIntensity,
          widget.refreshIntensity,
          rawProgress,
        )!;

        final extraGlowHeight = (28.h * rawProgress);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 1. Ambient down-glow beneath the header when refreshing
            if (rawProgress > 0.02)
              Positioned(
                top: widget.height - 2,
                left: -20,
                right: -20,
                height: extraGlowHeight + 30.h,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.8),
                        radius: 1.1,
                        colors: [
                          const Color(0xFFFF7A45).withValues(
                            alpha: (isDark ? 0.32 : 0.22) * rawProgress,
                          ),
                          const Color(0xFFFFB020).withValues(
                            alpha: (isDark ? 0.18 : 0.12) * rawProgress,
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
              ),

            // 2. Main Aurora Canvas & Frosted Glass Container
            ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Color.lerp(
                            const Color(0xFF141416).withValues(alpha: 0.85),
                            const Color(0xFF221510).withValues(alpha: 0.94),
                            rawProgress,
                          )
                        : Color.lerp(
                            Colors.white.withValues(alpha: 0.88),
                            const Color(0xFFFFF4EE).withValues(alpha: 0.96),
                            rawProgress,
                          ),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Dynamic Aurora Wave Painter
                      CustomPaint(
                        painter: _AuroraWavePainter(
                          waveProgress: _waveController.value,
                          sweepProgress: _sweepController.value,
                          intensity: currentIntensity,
                          isDark: isDark,
                        ),
                      ),

                      // Content on top of Aurora
                      widget.child,
                    ],
                  ),
                ),
              ),
            ),

            // 3. Glowing Aurora Bottom Border Beam
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _AuroraBeamLine(
                sweepProgress: _sweepController.value,
                intensity: currentIntensity,
                isDark: isDark,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Custom painter that renders organic undulating aurora curtain waves
/// using multiple sinusoidal interfering gradient ribbons.
class _AuroraWavePainter extends CustomPainter {
  _AuroraWavePainter({
    required this.waveProgress,
    required this.sweepProgress,
    required this.intensity,
    required this.isDark,
  });

  final double waveProgress;
  final double sweepProgress;
  final double intensity;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    if (w <= 0 || h <= 0) return;

    final t = waveProgress * 2 * math.pi;

    // --- Layer A: Ambient Aurora Orbs (Soft blooming light centers) ---
    final orb1Center = Offset(
      w * (0.25 + 0.20 * math.sin(t)),
      h * (0.20 + 0.25 * math.cos(t * 0.8)),
    );
    final orb1Radius = w * 0.65;
    final orb1Paint = Paint()
      ..shader = ui.Gradient.radial(
        orb1Center,
        orb1Radius,
        [
          const Color(0xFFFF6A00).withValues(
            alpha: (isDark ? 0.38 : 0.25) * intensity,
          ),
          const Color(0xFFFF9E66).withValues(
            alpha: (isDark ? 0.18 : 0.12) * intensity,
          ),
          Colors.transparent,
        ],
        [0.0, 0.5, 1.0],
      );
    canvas.drawCircle(orb1Center, orb1Radius, orb1Paint);

    final orb2Center = Offset(
      w * (0.75 - 0.22 * math.cos(t * 0.7)),
      h * (0.30 + 0.20 * math.sin(t * 1.1)),
    );
    final orb2Radius = w * 0.60;
    final orb2Paint = Paint()
      ..shader = ui.Gradient.radial(
        orb2Center,
        orb2Radius,
        [
          const Color(0xFFFF2A6D).withValues(
            alpha: (isDark ? 0.32 : 0.20) * intensity,
          ),
          const Color(0xFFFFB347).withValues(
            alpha: (isDark ? 0.16 : 0.10) * intensity,
          ),
          Colors.transparent,
        ],
        [0.0, 0.45, 1.0],
      );
    canvas.drawCircle(orb2Center, orb2Radius, orb2Paint);

    // --- Layer B: Primary Aurora Wave (Warm Amber-Orange Curtain) ---
    final path1 = Path()..moveTo(0, 0);
    const step = 4.0;
    for (double x = 0; x <= w; x += step) {
      final nx = x / w;
      final y = h * (0.35 + 0.45 * intensity) +
          math.sin(nx * 2.5 * math.pi + t) * (h * 0.20) +
          math.cos(nx * 4.0 * math.pi - t * 0.8) * (h * 0.12);
      path1.lineTo(x, y);
    }
    path1.lineTo(w, 0);
    path1.close();

    final paint1 = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * 0.2, 0),
        Offset(w * 0.8, h),
        [
          const Color(0xFFFF7A45).withValues(
            alpha: (isDark ? 0.40 : 0.28) * intensity,
          ),
          const Color(0xFFFFB020).withValues(
            alpha: (isDark ? 0.22 : 0.15) * intensity,
          ),
          Colors.transparent,
        ],
        [0.0, 0.6, 1.0],
      );
    canvas.drawPath(path1, paint1);

    // --- Layer C: Secondary Aurora Wave (Sunset Magenta / Peach Ribbon) ---
    final path2 = Path()..moveTo(0, 0);
    for (double x = 0; x <= w; x += step) {
      final nx = x / w;
      final y = h * (0.30 + 0.40 * intensity) +
          math.cos(nx * 3.0 * math.pi - t * 1.3) * (h * 0.22) +
          math.sin(nx * 1.8 * math.pi + t * 0.6) * (h * 0.14);
      path2.lineTo(x, y);
    }
    path2.lineTo(w, 0);
    path2.close();

    final paint2 = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w, 0),
        Offset(0, h),
        [
          const Color(0xFFFF3366).withValues(
            alpha: (isDark ? 0.34 : 0.22) * intensity,
          ),
          const Color(0xFFFF8A00).withValues(
            alpha: (isDark ? 0.18 : 0.12) * intensity,
          ),
          Colors.transparent,
        ],
        [0.0, 0.55, 1.0],
      );
    canvas.drawPath(path2, paint2);

    // --- Layer D: Counter Aurora Crest (Golden Sunshine Shimmer) ---
    final path3 = Path()..moveTo(0, 0);
    for (double x = 0; x <= w; x += step) {
      final nx = x / w;
      final y = h * (0.25 + 0.35 * intensity) +
          math.sin(nx * 4.5 * math.pi + t * 1.6) * (h * 0.16) +
          math.cos(nx * 2.0 * math.pi - t * 0.9) * (h * 0.10);
      path3.lineTo(x, y);
    }
    path3.lineTo(w, 0);
    path3.close();

    final paint3 = Paint()
      ..shader = ui.Gradient.linear(
        Offset(w * 0.5, 0),
        Offset(w * 0.5, h * 0.9),
        [
          const Color(0xFFFFD166).withValues(
            alpha: (isDark ? 0.28 : 0.18) * intensity,
          ),
          Colors.transparent,
        ],
        [0.0, 1.0],
      );
    canvas.drawPath(path3, paint3);
  }

  @override
  bool shouldRepaint(covariant _AuroraWavePainter oldDelegate) {
    return oldDelegate.waveProgress != waveProgress ||
        oldDelegate.sweepProgress != sweepProgress ||
        oldDelegate.intensity != intensity ||
        oldDelegate.isDark != isDark;
  }
}

/// A sleek, glowing laser filament line along the bottom border of the top bar.
/// It continuously glides horizontally with shifting aurora highlights.
class _AuroraBeamLine extends StatelessWidget {
  const _AuroraBeamLine({
    required this.sweepProgress,
    required this.intensity,
    required this.isDark,
  });

  final double sweepProgress;
  final double intensity;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final lineHeight = ui.lerpDouble(1.2, 2.4, intensity)!;

    // Sweeping highlight position from -1.5 to 1.5
    final sweepOffset = -1.5 + (sweepProgress * 3.0);

    return Container(
      height: lineHeight,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF7A45).withValues(
              alpha: (isDark ? 0.55 : 0.35) * intensity,
            ),
            blurRadius: 10 * intensity,
            spreadRadius: 1 * intensity,
          ),
          if (intensity > 0.6)
            BoxShadow(
              color: const Color(0xFFFFD166).withValues(
                alpha: (isDark ? 0.40 : 0.25) * intensity,
              ),
              blurRadius: 16 * intensity,
              spreadRadius: 2 * intensity,
            ),
        ],
        gradient: LinearGradient(
          begin: Alignment(sweepOffset - 0.7, 0),
          end: Alignment(sweepOffset + 0.7, 0),
          colors: [
            const Color(0xFFFF7A45).withValues(
              alpha: (isDark ? 0.25 : 0.15) * intensity,
            ),
            const Color(0xFFFF9E66).withValues(
              alpha: (isDark ? 0.55 : 0.35) * intensity,
            ),
            const Color(0xFFFFD166).withValues(
              alpha: (isDark ? 0.95 : 0.75) * intensity,
            ),
            const Color(0xFFFF3366).withValues(
              alpha: (isDark ? 0.65 : 0.45) * intensity,
            ),
            const Color(0xFFFF7A45).withValues(
              alpha: (isDark ? 0.25 : 0.15) * intensity,
            ),
          ],
          stops: const [0.0, 0.3, 0.5, 0.7, 1.0],
        ),
      ),
    );
  }
}
