import 'package:flutter/material.dart';

import '../config/api_config.dart';

class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    required this.imageUrls,
    required this.initialIndex,
    super.key,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.imageUrls.length - 1).toInt();
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_currentIndex + 1} / ${widget.imageUrls.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemBuilder: (context, index) {
          final url = widget.imageUrls[index];
          return InteractiveViewer(
            child: Center(
              child: url.startsWith('sample://')
                  ? Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: const Color(0xFF111827),
                      child: const Icon(
                        Icons.image_outlined,
                        color: Colors.white70,
                        size: 72,
                      ),
                    )
                  : Image.network(
                      ApiConfig.assetUrl(url),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.white,
                        size: 56,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}
