class ApiConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://laws-johnson-forums-accounts.trycloudflare.com',
  );

  static const String loginPath = '/api/auth/login';
  static const String logoutPath = '/api/auth/logout';
  static const String mePath = '/api/me';
  static const String feedPath = '/api/feed';
  static const String storiesPath = '/api/stories';
  static const String notificationsUnreadCountPath =
      '/api/notifications/unread-count';
  static const String playlistsPath = '/api/playlists';
  static const String musicLibrarySearchPath = '/api/music-library/search';

  static String playlistPath(int playlistId) => '/api/playlists/$playlistId';

  static String playlistTrackUploadPath(int playlistId) =>
      '/api/playlists/$playlistId/tracks/upload-audio';

  static String playlistTrackFromLibraryPath(int playlistId) =>
      '/api/playlists/$playlistId/tracks/from-library';

  static String playlistTrackPath(int playlistId, int trackId) =>
      '/api/playlists/$playlistId/tracks/$trackId';

  static String playlistReorderPath(int playlistId) =>
      '/api/playlists/$playlistId/tracks/reorder';

  static String userPlaylistsPath(String username) =>
      '/api/users/$username/playlists';

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

  static String postcardUrl(String fileName) {
    final name = fileName.split('/').last.trim();
    return 'https://raw.githubusercontent.com/jenrielreyes2023-blip/katsklub-flutter-app/main/deploy_postcards/$name';
  }
}
