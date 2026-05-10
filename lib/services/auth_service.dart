import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/user.dart';

class AuthResult {
  const AuthResult({
    required this.ok,
    this.user,
    this.error,
  });

  final bool ok;
  final User? user;
  final String? error;
}

class AuthService {
  static const String sessionCookieKey = 'katsklub_session_cookie';
  static const String _authTokenKey = 'katsklub_auth_token';
  static const String _userKey = 'katsklub_user';

  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  Future<AuthResult> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final response = await _client.post(
        ApiConfig.uri(ApiConfig.loginPath),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'identifier': identifier.trim(),
          'password': password,
        }),
      );

      final data = _decodeJsonObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AuthResult(
          ok: false,
          error: _readError(data) ?? 'Login failed. Please try again.',
        );
      }

      final user = _readUser(data);
      if (user == null) {
        return const AuthResult(
          ok: false,
          error: 'Login succeeded but no user was returned.',
        );
      }

      final savedToken = await _saveAuthData(
        response: response,
        responseData: data,
        user: user,
      );

      final verifiedUser =
          savedToken == null ? null : await _fetchMe(token: savedToken);
      if (verifiedUser != null) {
        await _saveUser(verifiedUser);
        return AuthResult(ok: true, user: verifiedUser);
      }

      return AuthResult(ok: true, user: user);
    } catch (_) {
      return const AuthResult(
        ok: false,
        error: 'Unable to connect to KatsKlub. Check your internet connection.',
      );
    }
  }

  Future<User?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString(_userKey);
    final savedToken = await getToken();

    if (savedUser == null || savedToken == null || savedToken.isEmpty) {
      return null;
    }

    final verifiedUser = await _fetchMe(token: savedToken);
    if (verifiedUser != null) {
      await prefs.setString(_userKey, jsonEncode(verifiedUser.toJson()));
      return verifiedUser;
    }

    await logout();
    return null;
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCookie = prefs.getString(sessionCookieKey);
    final savedToken = prefs.getString(_authTokenKey);

    if ((savedCookie != null && savedCookie.isNotEmpty) ||
        (savedToken != null && savedToken.isNotEmpty)) {
      try {
        await _client.post(
          ApiConfig.uri(ApiConfig.logoutPath),
          headers: _buildAuthHeaders(
            token: savedToken,
            cookie: savedCookie,
          ),
        );
      } catch (_) {
        // Local logout must still work even if the network request fails.
      }
    }

    await prefs.remove(sessionCookieKey);
    await prefs.remove(_authTokenKey);
    await prefs.remove(_userKey);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString(_authTokenKey)?.trim();
    if (savedToken != null && savedToken.isNotEmpty) {
      return savedToken;
    }

    final savedCookie = prefs.getString(sessionCookieKey);
    final cookieToken = _extractSessionToken(savedCookie);
    if (cookieToken != null && cookieToken.isNotEmpty) {
      await prefs.setString(_authTokenKey, cookieToken);
      return cookieToken;
    }

    return null;
  }

  Future<User?> _fetchMe({
    required String token,
    String? cookie,
  }) async {
    try {
      final response = await _client.get(
        ApiConfig.uri(ApiConfig.mePath),
        headers: _buildAuthHeaders(
          token: token,
          cookie: cookie,
        ),
      );

      if (response.statusCode != 200) {
        return null;
      }

      return _readUser(_decodeJsonObject(response.body));
    } catch (_) {
      return null;
    }
  }

  Future<String?> _saveAuthData({
    required http.Response response,
    required Map<String, dynamic> responseData,
    required User user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final cookie = _extractCookieHeader(response.headers['set-cookie']);
    final responseToken = responseData['token'];
    final cookieToken = _extractSessionToken(cookie);
    final token = responseToken is String && responseToken.isNotEmpty
        ? responseToken
        : cookieToken;

    if (cookie != null && cookie.isNotEmpty) {
      await prefs.setString(sessionCookieKey, cookie);
    }

    if (token != null && token.isNotEmpty) {
      await prefs.setString(_authTokenKey, token);
    }

    await _saveUser(user);
    return token;
  }

  Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toJson()));
  }

  Map<String, dynamic> _decodeJsonObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }

    return <String, dynamic>{};
  }

  User? _readUser(Map<String, dynamic> data) {
    final user = data['user'];
    if (user is Map<String, dynamic>) {
      return User.fromJson(user);
    }

    return null;
  }

  String? _readError(Map<String, dynamic> data) {
    final error = data['error'];
    if (error is String && error.trim().isNotEmpty) {
      return error;
    }

    return null;
  }

  String? _extractCookieHeader(String? setCookieHeader) {
    if (setCookieHeader == null || setCookieHeader.isEmpty) {
      return null;
    }

    final cookies = setCookieHeader
        .split(RegExp(r', (?=[^;,]+=)'))
        .map((cookie) => cookie.split(';').first.trim())
        .where((cookie) => cookie.isNotEmpty)
        .toList();

    if (cookies.isEmpty) {
      return null;
    }

    return cookies.join('; ');
  }

  String? _extractSessionToken(String? cookieHeader) {
    final cookie = cookieHeader?.trim();
    if (cookie == null || cookie.isEmpty) {
      return null;
    }

    for (final part in cookie.split(RegExp(r';\s*'))) {
      final trimmed = part.trim();
      if (!trimmed.toLowerCase().startsWith('katsklub_session=')) {
        continue;
      }
      final rawValue = trimmed.substring('katsklub_session='.length).trim();
      if (rawValue.isEmpty) {
        return null;
      }
      return Uri.decodeComponent(rawValue);
    }

    return null;
  }

  Map<String, String> _buildAuthHeaders({
    String? token,
    String? cookie,
    bool includeJsonContentType = false,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    final cleanToken = token?.trim();
    if (cleanToken != null && cleanToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $cleanToken';
    } else {
      final cleanCookie = cookie?.trim();
      if (cleanCookie != null && cleanCookie.isNotEmpty) {
        headers['Cookie'] = cleanCookie;
      }
    }

    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
    }

    return headers;
  }
}
