import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomIcons {
  static Widget _svgIcon(String svg, {Color color = Colors.black, double size = 24}) {
    return SvgPicture.string(
      svg,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
    );
  }

  static Widget heart({Color color = Colors.black, double size = 24}) {
    return _svgIcon(_heartSvg, color: color, size: size);
  }

  static Widget heartFilled({Color color = Colors.black, double size = 24}) {
    return _svgIcon(_heartFilledSvg, color: color, size: size);
  }

  static Widget comment({Color color = Colors.black, double size = 24}) {
    return _svgIcon(_commentSvg, color: color, size: size);
  }

  static Widget dm({Color color = Colors.black, double size = 24}) {
    return _svgIcon(_dmSvg, color: color, size: size);
  }

  static Widget ghost({Color color = Colors.black, double size = 24}) {
    return _svgIcon(_ghostSvg, color: color, size: size);
  }

  static Widget share({Color color = Colors.black, double size = 24}) {
    return _svgIcon(_shareSvg, color: color, size: size);
  }

  static Widget repost({Color color = Colors.black, double size = 24}) {
    return _svgIcon(_repostSvg, color: color, size: size);
  }

  static Widget bookmark({Color color = Colors.black, double size = 24, bool isFilled = false}) {
    return _svgIcon(isFilled ? _bookmarkFilledSvg : _bookmarkSvg, color: color, size: size);
  }

  static Widget reels({Color color = Colors.black, double size = 24}) {
    return _svgIcon(_reelsSvg, color: color, size: size);
  }

  static const String _reelsSvg =
      '<svg width="800" height="800" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><rect x="3" y="3" width="18" height="18" rx="5" stroke="#292D32" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M3 9h18" stroke="#292D32" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M8.5 3 6.5 9" stroke="#292D32" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M15.5 3 13.5 9" stroke="#292D32" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M10.5 12.5l4.5 2.5-4.5 2.5v-5z" fill="#292D32"/></svg>';

  static const String _heartSvg =
      '<svg width="800" height="800" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M12.62 20.8101C12.28 20.9301 11.72 20.9301 11.38 20.8101 8.48 19.8201 2 15.6901 2 8.6901c0-3.09 2.49-5.59 5.56-5.59 1.82.0 3.43.88 4.44 2.24 1.01-1.36 2.63-2.24 4.44-2.24 3.07.0 5.56 2.5 5.56 5.59.0 7-6.48 11.13-9.38 12.12z" stroke="#292D32" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  static const String _heartFilledSvg =
      '<svg width="800" height="800" viewBox="0 0 24 24" fill="#292D32" xmlns="http://www.w3.org/2000/svg"><path d="M12.62 20.8101C12.28 20.9301 11.72 20.9301 11.38 20.8101 8.48 19.8201 2 15.6901 2 8.6901c0-3.09 2.49-5.59 5.56-5.59 1.82.0 3.43.88 4.44 2.24 1.01-1.36 2.63-2.24 4.44-2.24 3.07.0 5.56 2.5 5.56 5.59.0 7-6.48 11.13-9.38 12.12z" stroke="#292D32" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  static const String _commentSvg =
      '<svg width="800" height="800" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M8.5 19H8c-4 0-6-1-6-6V8C2 4 4 2 8 2h8c4 0 6 2 6 6v5c0 4-2 6-6 6h-.5C15.19 19 14.89 19.15 14.7 19.4l-1.5 2C12.54 22.28 11.46 22.28 10.8 21.4l-1.5-2C9.14 19.18 8.77 19 8.5 19z" stroke="#292D32" stroke-width="2.2" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M7 8H17" stroke="#292D32" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M7 13h6" stroke="#292D32" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  static const String _shareSvg =
      '<svg width="800" height="800" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M7.39969 6.32015l8.49001-2.83c3.81-1.27 5.88.810000000000001 4.62 4.62l-2.83 8.49005c-1.9 5.71-5.02 5.71-6.92.0L9.91969 14.0802l-2.52-.84c-5.71-1.9-5.71-5.01005.0-6.92005z" stroke="#292D32" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".34" d="M10.1094 13.6501l3.58-3.59" stroke="#292D32" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  static const String _repostSvg =
      '<svg width="800" height="800" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><g opacity=".4"><path d="M3.58008 5.16016H17.4201c1.66.0 3 1.34 3 3V11.4802" stroke="#292D32" stroke-width="2.2" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/><path d="M6.74008 2l-3.16 3.15997 3.16 3.16004" stroke="#292D32" stroke-width="2.2" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/></g><path d="M20.4201 18.84H6.58008c-1.66.0-3-1.34-3-3V12.52" stroke="#292D32" stroke-width="2.2" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/><path d="M17.2598 22.0002l3.16-3.16-3.16-3.16" stroke="#292D32" stroke-width="2.2" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  static const String _bookmarkSvg =
      '<svg width="800" height="800" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><g opacity=".4"><path d="M14.5 10.6504h-5" stroke="#292D32" stroke-width="2.2" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/><path d="M12 8.20996V13.21" stroke="#292D32" stroke-width="2.2" stroke-miterlimit="10" stroke-linecap="round" stroke-linejoin="round"/></g><path d="M16.8203 2H7.18031c-2.13.0-3.86 1.74-3.86 3.86V19.95c0 1.8 1.29 2.56 2.87 1.69l4.87999-2.71C11.5903 18.64 12.4303 18.64 12.9403 18.93l4.88 2.71C19.4003 22.52 20.6903 21.76 20.6903 19.95V5.86C20.6803 3.74 18.9503 2 16.8203 2z" stroke="#292D32" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  static const String _bookmarkFilledSvg =
      '<svg width="800" height="800" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg"><path d="M16.8203 2H7.18031c-2.13.0-3.86 1.74-3.86 3.86V19.95c0 1.8 1.29 2.56 2.87 1.69l4.87999-2.71C11.5903 18.64 12.4303 18.64 12.9403 18.93l4.88 2.71C19.4003 22.52 20.6903 21.76 20.6903 19.95V5.86C20.6803 3.74 18.9503 2 16.8203 2z" fill="#292D32" stroke="#292D32" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  static const String _dmSvg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"><path opacity=".4" d="M18.4698 16.83L18.8598 19.99C18.9598 20.82 18.0698 21.4 17.3598 20.97l-4.19-2.49C12.7098 18.48 12.2599 18.45 11.8199 18.39 12.5599 17.52 12.9998 16.42 12.9998 15.23c0-2.84-2.46-5.14-5.49995-5.14-1.16 0-2.23.33-3.12.91C4.34985 10.75 4.33984 10.5 4.33984 10.24 4.33984 5.68999 8.28985 2 13.1698 2c4.88 0 8.83 3.68999 8.83 8.24 0 2.7-1.39 5.09-3.53 6.59z" stroke="#292d32" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/><path d="M13 15.2298c0 1.19-.44 2.29-1.18 3.16-.99 1.2-2.56 1.97-4.32 1.97l-2.61 1.55C4.45 22.1798 3.89 21.8098 3.95 21.2998l.25-1.97c-1.34-.93-2.2-2.42-2.2-4.1 0-1.76.94-3.31 2.38-4.23.89-.58 1.96-.91 3.12-.91 3.04 0 5.5 2.3 5.5 5.14z" stroke="#292d32" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>';

  static const String _ghostSvg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none"><path d="M22 20.07V12.18C22 6.57999 17.5 2 12 2S2 6.57999 2 12.18v7.89C2 21.33 2.74998 21.67 3.66998 20.83L4.66998 19.92C5.03998 19.58 5.64001 19.58 6.01001 19.92l2 1.83c.37.34.96997.34 1.33997.0L11.35 19.92C11.72 19.58 12.32 19.58 12.69 19.92l2 1.83C15.06 22.09 15.66 22.09 16.03 21.75l2-1.83C18.4 19.58 19 19.58 19.37 19.92L20.37 20.83C21.25 21.67 22 21.33 22 20.07z" stroke="#292D32" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M8 14c2.37 1.78 5.63 1.78 8 0" stroke="#292D32" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path opacity=".4" d="M12 11c1.1046.0 2-.8954 2-2 0-1.10457-.8954-2-2-2s-2 .89543-2 2c0 1.1046.8954 2 2 2z" stroke="#292D32" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/></svg>';

}
