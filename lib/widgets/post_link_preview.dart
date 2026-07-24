import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/post.dart'; // For LinkPreview
import 'loading_skeletons.dart'; // For SkeletonPulse

class YouTubePreviewCard extends StatelessWidget {
  const YouTubePreviewCard({
    required this.preview,
    required this.onTap,
    this.onTapDown,
    super.key,
  });

  final LinkPreview preview;
  final Future<void> Function() onTap;
  final VoidCallback? onTapDown;

  @override
  Widget build(BuildContext context) {
    final imageUrl = preview.imageUrl.trim();
    final title = preview.title.trim().isNotEmpty
        ? preview.title.trim()
        : 'YouTube video';
    final description = preview.description.trim();

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onTapDown?.call(),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl.isNotEmpty)
                  CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    memCacheWidth: 800,
                    maxWidthDiskCache: 800,
                    placeholder: (_, __) => const _ImageLoadingPlaceholder(),
                    errorWidget: (_, __, ___) => _fallback(),
                  )
                else
                  _fallback(),
                Container(
                  color: Colors.black.withValues(alpha: 0.22),
                ),
                Center(
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.56),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFFB0B3B8)
                      : const Color(0xFF65676B),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: const Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: Color(0xFF65676B),
          size: 44,
        ),
      ),
    );
  }
}

class LinkPreviewCard extends StatelessWidget {
  const LinkPreviewCard({
    required this.preview,
    required this.onTap,
    this.onTapDown,
    this.isYouTube = false,
    super.key,
  });

  final LinkPreview preview;
  final Future<void> Function() onTap;
  final VoidCallback? onTapDown;
  final bool isYouTube;

  @override
  Widget build(BuildContext context) {
    final imageUrl = preview.imageUrl.trim();
    final title = preview.title.trim().isNotEmpty
        ? preview.title.trim()
        : preview.domain.trim();
    final description = preview.description.trim();
    final domain = preview.domain.trim().isNotEmpty
        ? preview.domain.trim()
        : preview.url.trim();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF242526) : const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTapDown: (_) => onTapDown?.call(),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark ? const Color(0xFF2F3031) : const Color(0xFFE5E7EB),
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  child: AspectRatio(
                    aspectRatio: 1.91,
                    child: CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      memCacheWidth: 800,
                      maxWidthDiskCache: 800,
                      placeholder: (_, __) => const _ImageLoadingPlaceholder(),
                      errorWidget: (_, __, ___) => _linkFallback(),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isYouTube) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'YouTube',
                              style: TextStyle(
                                color: Color(0xFFDC2626),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            domain,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF65676B),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isDark ? const Color(0xFFB0B3B8) : const Color(0xFF65676B),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _linkFallback() {
    return Container(
      color: const Color(0xFFE5E7EB),
      child: Center(
        child: Icon(
          isYouTube ? Icons.play_circle_outline_rounded : Icons.link_rounded,
          color: const Color(0xFF65676B),
          size: 34,
        ),
      ),
    );
  }
}

class _ImageLoadingPlaceholder extends StatelessWidget {
  const _ImageLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulse(
      child: ColoredBox(
        color: Color(0xFFE6EBF2),
        child: SizedBox.expand(),
      ),
    );
  }
}
