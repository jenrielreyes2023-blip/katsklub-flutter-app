import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
          pageBuilder: (context, animation, secondaryAnimation) {
            return Material(
              type: MaterialType.transparency,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: builder(context),
              ),
            );
          },
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

/// Uniform KatsKlub Sheet Item model for standardized menu sheets.
class KatsSheetItem {
  const KatsSheetItem({
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.isDestructive = false,
    this.trailing,
    this.showIconOnRight = true,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isDestructive;
  final Widget? trailing;
  final bool showIconOnRight;
}

/// Centralized Bottom Sheet modal manager for the KatsKlub app.
/// Ensures 100% uniform design, typography (13.5.sp bold), and ScreenUtil responsiveness.
class KatsBottomSheet {
  /// Shows a standardized action menu modal (e.g. Plus [+] Create Menu, More options).
  static Future<T?> showMenu<T>(
    BuildContext context, {
    required List<KatsSheetItem> items,
    String? title,
    bool iconOnRight = true,
    Color barrierColor = const Color(0x8A000000),
  }) {
    return showModalBottomSheet<T>(
      context: context,
      barrierColor: barrierColor,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final bottomPadding = MediaQuery.paddingOf(sheetContext).bottom;
        final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
        final cardBg = isDark ? const Color(0xFF242526) : Colors.white;

        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? Theme.of(sheetContext).colorScheme.surface
                : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.fromLTRB(14.w, 10.h, 14.w, 16.h + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Standard Drag Handle Pill
              Container(
                width: 42.w,
                height: 4.5.h,
                margin: EdgeInsets.only(bottom: 14.h),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF3E4042)
                      : const Color(0xFF9CA3AF),
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),

              if (title != null && title.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ),
              ],

              // Standard Rounded Card Wrapper
              ClipRRect(
                borderRadius: BorderRadius.circular(16.r),
                child: DecoratedBox(
                  decoration: BoxDecoration(color: cardBg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        _KatsSheetMenuItemWidget(
                          item: items[i],
                          iconOnRight: iconOnRight,
                        ),
                        if (i != items.length - 1)
                          Padding(
                            padding: EdgeInsets.only(left: 16.w),
                            child: Divider(
                              height: 1,
                              thickness: 1,
                              color: isDark
                                  ? const Color(0xFF3E4042)
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Shows custom content with uniform KatsKlub container and header styling.
  static Future<T?> showCustom<T>(
    BuildContext context, {
    required Widget child,
    double maxHeightFraction = 0.85,
    EdgeInsetsGeometry? padding,
    Color barrierColor = const Color(0x8A000000),
  }) {
    return showModalBottomSheet<T>(
      context: context,
      barrierColor: barrierColor,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SmoothSheetContainer(
          maxHeightFraction: maxHeightFraction,
          padding: padding ?? EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 18.h),
          child: child,
        );
      },
    );
  }
}

class _KatsSheetMenuItemWidget extends StatelessWidget {
  const _KatsSheetMenuItemWidget({
    required this.item,
    required this.iconOnRight,
  });

  final KatsSheetItem item;
  final bool iconOnRight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemBg = isDark ? const Color(0xFF242526) : Colors.white;
    final itemFg = item.isDestructive
        ? const Color(0xFFDC2626)
        : (isDark ? const Color(0xFFE4E6EB) : const Color(0xFF111827));
    final iconColor = item.isDestructive
        ? const Color(0xFFDC2626)
        : (isDark ? const Color(0xFFFF7A45) : const Color(0xFF111827));

    final iconWidget = Icon(
      item.icon,
      color: iconColor,
      size: 22.r,
    );

    final titleColumn = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.title,
            style: TextStyle(
              color: itemFg,
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
            ),
          ),
          if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Text(
              item.subtitle!,
              style: TextStyle(
                color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF65676B),
                fontSize: 11.5.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );

    return Material(
      color: itemBg,
      child: InkWell(
        onTap: item.onTap,
        splashColor: isDark ? const Color(0xFF3A3B3C) : const Color(0xFFE5E7EB),
        highlightColor: isDark ? const Color(0xFF2F3031) : const Color(0xFFF3F4F6),
        child: Container(
          constraints: BoxConstraints(minHeight: 52.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              if (!iconOnRight) ...[
                iconWidget,
                SizedBox(width: 14.w),
              ],
              titleColumn,
              if (item.trailing != null) ...[
                item.trailing!,
              ] else if (iconOnRight) ...[
                iconWidget,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Uniform Create-Post / Action Bottom Sheet Container.
/// Uses ScreenUtil (.r, .w, .h) for dark/light rounded top corners and drag handle pill.
class SmoothSheetContainer extends StatelessWidget {
  const SmoothSheetContainer({
    required this.child,
    this.maxHeightFraction = 0.85,
    this.padding,
    super.key,
  });

  final Widget child;
  final double maxHeightFraction;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF1E1F20) : const Color(0xFFF7F7F7);
    final handleColor = isDark ? const Color(0xFF3E4042) : const Color(0xFFD1D5DB);
    final screenHeight = MediaQuery.of(context).size.height;
    final effectivePadding = padding ?? EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 18.h);

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(maxHeight: screenHeight * maxHeightFraction),
          width: double.infinity,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: effectivePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42.w,
                height: 4.5.h,
                decoration: BoxDecoration(
                  color: handleColor,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),
              SizedBox(height: 14.h),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}
