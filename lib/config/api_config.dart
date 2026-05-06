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
    if (url.isEmpty ||
        url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('data:')) {
      return url;
    }

    if (url.startsWith('/')) {
      return '$apiBaseUrl$url';
    }

    return '$apiBaseUrl/$url';
  }
}
