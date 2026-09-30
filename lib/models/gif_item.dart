class GifItem {
  final String id;
  final String title;
  final String url;
  final String previewUrl;
  final int? width;
  final int? height;

  const GifItem({
    required this.id,
    required this.title,
    required this.url,
    required this.previewUrl,
    this.width,
    this.height,
  });

  factory GifItem.fromJson(Map<String, dynamic> json) {
    // Check if coming from our backend normalized API
    if (json.containsKey('previewUrl')) {
      return GifItem(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? 'GIF',
        url: json['url']?.toString() ?? '',
        previewUrl: json['previewUrl']?.toString() ?? (json['url']?.toString() ?? ''),
        width: json['width'] is int ? json['width'] as int : int.tryParse(json['width']?.toString() ?? ''),
        height: json['height'] is int ? json['height'] as int : int.tryParse(json['height']?.toString() ?? ''),
      );
    }

    // Direct Giphy API JSON
    final images = json['images'] as Map<String, dynamic>? ?? {};
    final fixedHeight = images['fixed_height'] as Map<String, dynamic>? ?? {};
    final downsized = images['downsized'] as Map<String, dynamic>? ?? {};
    final original = images['original'] as Map<String, dynamic>? ?? {};
    final preview = images['fixed_height_small'] as Map<String, dynamic>? ??
        images['fixed_width_small'] as Map<String, dynamic>? ??
        fixedHeight;

    final fullUrl = fixedHeight['url']?.toString() ??
        downsized['url']?.toString() ??
        original['url']?.toString() ??
        '';

    final smallUrl = preview['url']?.toString() ?? fullUrl;

    return GifItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'GIF',
      url: fullUrl,
      previewUrl: smallUrl,
      width: int.tryParse(fixedHeight['width']?.toString() ?? ''),
      height: int.tryParse(fixedHeight['height']?.toString() ?? ''),
    );
  }
}
