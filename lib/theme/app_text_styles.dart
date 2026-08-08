import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Centralized text styles for Home / Discover / Postpage / Messages
/// Iisang hawak lang — pag binago mo dito, sabay-sabay na lahat.
class KatsText {
  // Facebook-accurate colors: light #050505, dark #E4E6EB
  static const Color _lightBody = Color(0xFF050505);
  static const Color _darkBody = Color(0xFFE4E6EB);
  static const Color _metaLight = Color(0xFF65676B);
  static const Color _metaDark = Color(0xFFB0B3B8);

  static bool _isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  // Ocean theme aware for PostHeader (isDarkTheme)
  static bool _isDarkTheme(BuildContext c, {String themeKey = ''}) {
    if (themeKey.isNotEmpty) {
      return themeKey == 'ocean' ||
          (Theme.of(c).brightness == Brightness.dark && themeKey.isEmpty);
    }
    return Theme.of(c).brightness == Brightness.dark;
  }

  /// Post body — Home/Discover/Postpage (Feed + Post detail text)
  /// SF Pro Rounded alternative: Nunito (rounded, even spacing, clear like Facebook Optimistic)
  static TextStyle postBody(BuildContext c) => TextStyle(fontFamily: 'SF Pro Rounded', 
        fontSize: 13.sp,
        height: 1.33,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w400,
        color: _isDark(c) ? _darkBody : _lightBody,
      );

  /// Post author name — Home/Discover/Postpage (parehas na)
  static TextStyle postAuthor(BuildContext c, {String themeKey = ''}) =>
      TextStyle(fontFamily: 'SF Pro Rounded', 
        fontSize: 13.sp,
        height: 1.33,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w700,
        color: _isDarkTheme(c, themeKey: themeKey) ? _darkBody : _lightBody,
      );

  /// Comment body — Postpage + Comments modal
  static TextStyle commentBody(BuildContext c) => TextStyle(fontFamily: 'SF Pro Rounded', 
        fontSize: 13.sp,
        height: 1.33,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w400,
        color: _isDark(c) ? _darkBody : _lightBody,
      );

  /// Comment/Replies author name
  static TextStyle commentAuthor(BuildContext c) => TextStyle(fontFamily: 'SF Pro Rounded', 
        fontSize: 13.sp,
        height: 1.33,
        letterSpacing: -0.2,
        fontWeight: FontWeight.w700,
        color: _isDark(c) ? _darkBody : _lightBody,
      );

  /// Reply body — same as commentBody (uniform)
  static TextStyle replyBody(BuildContext c) => commentBody(c);

  /// Like/Comment/Repost count label — Feed + Postpage
  static TextStyle countLabel(BuildContext c, Color color) => TextStyle(fontFamily: 'SF Pro Rounded', 
        color: color,
        fontSize: 13.sp,
        fontWeight: FontWeight.w600,
        height: 1.33,
      );

  /// View/Hide replies link
  static TextStyle viewReplies(BuildContext c, {bool isLoading = false}) =>
      TextStyle(fontFamily: 'SF Pro Rounded', 
        color: isLoading ? const Color(0xFF6B7280) : const Color(0xFFFF7A45),
        fontSize: 10.sp,
        fontWeight: FontWeight.w700,
        height: 1.33,
        letterSpacing: -0.2,
      );

  /// Messages thread list
  static TextStyle threadName(BuildContext c) => TextStyle(fontFamily: 'SF Pro Rounded', 
        color: Theme.of(c).colorScheme.onSurface,
        fontSize: 13.sp,
        fontWeight: FontWeight.w800,
        height: 1.33,
      );

  static TextStyle threadPreview(BuildContext c, {bool unread = false}) {
    final isDark = _isDark(c);
    return TextStyle(fontFamily: 'SF Pro Rounded', 
      color: unread
          ? (isDark ? Colors.white : const Color(0xFF111827))
          : const Color(0xFF6B7280),
      fontSize: 13.sp,
      fontWeight: unread ? FontWeight.w700 : FontWeight.w400,
      height: 1.33,
    );
  }

  /// With users line
  static TextStyle withUsers(BuildContext c) => TextStyle(fontFamily: 'SF Pro Rounded', 
        color: const Color(0xFF6B7280),
        fontSize: 12.5.sp,
        fontWeight: FontWeight.w500,
        height: 1.33,
      );

  static TextStyle withUsersLink(BuildContext c) => TextStyle(fontFamily: 'SF Pro Rounded', 
        color: _isDark(c) ? _darkBody : _lightBody,
        fontSize: 12.5.sp,
        fontWeight: FontWeight.w700,
        height: 1.33,
      );

  /// Timestamp — Postcard feed & Postpage (10.5.sp w400 meta)
  static TextStyle timestamp(BuildContext c) {
    final isDark = _isDark(c);
    return TextStyle(fontFamily: 'SF Pro Rounded', 
      color: isDark ? _metaDark : _metaLight,
      fontSize: 10.5.sp,
      fontWeight: FontWeight.w400,
      height: 1.33,
    );
  }
}
