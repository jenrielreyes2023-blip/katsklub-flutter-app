class ApiConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://katsklub.top',
  );

  static const String loginPath = '/api/auth/login';
  static const String logoutPath = '/api/auth/logout';
  static const String mePath = '/api/me';
  static const String feedPath = '/api/feed';
  static const String storiesPath = '/api/stories';
  static const String notificationsUnreadCountPath =
      '/api/notifications/unread-count';

  static Uri uri(String path) {
    return Uri.parse('$apiBaseUrl$path');
  }

  static String assetUrl(String value) {
    final url = value.trim();
    if (url.isEmpty || url.startsWith('data:')) {
      return url;
    }

    if (url.startsWith('http://') || url.startsWith('https://')) {
      final assetUri = Uri.tryParse(url);
      final apiUri = Uri.tryParse(apiBaseUrl);
      if (assetUri == null || apiUri == null) {
        return url;
      }

      final sameOrigin = assetUri.scheme == apiUri.scheme &&
          assetUri.host == apiUri.host &&
          _normalizedPort(assetUri) == _normalizedPort(apiUri);

      if (sameOrigin) {
        return url;
      }

      final encodedUrl = Uri.encodeQueryComponent(url);
      return '$apiBaseUrl/api/proxy-media?url=$encodedUrl';
    }

    if (url.startsWith('/')) {
      return '$apiBaseUrl$url';
    }

    return '$apiBaseUrl/$url';
  }

  static int _normalizedPort(Uri uri) {
    if (uri.hasPort) {
      return uri.port;
    }

    return uri.scheme == 'https' ? 443 : 80;
  }
}
