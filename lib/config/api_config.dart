class ApiConfig {
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://katsklub.top',
  );

  static const String loginPath = '/api/auth/login';
  static const String logoutPath = '/api/auth/logout';
  static const String mePath = '/api/me';

  static Uri uri(String path) {
    return Uri.parse('$apiBaseUrl$path');
  }
}
