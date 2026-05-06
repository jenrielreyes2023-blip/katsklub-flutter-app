import 'package:flutter/material.dart';

import '../config/api_config.dart';

class PostImageGrid extends StatelessWidget {
  const PostImageGrid({
    required this.imageUrls,
    this.onImageTap,
    super.key,
  });

  final List<String> imageUrls;
  final ValueChanged<int>? onImageTap;

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return const SizedBox.shrink();
    }

    final visibleImages = imageUrls.take(4).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: visibleImages.length == 1 ? 1.12 : 1,
        child: GridView.builder(
          itemCount: visibleImages.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: visibleImages.length == 1 ? 1 : 2,
            mainAxisSpacing: 2,
            crossAxisSpacing: 2,
          ),
          itemBuilder: (context, index) {
            final extraCount = imageUrls.length - 4;
            final showExtraCount = index == 3 && extraCount > 0;

            return GestureDetector(
              onTap: () => onImageTap?.call(index),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _GridImage(url: visibleImages[index], index: index),
                  if (showExtraCount)
                    Container(
                      color: Colors.black.withOpacity(0.45),
                      alignment: Alignment.center,
                      child: Text(
                        '+$extraCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _GridImage extends StatelessWidget {
  const _GridImage({
    required this.url,
    required this.index,
  });

  final String url;
  final int index;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('sample://')) {
      final gradients = [
        const [Color(0xFF60A5FA), Color(0xFFA78BFA)],
        const [Color(0xFFF97316), Color(0xFFFACC15)],
        const [Color(0xFF34D399), Color(0xFF06B6D4)],
        const [Color(0xFFFB7185), Color(0xFFC084FC)],
      ];
      final colors = gradients[index % gradients.length];

      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Icon(
          Icons.image_outlined,
          color: Colors.white.withOpacity(0.82),
          size: 34,
        ),
      );
    }

    return Image.network(
      ApiConfig.assetUrl(url),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: const Color(0xFFE5E7EB),
        child: const Icon(Icons.image_not_supported_outlined),
      ),
    );
  }
}
