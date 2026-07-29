import 'package:flutter/material.dart';

/// A GPU-accelerated, 120fps butter-smooth PageRoute transition for Bottom Sheets.
/// Eliminates layout re-calculation jank by animating via PageRoute SlideTransition.
class SmoothBottomSheetRoute<T> extends PageRouteBuilder<T> {
  SmoothBottomSheetRoute({
    required WidgetBuilder builder,
    Color barrierColor = const Color(0x8A000000),
  }) : super(
          opaque: false,
          barrierDismissible: true,
          barrierColor: barrierColor,
          transitionDuration: const Duration(milliseconds: 280),
          reverseTransitionDuration: const Duration(milliseconds: 240),
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            );
          },
        );

  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    Color barrierColor = const Color(0x8A000000),
  }) {
    return Navigator.of(context).push<T>(
      SmoothBottomSheetRoute<T>(
        builder: builder,
        barrierColor: barrierColor,
      ),
    );
  }
}

/// Uniform Create-Post Style Bottom Sheet Container.
/// Provides dark rounded top corners (24px), drag handle pill (44x5px), and consistent padding.
class SmoothSheetContainer extends StatelessWidget {
  const SmoothSheetContainer({
    required this.child,
    this.maxHeightFraction = 0.85,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 18),
    super.key,
  });

  final Widget child;
  final double maxHeightFraction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1F20) : const Color(0xFFF7F7F7);
    final handleColor = isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB);
    final screenHeight = MediaQuery.of(context).size.height;

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(maxHeight: screenHeight * maxHeightFraction),
          width: double.infinity,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
