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

      final savedCookie = await _saveAuthData(
        response: response,
        responseData: data,
        user: user,
      );

      final verifiedUser =
          savedCookie == null ? null : await _fetchMe(savedCookie);
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
    final savedCookie = prefs.getString(sessionCookieKey);

    if (savedUser == null || savedCookie == null || savedCookie.isEmpty) {
      return null;
    }

    final verifiedUser = await _fetchMe(savedCookie);
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

    if (savedCookie != null && savedCookie.isNotEmpty) {
      try {
        await _client.post(
          ApiConfig.uri(ApiConfig.logoutPath),
          headers: {
            'Accept': 'application/json',
            'Cookie': savedCookie,
          },
        );
      } catch (_) {
        // Local logout must still work even if the network request fails.
      }
    }

    await prefs.remove(sessionCookieKey);
    await prefs.remove(_authTokenKey);
    await prefs.remove(_userKey);
  }

  Future<User?> _fetchMe(String cookie) async {
    try {
      final response = await _client.get(
        ApiConfig.uri(ApiConfig.mePath),
        headers: {
          'Accept': 'application/json',
          'Cookie': cookie,
        },
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
    final token = responseData['token'];

    if (cookie != null && cookie.isNotEmpty) {
      await prefs.setString(sessionCookieKey, cookie);
    }

    if (token is String && token.isNotEmpty) {
      await prefs.setString(_authTokenKey, token);
    }

    await _saveUser(user);
    return cookie;
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
}
