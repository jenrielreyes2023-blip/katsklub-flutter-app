import 'package:flutter/material.dart';

class RainbowShimmerText extends StatefulWidget {
  const RainbowShimmerText({
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
  State<RainbowShimmerText> createState() => _RainbowShimmerTextState();
}

class _RainbowShimmerTextState extends State<RainbowShimmerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000), // Slower, smoother rainbow shift
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
                Color(0xFFFF2A2A), // Red
                Color(0xFFFF7A00), // Orange
                Color(0xFFFFD600), // Yellow
                Color(0xFF00E575), // Green
                Color(0xFF00B2FF), // Blue
                Color(0xFF9E00FF), // Violet
                Color(0xFFFF2A2A), // Seamless loop back to Red
              ],
              stops: const [0.0, 0.16, 0.33, 0.5, 0.66, 0.83, 1.0],
              transform: _SlantedGradientTransform(_controller.value),
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            maxLines: widget.maxLines,
            overflow: widget.overflow,
            style: widget.style.copyWith(
              color: Colors.white, // Required for ShaderMask to apply fully
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
