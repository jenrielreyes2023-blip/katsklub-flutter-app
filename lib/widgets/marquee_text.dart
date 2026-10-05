import 'package:flutter/material.dart';

/// Reusable lightweight marquee text widget that smoothly scrolls text horizontally
/// when it exceeds [maxWidth].
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double maxWidth;
  final bool isPlaying;
  final double scrollSpeed; // pixels per second

  const MarqueeText({
    super.key,
    required this.text,
    required this.style,
    required this.maxWidth,
    this.isPlaying = true,
    this.scrollSpeed = 22.0,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _textWidth = 0.0;
  bool _needsMarquee = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _calculateWidth();
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.maxWidth != widget.maxWidth ||
        oldWidget.isPlaying != widget.isPlaying) {
      _calculateWidth();
    }
  }

  void _calculateWidth() {
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    _textWidth = painter.width;
    _needsMarquee = _textWidth > widget.maxWidth;

    if (_needsMarquee && widget.isPlaying) {
      final totalSpan = _textWidth + 24.0;
      final durationMs = (totalSpan / widget.scrollSpeed * 1000).toInt().clamp(2500, 24000);
      _controller.duration = Duration(milliseconds: durationMs);
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_needsMarquee) {
      return Text(
        widget.text,
        style: widget.style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    const spacing = 24.0;
    final totalSpan = _textWidth + spacing;

    return SizedBox(
      width: widget.maxWidth,
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final offset = -(_controller.value * totalSpan);
            return Stack(
              children: [
                Transform.translate(
                  offset: Offset(offset, 0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.text, style: widget.style),
                      const SizedBox(width: spacing),
                      Text(widget.text, style: widget.style),
                      const SizedBox(width: spacing),
                      Text(widget.text, style: widget.style),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
