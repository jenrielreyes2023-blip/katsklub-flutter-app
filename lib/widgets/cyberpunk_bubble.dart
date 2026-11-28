import 'dart:math' as math;
import 'package:flutter/material.dart';

class CyberpunkBubble extends StatefulWidget {
  const CyberpunkBubble({
    super.key,
    required this.child,
    required this.sentByMe,
    this.borderRadius,
    this.constraints,
    this.padding,
    this.showHudTag = true,
  });

  final Widget child;
  final bool sentByMe;
  final BorderRadius? borderRadius;
  final BoxConstraints? constraints;
  final EdgeInsetsGeometry? padding;
  final bool showHudTag;

  @override
  State<CyberpunkBubble> createState() => _CyberpunkBubbleState();
}

class _CyberpunkBubbleState extends State<CyberpunkBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final defaultRadius = widget.borderRadius ??
        BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: Radius.circular(widget.sentByMe ? 4 : 16),
          bottomLeft: Radius.circular(widget.sentByMe ? 16 : 4),
          bottomRight: const Radius.circular(16),
        );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        final pulse = (math.sin(t * 2 * math.pi) + 1) / 2; // 0.0 to 1.0

        const cyan = Color(0xFF00F0FF);
        const magenta = Color(0xFFFF007F);

        // Rotating gradient alignment based on animation progress
        final angle = t * 2 * math.pi;
        final startAlign = Alignment(math.cos(angle), math.sin(angle));
        final endAlign = Alignment(math.cos(angle + math.pi), math.sin(angle + math.pi));

        // Scanline sweep position (from -1.2 to 1.2 across the bubble)
        final sweepX = -1.2 + (t * 2.4);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Outer Glowing Bubble
            Container(
              constraints: widget.constraints,
              decoration: BoxDecoration(
                borderRadius: defaultRadius,
                boxShadow: [
                  BoxShadow(
                    color: cyan.withValues(alpha: 0.16 + 0.12 * pulse),
                    blurRadius: 10 + 6 * pulse,
                    spreadRadius: 0.5 + 0.8 * pulse,
                  ),
                  BoxShadow(
                    color: magenta.withValues(alpha: 0.10 + 0.08 * (1 - pulse)),
                    blurRadius: 12 + 4 * (1 - pulse),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: defaultRadius,
                  gradient: LinearGradient(
                    begin: startAlign,
                    end: endAlign,
                    colors: const [
                      Color(0xFF00F0FF),
                      Color(0xFF8B5CF6),
                      Color(0xFFFF007F),
                      Color(0xFF00F0FF),
                    ],
                    stops: const [0.0, 0.35, 0.7, 1.0],
                  ),
                ),
                padding: const EdgeInsets.all(1.5), // High-tech neon border thickness
                child: ClipRRect(
                  borderRadius: defaultRadius,
                  child: Stack(
                    children: [
                      // Dark Cyber Metallic Glass Interior
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF0C111F),
                              Color(0xFF070A14),
                              Color(0xFF080D1A),
                            ],
                          ),
                        ),
                        padding: widget.padding ??
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        child: widget.child,
                      ),

                      // Holographic Laser Scanline Sweep
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: _CyberScanlinePainter(
                              sweepX: sweepX,
                              cyan: cyan,
                              magenta: magenta,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Top Cyber HUD Bracket & Blinking Neon Tag
            if (widget.showHudTag)
              Positioned(
                top: -8,
                right: widget.sentByMe ? 8 : null,
                left: widget.sentByMe ? null : 8,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF070A14),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: cyan.withValues(alpha: 0.4 + 0.3 * pulse),
                        width: 0.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cyan.withValues(alpha: 0.25 * pulse),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: pulse > 0.5 ? cyan : magenta,
                            boxShadow: [
                              BoxShadow(
                                color: (pulse > 0.5 ? cyan : magenta).withValues(alpha: 0.8),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.sentByMe ? 'CYBER // 01' : 'SYS // IN',
                          style: const TextStyle(
                            fontFamily: 'SF Pro Rounded',
                            fontSize: 7.5,
                            fontWeight: FontWeight.w800,
                            color: cyan,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Bottom Corner Tech Ornament Accent
            if (widget.showHudTag)
              Positioned(
                bottom: -4,
                left: widget.sentByMe ? 12 : null,
                right: widget.sentByMe ? null : 12,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: const Color(0xFF070A14),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: magenta.withValues(alpha: 0.45),
                        width: 0.6,
                      ),
                    ),
                    child: const Text(
                      '///',
                      style: TextStyle(
                        fontFamily: 'SF Pro Rounded',
                        fontSize: 6.5,
                        fontWeight: FontWeight.w900,
                        color: magenta,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CyberScanlinePainter extends CustomPainter {
  const _CyberScanlinePainter({
    required this.sweepX,
    required this.cyan,
    required this.magenta,
  });

  final double sweepX;
  final Color cyan;
  final Color magenta;

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Subtle horizontal micro scanlines (cyber CRT feel)
    final scanlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += 4.0) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), scanlinePaint);
    }

    // 2. Angled laser sweep gradient
    final sweepRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final sweepPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment(sweepX - 0.3, -1.0),
        end: Alignment(sweepX + 0.3, 1.0),
        colors: [
          Colors.transparent,
          cyan.withValues(alpha: 0.08),
          magenta.withValues(alpha: 0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 0.55, 1.0],
      ).createShader(sweepRect);

    canvas.drawRect(sweepRect, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _CyberScanlinePainter oldDelegate) {
    return oldDelegate.sweepX != sweepX;
  }
}
