import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../services/feed_service.dart';
import '../screens/user_profile_screen.dart';
import '../utils/emoji_presentation.dart';
import 'post_image_grid.dart';
import 'post_card.dart';
import 'gold_shimmer_text.dart';

class RepostSourcePreview extends StatefulWidget {
  const RepostSourcePreview({
    required this.post,
    this.label,
    this.onTap,
    super.key,
  });

  final Post post;
  final String? label;
  final VoidCallback? onTap;

  @override
  State<RepostSourcePreview> createState() => _RepostSourcePreviewState();
}

class _RepostSourcePreviewState extends State<RepostSourcePreview> {
  final FeedService _feedService = FeedService();
  late bool _isFollowingAuthor;
  bool _isFollowPending = false;
  DateTime? _lastInteractiveSurfaceTapAt;

  @override
  void initState() {
    super.initState();
    _isFollowingAuthor = widget.post.isFollowingAuthor;
  }

  @override
  void didUpdateWidget(covariant RepostSourcePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.isFollowingAuthor != widget.post.isFollowingAuthor) {
      _isFollowingAuthor = widget.post.isFollowingAuthor;
      _isFollowPending = false;
    }
  }

  void _markInteractiveSurfaceTap() {
    _lastInteractiveSurfaceTapAt = DateTime.now();
  }

  bool _shouldSuppressBodyTap() {
    final tappedAt = _lastInteractiveSurfaceTapAt;
    if (tappedAt == null) {
      return false;
    }

    return DateTime.now().difference(tappedAt) <
        const Duration(milliseconds: 300);
  }

  void _openAuthorProfile() {
    _markInteractiveSurfaceTap();
    final username = widget.post.authorUsername.trim();
    if (username.isEmpty) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(username: username),
      ),
    );
  }

  Future<void> _followAuthor() async {
    _markInteractiveSurfaceTap();
    final username = widget.post.authorUsername.trim();
    if (username.isEmpty || _isFollowPending || _isFollowingAuthor || widget.post.ownedByMe) {
      return;
    }

    setState(() {
      _isFollowPending = true;
    });

    try {
      await _feedService.followUser(username);
      if (!mounted) {
        return;
      }
      setState(() {
        _isFollowPending = false;
        _isFollowingAuthor = true;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isFollowPending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to follow user.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isDark ? const Color(0xFF242526) : const Color(0xFFF9FAFB);
    final borderColor = isDark ? const Color(0xFF2D2E30) : const Color(0xFFE5E7EB);
    final titleColor = isDark ? Colors.white : const Color(0xFF111827);
    final subtitleColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    const activeOrange = Color(0xFFFF7A45);

    final content = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: isDark ? const Color(0xFF18191A) : const Color(0xFFE5E7EB),
                    backgroundImage: post.authorAvatarUrl.trim().isEmpty
                        ? null
                        : CachedNetworkImageProvider(_resolveUrl(post.authorAvatarUrl)),
                    child: post.authorAvatarUrl.trim().isEmpty
                        ? Text(
                            post.authorInitials,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (_) => _markInteractiveSurfaceTap(),
                                onTap: _openAuthorProfile,
                                child: post.authorUsername.toLowerCase() == 'gemini'
                                    ? GoldShimmerText(
                                        text: post.authorFullName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      )
                                    : Text(
                                        post.authorFullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: titleColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                              ),
                            ),
                            if (post.authorIsVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.verified,
                                color: activeOrange,
                                size: 15,
                              ),
                            ],
                            if (!post.ownedByMe) ...[
                              const SizedBox(width: 6),
                              Text(
                                '·',
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (_isFollowingAuthor || _isFollowPending)
                                    ? null
                                    : (_) => _markInteractiveSurfaceTap(),
                                onTap: (_isFollowingAuthor || _isFollowPending)
                                    ? null
                                    : _followAuthor,
                                child: SizedBox(
                                  height: 16,
                                  child: Center(
                                    child: _isFollowPending
                                        ? const SizedBox(
                                            width: 12,
                                            height: 12,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.8,
                                              color: activeOrange,
                                            ),
                                          )
                                        : Text(
                                            _isFollowingAuthor ? 'Following' : 'Follow',
                                            style: TextStyle(
                                              color: _isFollowingAuthor
                                                  ? subtitleColor
                                                  : activeOrange,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              height: 1.0,
                                            ),
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _formatTimestamp(post.createdAt),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: subtitleColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (post.privacyLabel.isNotEmpty) ...[
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  '·',
                                  style: TextStyle(
                                    color: subtitleColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(
                                _getPrivacyIcon(post.visibility),
                                color: subtitleColor,
                                size: 13,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (post.displayTitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Text(
                  post.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            if (post.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: _ExpandableRepostText(
                  text: post.text.trim(),
                  textColor: titleColor,
                ),
              ),
            if (post.imageUrls.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: IgnorePointer(
                  child: PostImageGrid(
                    imageUrls: post.imageUrls,
                    initialAspectRatios: post.imageAspectRatios,
                    postId: 'repost-${post.id}',
                  ),
                ),
              )
            else if (post.hasVideo)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: IgnorePointer(
                  child: VideoPreviewCard(post: post),
                ),
              )
            else if (_hasMediaPreview)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: _SourceMediaPreview(post: post),
              )
            else
              const SizedBox(height: 14),
          ],
        ),
      ),
    );

    final body = widget.onTap == null
        ? content
        : Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                if (_shouldSuppressBodyTap()) {
                  return;
                }
                widget.onTap?.call();
              },
              child: content,
            ),
          );

    final cleanLabel = widget.label?.trim();
    if (cleanLabel == null || cleanLabel.isEmpty) {
      return body;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          cleanLabel,
          style: TextStyle(
            color: subtitleColor,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        body,
      ],
    );
  }

  String _formatTimestamp(DateTime? createdAt) {
    if (createdAt == null) {
      return 'Now';
    }

    final diff = DateTime.now().difference(createdAt.toLocal());
    if (diff.inMinutes < 1) {
      return 'Now';
    }
    if (diff.inHours < 1) {
      return '${diff.inMinutes}m';
    }
    if (diff.inDays < 1) {
      return '${diff.inHours}h';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}d';
    }

    const monthNames = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final month = monthNames[createdAt.month - 1];
    return '$month ${createdAt.day}, ${createdAt.year}';
  }

  bool get _hasMediaPreview {
    if (widget.post.imageUrls.isNotEmpty) {
      return true;
    }
    if (widget.post.hasVideo || widget.post.youtubeVideoId.trim().isNotEmpty) {
      return true;
    }
    final preview = widget.post.resolvedLinkPreview;
    return preview != null && preview.imageUrl.trim().isNotEmpty;
  }

  static String _resolveUrl(String raw) {
    final value = raw.trim();
    if (value.startsWith('http://') || value.startsWith('https://') || value.startsWith('data:')) {
      return value;
    }
    return ApiConfig.assetUrl(value);
  }
}

class _SourceMediaPreview extends StatelessWidget {
  const _SourceMediaPreview({
    required this.post,
  });

  final Post post;

  @override
  Widget build(BuildContext context) {
    final imageCount = post.imageUrls.length;
    final preview = post.resolvedLinkPreview;
    final isYouTube = post.youtubeVideoId.trim().isNotEmpty;
    final mediaUrl = imageCount > 0
        ? _resolveUrl(post.imageUrls.first)
        : post.hasVideo
            ? _resolveUrl(post.primaryVideoPosterUrl)
            : preview != null && preview.imageUrl.trim().isNotEmpty
                ? _resolveUrl(preview.imageUrl)
                : '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (mediaUrl.isNotEmpty)
              Image.network(
                mediaUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback(context),
              )
            else
              _fallback(context),
            if (post.hasVideo || isYouTube)
              Container(color: Colors.black.withValues(alpha: 0.18)),
            if (post.hasVideo || isYouTube)
              Center(
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.56),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            if (imageCount > 1)
              Positioned(
                right: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.66),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '+${imageCount - 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (isYouTube)
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xCCDC2626),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'YouTube',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )
            else if (preview != null && preview.domain.trim().isNotEmpty)
              Positioned(
                left: 10,
                top: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.66),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    preview.domain.trim(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      color: isDark ? const Color(0xFF1C1E21) : const Color(0xFFE5E7EB),
      child: Center(
        child: Icon(
          post.hasVideo || post.youtubeVideoId.trim().isNotEmpty
              ? Icons.play_circle_outline_rounded
              : Icons.image_outlined,
          size: 38,
          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  static String _resolveUrl(String raw) {
    final value = raw.trim();
    if (value.startsWith('http://') || value.startsWith('https://') || value.startsWith('data:')) {
      return value;
    }
    return ApiConfig.assetUrl(value);
  }
}


class _ExpandableRepostText extends StatefulWidget {
  const _ExpandableRepostText({
    required this.text,
    required this.textColor,
  });

  final String text;
  final Color textColor;

  @override
  State<_ExpandableRepostText> createState() => _ExpandableRepostTextState();
}

class _ExpandableRepostTextState extends State<_ExpandableRepostText> {
  static const int _collapsedMaxLines = 4;
  TextStyle get _textStyle => TextStyle(
        color: widget.textColor,
        fontSize: 14,
        height: 1.35,
      );

  bool _expanded = false;

  String? _cachedText;
  double? _cachedMaxWidth;
  bool? _cachedIsLongText;
  String? _cachedCollapsedText;

  bool _fits({
    required String value,
    required double maxWidth,
    required TextDirection textDirection,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: _textStyle),
      textDirection: textDirection,
      maxLines: _collapsedMaxLines,
    )..layout(maxWidth: maxWidth);

    return !painter.didExceedMaxLines;
  }

  String _wholeWordCollapsedText({
    required double maxWidth,
    required TextDirection textDirection,
  }) {
    final text = widget.text;
    if (_fits(
      value: text,
      maxWidth: maxWidth,
      textDirection: textDirection,
    )) {
      return text;
    }

    final candidateEnds = <int>[];
    for (final match in RegExp(r'\s+').allMatches(text)) {
      final end = match.start;
      if (end > 0) {
        candidateEnds.add(end);
      }
    }

    if (candidateEnds.isEmpty) {
      return text;
    }

    var low = 0;
    var high = candidateEnds.length - 1;
    var bestEnd = candidateEnds.first;

    while (low <= high) {
      final mid = (low + high) ~/ 2;
      final end = candidateEnds[mid];
      final candidate = text.substring(0, end).trimRight();

      if (_fits(
        value: candidate,
        maxWidth: maxWidth,
        textDirection: textDirection,
      )) {
        bestEnd = end;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return text.substring(0, bestEnd).trimRight();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textDirection = Directionality.of(context);
        final currentText = widget.text;
        final currentMaxWidth = constraints.maxWidth;

        final bool isLongText;
        final String collapsedText;

        if (_cachedText == currentText &&
            _cachedMaxWidth == currentMaxWidth &&
            _cachedIsLongText != null &&
            _cachedCollapsedText != null) {
          isLongText = _cachedIsLongText!;
          collapsedText = _cachedCollapsedText!;
        } else {
          isLongText = !_fits(
            value: currentText,
            maxWidth: currentMaxWidth,
            textDirection: textDirection,
          );

          collapsedText = isLongText
              ? _wholeWordCollapsedText(
                  maxWidth: currentMaxWidth,
                  textDirection: textDirection,
                )
              : currentText;

          _cachedText = currentText;
          _cachedMaxWidth = currentMaxWidth;
          _cachedIsLongText = isLongText;
          _cachedCollapsedText = collapsedText;
        }

        void toggleExpanded() {
          if (!isLongText) {
            return;
          }
          setState(() {
            _expanded = !_expanded;
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: isLongText ? toggleExpanded : null,
              child: Text(
                ensureEmojiPresentation(_expanded ? widget.text : collapsedText),
                style: _textStyle,
              ),
            ),
            if (isLongText) ...[
              const SizedBox(height: 4),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: toggleExpanded,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    _expanded ? 'See less' : 'See more',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF7A45),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

IconData _getPrivacyIcon(String visibility) {
  switch (visibility) {
    case 'friends':
      return Icons.people_alt_rounded;
    case 'only_me':
      return Icons.lock_rounded;
    default:
      return Icons.public_rounded;
  }
}
