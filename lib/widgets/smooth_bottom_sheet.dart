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
/// Ensures 100% uniform design, typography (12.sp bold), compact spacing, and ScreenUtil responsiveness.
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
        const sheetBg = Color(0xFF101012);
        const cardBg = Color(0xFF1E1E20);
        const dragHandleColor = Color(0xFF38383A);
        const dividerColor = Color(0xFF2C2C2E);

        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 14.h + bottomPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Standard Drag Handle Pill
              Container(
                width: 36.w,
                height: 3.5.h,
                margin: EdgeInsets.only(bottom: 10.h),
                decoration: BoxDecoration(
                  color: dragHandleColor,
                  borderRadius: BorderRadius.circular(999.r),
                ),
              ),

              if (title != null && title.isNotEmpty) ...[
                Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontFamily: 'SF Pro Rounded',
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],

              // Standard Rounded Island Card Wrapper
              ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: DecoratedBox(
                  decoration: const BoxDecoration(color: cardBg),
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
                            padding: EdgeInsets.only(left: 14.w),
                            child: const Divider(
                              height: 1,
                              thickness: 0.5,
                              color: dividerColor,
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
          padding: padding ?? EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 14.h),
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
    const itemBg = Color(0xFF1E1E20);
    final itemFg =
        item.isDestructive ? const Color(0xFFED4956) : Colors.white;

    final iconWidget = Icon(
      item.icon,
      color: itemFg,
      size: 18.5.r,
    );

    final titleColumn = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.title,
            style: TextStyle(
              fontFamily: 'SF Pro Rounded',
              color: itemFg,
              fontSize: 13.5.sp,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
          if (item.subtitle != null && item.subtitle!.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Text(
              item.subtitle!,
              style: TextStyle(
                fontFamily: 'SF Pro Rounded',
                color: const Color(0xFF8E8E93),
                fontSize: 10.5.sp,
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
        splashColor: const Color(0xFF3A3B3C),
        highlightColor: const Color(0xFF2F3031),
        child: Container(
          constraints: BoxConstraints(minHeight: 44.h),
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.5.h),
          child: Row(
            children: [
              if (!iconOnRight) ...[
                iconWidget,
                SizedBox(width: 12.w),
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
    this.maxHeightFraction = 0.88,
    this.padding,
    this.backgroundColor,
    this.handleColor,
    this.showHandle = true,
    super.key,
  });

  final Widget child;
  final double maxHeightFraction;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;
  final Color? handleColor;
  final bool showHandle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? const Color(0xFF101012) : const Color(0xFFF2F2F7);
    final defaultHandle = isDark ? const Color(0xFF38383A) : const Color(0xFFD1D1D6);
    final effectiveBg = backgroundColor ?? defaultBg;
    final effectiveHandle = handleColor ?? defaultHandle;
    final screenHeight = MediaQuery.of(context).size.height;
    final effectivePadding = padding ?? EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 12.h);

    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(maxHeight: screenHeight * maxHeightFraction),
          width: double.infinity,
          decoration: BoxDecoration(
            color: effectiveBg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: effectivePadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showHandle) ...[
                Container(
                  width: 36.w,
                  height: 3.5.h,
                  margin: EdgeInsets.only(bottom: 10.h),
                  decoration: BoxDecoration(
                    color: effectiveHandle,
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
              ],
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

