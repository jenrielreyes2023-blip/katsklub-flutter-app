import 'package:flutter/material.dart';
import 'package:flutter_svga/flutter_svga.dart';

/// A reusable background widget supporting both static images and SVGA animations.
class DynamicBackgroundWidget extends StatefulWidget {
  final String? bgImagePath;
  final String? svgaPath;
  final Widget child;

  const DynamicBackgroundWidget({
    super.key,
    this.bgImagePath = 'assets/images/erhai_bg.png',
    this.svgaPath = 'assets/svga/bg_1334.svga',
    required this.child,
  });

  @override
  State<DynamicBackgroundWidget> createState() => _DynamicBackgroundWidgetState();
}

class _DynamicBackgroundWidgetState extends State<DynamicBackgroundWidget>
    with SingleTickerProviderStateMixin {
  SVGAAnimationController? _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = SVGAAnimationController(vsync: this);
    if (widget.svgaPath != null) {
      _loadSvga(widget.svgaPath!);
    }
  }

  @override
  void didUpdateWidget(covariant DynamicBackgroundWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.svgaPath != oldWidget.svgaPath && widget.svgaPath != null) {
      _loadSvga(widget.svgaPath!);
    }
  }

  Future<void> _loadSvga(String path) async {
    try {
      final videoItem = await SVGAParser.shared.decodeFromAssets(path);
      if (mounted) {
        setState(() {
          _animationController?.videoItem = videoItem;
          _animationController?.repeat();
        });
      }
    } catch (e) {
      debugPrint('Error loading SVGA asset $path: $e');
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Static Image Layer (Erhai background)
        if (widget.bgImagePath != null)
          Positioned.fill(
            child: Image.asset(
              widget.bgImagePath!,
              fit: BoxFit.cover,
            ),
          ),

        // 2. SVGA Animation Layer (floating overlay, pointer events ignored)
        if (widget.svgaPath != null && _animationController?.videoItem != null)
          Positioned.fill(
            child: IgnorePointer(
              child: SVGAImage(
                _animationController!,
                fit: BoxFit.cover,
              ),
            ),
          ),

        // 3. Child Content Layer
        widget.child,
      ],
    );
  }
}
