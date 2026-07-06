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

  static Widget share({Color color = Colors.black, double size = 24}) {
    return _svgIcon(_shareSvg, color: color, size: size);
  }

  static Widget repost({Color color = Colors.black, double size = 24}) {
    return _svgIcon(_repostSvg, color: color, size: size);
  }

  static Widget bookmark({Color color = Colors.black, double size = 24, bool isFilled = false}) {
    return _svgIcon(isFilled ? _bookmarkFilledSvg : _bookmarkSvg, color: color, size: size);
  }

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

}
