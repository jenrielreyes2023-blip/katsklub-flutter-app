import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/image_viewer_screen.dart';
import 'hashtag_text.dart';

class CommentContent extends StatelessWidget {
  final String text;
  final TextStyle style;
  final ValueChanged<String>? onHashtagTap;
  final ValueChanged<String>? onMentionTap;
  final List<InlineSpan>? prefixSpans;

  const CommentContent({
    super.key,
    required this.text,
    required this.style,
    this.onHashtagTap,
    this.onMentionTap,
    this.prefixSpans,
  });

  static final RegExp _gifRegex = RegExp(
    r'(https?:\/\/[^\s]+(?:\.gif|\/200\.gif|\/giphy\.gif|giphy\.com|tenor\.com|klipy\.com)[^\s]*)',
    caseSensitive: false,
  );

  @override
  Widget build(BuildContext context) {
    final match = _gifRegex.firstMatch(text);
    if (match == null) {
      return HashtagText(
        text: text,
        style: style,
        onHashtagTap: onHashtagTap ?? (_) {},
        onMentionTap: onMentionTap,
        prefixSpans: prefixSpans,
      );
    }

    final gifUrl = match.group(0)!;
    final cleanText = text.replaceFirst(gifUrl, '').trim();
    final hasText = cleanText.isNotEmpty;
    final hasPrefix = prefixSpans != null && prefixSpans!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasText || hasPrefix) ...[
          HashtagText(
            text: cleanText,
            style: style,
            onHashtagTap: onHashtagTap ?? (_) {},
            onMentionTap: onMentionTap,
            prefixSpans: prefixSpans,
          ),
          SizedBox(height: 6.h),
        ],
        GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ImageViewerScreen(
                  imageUrls: [gifUrl],
                  initialIndex: 0,
                ),
              ),
            );
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: 180.h,
                maxWidth: 240.w,
              ),
              child: RepaintBoundary(
                child: CachedNetworkImage(
                  imageUrl: gifUrl,
                  fit: BoxFit.cover,
                  memCacheHeight: (180.h * 2).round().clamp(160, 400),
                  memCacheWidth: (240.w * 2).round().clamp(200, 500),
                  fadeInDuration: const Duration(milliseconds: 120),
                placeholder: (context, url) => Container(
                  height: 120.h,
                  width: 160.w,
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white10
                        : Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image_rounded, size: 16, color: Colors.redAccent),
                      SizedBox(width: 4.w),
                      Text(
                        'GIF unavailable',
                        style: TextStyle(fontSize: 11.sp, color: Colors.redAccent),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
    );
  }
}
