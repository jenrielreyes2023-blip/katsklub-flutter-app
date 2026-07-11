import 'package:flutter/material.dart';

class GoldShimmerText extends StatefulWidget {
  const GoldShimmerText({
    super.key,
    required this.text,
    required this.style,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final String text;
  final TextStyle style;
  final int maxLines;
  final TextOverflow overflow;

  @override
  State<GoldShimmerText> createState() => _GoldShimmerTextState();
}

class _GoldShimmerTextState extends State<GoldShimmerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFFD4AF37), // Metallic Gold
                Color(0xFFFFDF73), // Sparkling Golden Yellow
                Color(0xFFFFD700), // Pure Gold
                Color(0xFFFFDF73), // Sparkling Golden Yellow
                Color(0xFFD4AF37), // Metallic Gold
              ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
              transform: _SlantedGradientTransform(_controller.value),
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            maxLines: widget.maxLines,
            overflow: widget.overflow,
            style: widget.style.copyWith(
              color: Colors.white, // Overridden by ShaderMask
            ),
          ),
        );
      },
    );
  }
}

class _SlantedGradientTransform extends GradientTransform {
  const _SlantedGradientTransform(this.percent);

  final double percent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    final double width = bounds.width;
    final double translation = -width + (2 * width * percent);
    final Matrix4 matrix = Matrix4.translationValues(translation, 0.0, 0.0);
    matrix.setEntry(0, 1, -0.35); // Slanted skewX(-0.35) shimmer effect
    return matrix;
  }
}
