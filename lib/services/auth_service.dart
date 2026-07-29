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
    this.statusCode,
  });

  final bool ok;
  final User? user;
  final String? error;
  final int? statusCode;
}

class ForgotPasswordResult {
  const ForgotPasswordResult({
    required this.ok,
    this.error,
    this.method,
    this.target,
    this.code,
    this.hasAlternative = false,
    this.alternativeMethod,
    this.alternativeTarget,
  });

  final bool ok;
  final String? error;
  final String? method;
  final String? target;
  final String? code;
  final bool hasAlternative;
  final String? alternativeMethod;
  final String? alternativeTarget;
}

class GoogleAuthResult {
  const GoogleAuthResult({
    required this.ok,
    this.user,
    this.needsSignup = false,
    this.draftId,
    this.googleEmail,
    this.googleFullName,
    this.googleAvatarUrl,
    this.error,
    this.statusCode,
  });

  final bool ok;
  final User? user;
  final bool needsSignup;
  final String? draftId;
  final String? googleEmail;
  final String? googleFullName;
  final String? googleAvatarUrl;
  final String? error;
  final int? statusCode;
}

class IdentifierCheckResult {
  const IdentifierCheckResult({
    required this.ok,
    required this.exists,
    this.error,
    this.statusCode,
  });

  final bool ok;
  final bool exists;
  final String? error;
  final int? statusCode;
}

class UsernameAvailabilityResult {
  const UsernameAvailabilityResult({
    required this.ok,
    required this.available,
    this.reason,
    this.error,
    this.statusCode,
  });

  final bool ok;
  final bool available;
  final String? reason;
  final String? error;
  final int? statusCode;
}

class CountryOption {
  const CountryOption({
    required this.name,
    this.cities = const <String>[],
  });

  final String name;
  final List<String> cities;
}

class CityLookupResult {
  const CityLookupResult({
    required this.ok,
    required this.cities,
    this.error,
  });

  final bool ok;
  final List<String> cities;
  final String? error;
}

class SignupStartResult {
  const SignupStartResult({
    required this.ok,
    this.draftId,
    this.fullName,
    this.email,
    this.error,
    this.statusCode,
  });

  final bool ok;
  final String? draftId;
  final String? fullName;
  final String? email;
  final String? error;
  final int? statusCode;
}

class AuthService {
  static const String sessionCookieKey = 'katsklub_session_cookie';
  static const String _authTokenKey = 'katsklub_auth_token';
  static const String _userKey = 'katsklub_user';

  static const String googleWebClientId =
      '318562799325-8i48536nqg6nivtf3h3o2t2ftjt5ah2e.apps.googleusercontent.com';

  // In-memory session — used when the user did not opt in to "Remember me".
  // Static so a fresh AuthService() instance still sees the active session.
  static bool _persistSession = true;
  static String? _memoryToken;
  static String? _memoryCookie;
  static User? _memoryUser;

  User? get currentUser => _memoryUser;

  final http.Client _client;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  Future<AuthResult> login({
    required String identifier,
    required String password,
    bool persistSession = true,
  }) async {
    _persistSession = persistSession;
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
          statusCode: response.statusCode,
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
    } catch (e, stack) {
      print('DEBUG: login caught error: $e');
      print(stack);
      return AuthResult(
        ok: false,
        error: 'Unable to connect to KatsKlub: $e',
      );
    }
  }

  Future<AuthResult> sendLoginOtp({
    required String phone,
  }) async {
    try {
      final response = await _client.post(
        ApiConfig.uri('/api/auth/phone-login/send-otp'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone': phone.trim(),
        }),
      );

      final data = _decodeJsonObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AuthResult(
          ok: false,
          error: _readError(data) ?? 'Failed to send login SMS verification code.',
          statusCode: response.statusCode,
        );
      }

      return const AuthResult(ok: true);
    } catch (_) {
      return const AuthResult(
        ok: false,
        error: 'Unable to connect to KatsKlub. Check your internet connection.',
      );
    }
  }

  Future<AuthResult> verifyLoginOtp({
    required String phone,
    required String otpCode,
    bool persistSession = true,
  }) async {
    _persistSession = persistSession;
    try {
      final response = await _client.post(
        ApiConfig.uri('/api/auth/phone-login/verify-otp'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'phone': phone.trim(),
          'otpCode': otpCode.trim(),
        }),
      );

      final data = _decodeJsonObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AuthResult(
          ok: false,
          error: _readError(data) ?? 'Verification failed.',
          statusCode: response.statusCode,
        );
      }

      final user = _readUser(data);
      if (user == null) {
        return const AuthResult(
          ok: false,
          error: 'Verification succeeded but no user was returned.',
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

  Future<ForgotPasswordResult> sendForgotPasswordOtp({
    required String identifier,
    bool useAlternative = false,
  }) async {
    try {
      final response = await _client.post(
        ApiConfig.uri('/api/auth/forgot-password/send-otp'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'identifier': identifier.trim(),
          'useAlternative': useAlternative,
        }),
      );

      final data = _decodeJsonObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return ForgotPasswordResult(
          ok: false,
          error: _readError(data) ?? 'Failed to request password reset code.',
        );
      }

      return ForgotPasswordResult(
        ok: true,
        method: data['method'] as String?,
        target: data['target'] as String?,
        code: data['code'] as String?,
        hasAlternative: data['hasAlternative'] as bool? ?? false,
        alternativeMethod: data['alternativeMethod'] as String?,
        alternativeTarget: data['alternativeTarget'] as String?,
      );
    } catch (_) {
      return const ForgotPasswordResult(
        ok: false,
        error: 'Unable to connect to KatsKlub. Check your internet connection.',
      );
    }
  }

  Future<AuthResult> resetPassword({
    required String identifier,
    required String otpCode,
    required String newPassword,
  }) async {
    try {
      final response = await _client.post(
        ApiConfig.uri('/api/auth/forgot-password/reset'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'identifier': identifier.trim(),
          'otpCode': otpCode.trim(),
          'newPassword': newPassword,
        }),
      );

      final data = _decodeJsonObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AuthResult(
          ok: false,
          error: _readError(data) ?? 'Failed to reset password.',
          statusCode: response.statusCode,
        );
      }

      return const AuthResult(ok: true);
    } catch (_) {
      return const AuthResult(
        ok: false,
        error: 'Unable to connect to KatsKlub. Check your internet connection.',
      );
    }
  }

  Future<GoogleAuthResult> exchangeGoogleIdToken({
    required String idToken,
    bool persistSession = true,
  }) async {
    _persistSession = persistSession;
    try {
      final response = await _client.post(
        ApiConfig.uri('/api/auth/google/native-id-token'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'idToken': idToken.trim()}),
      );

      final data = _decodeJsonObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return GoogleAuthResult(
          ok: false,
          error: _readError(data) ?? 'Google sign-in failed. Please try again.',
          statusCode: response.statusCode,
        );
      }

      if (data['needsSignup'] == true) {
        final draftId = data['draftId']?.toString().trim();
        if (draftId == null || draftId.isEmpty) {
          return const GoogleAuthResult(
            ok: false,
            error: 'Google sign-in returned an incomplete signup draft.',
          );
        }
        return GoogleAuthResult(
          ok: true,
          needsSignup: true,
          draftId: draftId,
          googleEmail: data['email']?.toString(),
          googleFullName: data['fullName']?.toString(),
          googleAvatarUrl: data['googleAvatarUrl']?.toString(),
          statusCode: response.statusCode,
        );
      }

      final user = _readUser(data);
      if (user == null) {
        return const GoogleAuthResult(
          ok: false,
          error: 'Google sign-in succeeded but no user was returned.',
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
        return GoogleAuthResult(ok: true, user: verifiedUser);
      }

      return GoogleAuthResult(ok: true, user: user);
    } catch (e, stack) {
      print('DEBUG: exchangeGoogleIdToken caught error: $e');
      print(stack);
      return GoogleAuthResult(
        ok: false,
        error: 'Unable to connect to KatsKlub: $e',
      );
    }
  }

  Future<IdentifierCheckResult> checkIdentifier(String identifier) async {
    try {
      final response = await _client.post(
        ApiConfig.uri('/api/auth/check-identifier'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'identifier': identifier.trim(),
        }),
      );

      final data = _decodeJsonObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return IdentifierCheckResult(
          ok: false,
          exists: false,
          error: _readError(data) ?? 'Unable to continue. Please try again.',
          statusCode: response.statusCode,
        );
      }

      return IdentifierCheckResult(
        ok: true,
        exists: data['exists'] == true,
        statusCode: response.statusCode,
      );
    } catch (_) {
      return const IdentifierCheckResult(
        ok: false,
        exists: false,
        error: 'Unable to connect to KatsKlub. Check your internet connection.',
      );
    }
  }

  Future<UsernameAvailabilityResult> checkUsernameAvailability(
    String username,
  ) async {
    final normalized = username.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const UsernameAvailabilityResult(
        ok: false,
        available: false,
        error: 'Username is required.',
      );
    }

    try {
      final response = await _client.get(
        ApiConfig.uri(
          '/api/users/check-username?username=${Uri.encodeQueryComponent(normalized)}',
        ),
        headers: const {
          'Accept': 'application/json',
        },
      );

      final data = _decodeJsonObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return UsernameAvailabilityResult(
          ok: false,
          available: false,
          error: _readError(data) ?? 'Unable to check username right now.',
          statusCode: response.statusCode,
        );
      }

      return UsernameAvailabilityResult(
        ok: true,
        available: data['available'] == true,
        reason: data['reason']?.toString().trim(),
        statusCode: response.statusCode,
      );
    } catch (_) {
      return const UsernameAvailabilityResult(
        ok: false,
        available: false,
        error: 'Unable to connect to KatsKlub. Check your internet connection.',
      );
    }
  }

  Future<List<CountryOption>> loadCountries() async {
    try {
      final response = await _client.get(
        Uri.parse('https://countriesnow.space/api/v0.1/countries'),
        headers: const {
          'Accept': 'application/json',
        },
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return const <CountryOption>[];
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const <CountryOption>[];
      }

      final data = decoded['data'];
      if (data is! List) {
        return const <CountryOption>[];
      }

      final countries = data
          .whereType<Map<String, dynamic>>()
          .map((country) {
            final name = country['country']?.toString().trim() ?? '';
            if (name.isEmpty) {
              return null;
            }
            final cities = (country['cities'] as List?)
                    ?.map((item) => item?.toString().trim() ?? '')
                    .where((city) => city.isNotEmpty)
                    .toSet()
                    .toList() ??
                <String>[];
            cities.sort();
            return CountryOption(name: name, cities: cities);
          })
          .whereType<CountryOption>()
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      return countries;
    } catch (_) {
      return const <CountryOption>[];
    }
  }

  Future<CityLookupResult> loadCitiesForCountry(String country) async {
    final cleanCountry = country.trim();
    if (cleanCountry.isEmpty) {
      return const CityLookupResult(ok: true, cities: <String>[]);
    }

    try {
      final countries = await loadCountries();
      final matchedCountry = countries.where((option) => option.name.toLowerCase() == cleanCountry.toLowerCase()).firstWhere(
            (_) => true,
            orElse: () => const CountryOption(name: '', cities: <String>[]),
          );
      if (matchedCountry.name.isEmpty) {
        return const CityLookupResult(
          ok: false,
          cities: <String>[],
          error: 'We could not match that country yet. Please choose from the list.',
        );
      }
      return CityLookupResult(ok: true, cities: matchedCountry.cities);
    } catch (_) {
      return const CityLookupResult(
        ok: false,
        cities: <String>[],
        error: 'Unable to load cities right now.',
      );
    }
  }

  Future<SignupStartResult> signupStart({
    required String fullName,
    required String email,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      final response = await _client.post(
        ApiConfig.uri('/api/signup/start'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'fullName': fullName.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
          'confirmPassword': confirmPassword,
        }),
      );

      final data = _decodeJsonObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return SignupStartResult(
          ok: false,
          error: _readError(data) ?? 'Unable to start signup. Please try again.',
          statusCode: response.statusCode,
        );
      }

      final draftId = data['draftId']?.toString().trim();
      if (draftId == null || draftId.isEmpty) {
        return const SignupStartResult(
          ok: false,
          error: 'Signup started but no draft id was returned.',
        );
      }

      return SignupStartResult(
        ok: true,
        draftId: draftId,
        fullName: data['fullName']?.toString(),
        email: data['email']?.toString(),
        statusCode: response.statusCode,
      );
    } catch (_) {
      return const SignupStartResult(
        ok: false,
        error: 'Unable to connect to KatsKlub. Check your internet connection.',
      );
    }
  }

  Future<AuthResult> sendOtp({
    required String draftId,
    required String phone,
  }) async {
    try {
      final response = await _client.post(
        ApiConfig.uri('/api/signup/send-otp'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'draftId': draftId.trim(),
          'phone': phone.trim(),
        }),
      );

      final data = _decodeJsonObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AuthResult(
          ok: false,
          error: _readError(data) ?? 'Failed to send verification SMS.',
          statusCode: response.statusCode,
        );
      }

      return const AuthResult(ok: true);
    } catch (_) {
      return const AuthResult(
        ok: false,
        error: 'Unable to connect to KatsKlub. Check your internet connection.',
      );
    }
  }

  Future<AuthResult> signupComplete({
    required String draftId,
    required String username,
    required String gender,
    required String birthday,
    required String location,
    String? fullName,
    String? bio,
    String? avatarDataUrl,
    String? googleAvatarUrl,
    String? otpCode,
  }) async {
    try {
      final response = await _client.post(
        ApiConfig.uri('/api/signup/complete'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'draftId': draftId.trim(),
          'username': username.trim().toLowerCase(),
          'gender': gender.trim(),
          'birthday': birthday.trim(),
          'location': location.trim(),
          'bio': (bio ?? '').trim(),
          if (fullName != null && fullName.trim().isNotEmpty)
            'fullName': fullName.trim(),
          if (avatarDataUrl != null && avatarDataUrl.trim().isNotEmpty)
            'avatarDataUrl': avatarDataUrl.trim(),
          if (googleAvatarUrl != null && googleAvatarUrl.trim().isNotEmpty)
            'googleAvatarUrl': googleAvatarUrl.trim(),
          if (otpCode != null && otpCode.trim().isNotEmpty)
            'otpCode': otpCode.trim(),
        }),
      );

      final data = _decodeJsonObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AuthResult(
          ok: false,
          error: _readError(data) ?? 'Unable to complete signup. Please try again.',
          statusCode: response.statusCode,
        );
      }

      final user = _readUser(data);
      if (user == null) {
        return const AuthResult(
          ok: false,
          error: 'Signup succeeded but no user was returned.',
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
    final savedToken = await getToken();
    if (savedToken == null || savedToken.isEmpty) {
      return null;
    }

    if (_memoryUser == null) {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString(_userKey);
      if (savedUser == null) {
        return null;
      }
    }

    final verifiedUser = await _fetchMe(token: savedToken);
    if (verifiedUser != null) {
      await _saveUser(verifiedUser);
      return verifiedUser;
    }

    await logout();
    return null;
  }

  Future<User?> getSavedUser() async {
    if (_memoryUser != null) {
      return _memoryUser;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString(_userKey);
    if (savedUser == null || savedUser.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(savedUser);
      if (decoded is Map<String, dynamic>) {
        return User.fromJson(decoded);
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> saveCurrentUser(User user) async {
    final oldUser = await getSavedUser();
    if (oldUser != null && oldUser.username == user.username) {
      bool hasKey(List<String> keys) {
        return keys.any((k) => user.raw.containsKey(k));
      }

      final mergedUser = user.copyWith(
        featuredPhotos: hasKey(['featuredPhotos', 'featured_photos'])
            ? user.featuredPhotos
            : oldUser.featuredPhotos,
        profileLinks: hasKey(['profileLinks', 'profile_links'])
            ? user.profileLinks
            : oldUser.profileLinks,
        achievements: hasKey(['achievements'])
            ? user.achievements
            : oldUser.achievements,
        recentVisitors: hasKey(['recentVisitors', 'recent_visitors'])
            ? user.recentVisitors
            : oldUser.recentVisitors,
        followersCount: hasKey(['followersCount', 'followers_count', 'followerCount', 'follower_count'])
            ? user.followersCount
            : oldUser.followersCount,
        followingCount: hasKey(['followingCount', 'following_count'])
            ? user.followingCount
            : oldUser.followingCount,
        postCount: hasKey(['postCount', 'post_count', 'postsCount'])
            ? user.postCount
            : oldUser.postCount,
        charmPoints: hasKey(['charmPoints', 'charm_points'])
            ? user.charmPoints
            : oldUser.charmPoints,
        newVisitorsCount: hasKey(['newVisitorsCount', 'new_visitors_count'])
            ? user.newVisitorsCount
            : oldUser.newVisitorsCount,
        pinnedPostId: hasKey(['pinnedPostId', 'pinned_post_id'])
            ? user.pinnedPostId
            : oldUser.pinnedPostId,
        profileBorder: hasKey(['profileBorder', 'profile_border'])
            ? user.profileBorder
            : oldUser.profileBorder,
        postcardTheme: hasKey(['postcardTheme', 'postcard_theme'])
            ? user.postcardTheme
            : oldUser.postcardTheme,
        bubbleTheme: hasKey(['bubbleTheme', 'bubble_theme'])
            ? user.bubbleTheme
            : oldUser.bubbleTheme,
      );
      await _saveUser(mergedUser);
    } else {
      await _saveUser(user);
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCookie = _memoryCookie ?? prefs.getString(sessionCookieKey);
    final savedToken = _memoryToken ?? prefs.getString(_authTokenKey);

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

    _memoryToken = null;
    _memoryCookie = null;
    _memoryUser = null;
    _persistSession = true;

    await prefs.remove(sessionCookieKey);
    await prefs.remove(_authTokenKey);
    await prefs.remove(_userKey);
  }

  Future<String?> getToken() async {
    final memoryToken = _memoryToken?.trim();
    if (memoryToken != null && memoryToken.isNotEmpty) {
      return memoryToken;
    }

    final memoryCookieToken = _extractSessionToken(_memoryCookie);
    if (memoryCookieToken != null && memoryCookieToken.isNotEmpty) {
      _memoryToken = memoryCookieToken;
      return memoryCookieToken;
    }

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
    final cookie = _extractCookieHeader(response.headers['set-cookie']);
    final responseToken = responseData['token'];
    final cookieToken = _extractSessionToken(cookie);
    final token = responseToken is String && responseToken.isNotEmpty
        ? responseToken
        : cookieToken;

    // Always cache in memory so the active session works regardless of
    // persistence preference.
    if (cookie != null && cookie.isNotEmpty) {
      _memoryCookie = cookie;
    }
    if (token != null && token.isNotEmpty) {
      _memoryToken = token;
    }
    _memoryUser = user;

    if (_persistSession) {
      final prefs = await SharedPreferences.getInstance();
      if (cookie != null && cookie.isNotEmpty) {
        await prefs.setString(sessionCookieKey, cookie);
      }
      if (token != null && token.isNotEmpty) {
        await prefs.setString(_authTokenKey, token);
      }
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
    }

    return token;
  }

  Future<void> _saveUser(User user) async {
    _memoryUser = user;
    if (!_persistSession) {
      return;
    }
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

  Future<bool> registerPushToken(String pushToken, String platform) async {
    try {
      final authToken = await getToken();
      if (authToken == null || authToken.isEmpty) {
        return false;
      }

      final response = await _client.post(
        ApiConfig.uri('/api/push/register'),
        headers: _buildAuthHeaders(
          token: authToken,
          includeJsonContentType: true,
        ),
        body: jsonEncode({
          'token': pushToken,
          'platform': platform,
        }),
      );

      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  Future<AuthResult> updateProfile({
    required String fullName,
    required String bio,
    required String gender,
    required String birthday,
    required String location,
    String? avatarImageDataUrl,
    required List<Map<String, dynamic>> profileLinks,
  }) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return const AuthResult(
          ok: false,
          error: 'Not authenticated.',
        );
      }

      final payload = <String, dynamic>{
        'fullName': fullName.trim(),
        'bio': bio.trim(),
        'gender': gender.trim(),
        'birthday': birthday.trim(),
        'location': location.trim(),
        'profileLinks': profileLinks,
      };

      if (avatarImageDataUrl != null) {
        payload['avatarImageDataUrl'] = avatarImageDataUrl;
      }

      final response = await _client.patch(
        ApiConfig.uri('/api/me/profile'),
        headers: _buildAuthHeaders(
          token: token,
          includeJsonContentType: true,
        ),
        body: jsonEncode(payload),
      );

      final data = _decodeJsonObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AuthResult(
          ok: false,
          error: _readError(data) ?? 'Failed to update profile.',
          statusCode: response.statusCode,
        );
      }

      final user = _readUser(data);
      if (user == null) {
        return const AuthResult(
          ok: false,
          error: 'Profile updated but no user was returned.',
        );
      }

      await _saveUser(user);
      return AuthResult(ok: true, user: user);
    } catch (_) {
      return const AuthResult(
        ok: false,
        error: 'Unable to connect to KatsKlub. Check your internet connection.',
      );
    }
  }

  Future<AuthResult> addFeaturedPhoto({
    String? imageDataUrl,
    String? imageUrl,
    String caption = '',
  }) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return const AuthResult(ok: false, error: 'Not authenticated.');
      }

      final payload = <String, dynamic>{
        'caption': caption.trim(),
      };
      if (imageDataUrl != null && imageDataUrl.isNotEmpty) {
        payload['imageDataUrl'] = imageDataUrl;
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        payload['imageUrl'] = imageUrl.trim();
      } else {
        return const AuthResult(ok: false, error: 'No image provided.');
      }

      final response = await _client.post(
        ApiConfig.uri('/api/me/featured-photos'),
        headers: _buildAuthHeaders(token: token, includeJsonContentType: true),
        body: jsonEncode(payload),
      );

      final data = _decodeJsonObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AuthResult(
          ok: false,
          error: _readError(data) ?? 'Failed to add featured photo.',
          statusCode: response.statusCode,
        );
      }

      final user = _readUser(data);
      if (user == null) {
        return const AuthResult(ok: false, error: 'No user returned.');
      }

      await _saveUser(user);
      return AuthResult(ok: true, user: user);
    } catch (_) {
      return const AuthResult(
        ok: false,
        error: 'Unable to connect to KatsKlub. Check your internet connection.',
      );
    }
  }

  Future<AuthResult> removeFeaturedPhoto(int photoId) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) {
        return const AuthResult(ok: false, error: 'Not authenticated.');
      }

      final response = await _client.delete(
        ApiConfig.uri('/api/me/featured-photos/$photoId'),
        headers: _buildAuthHeaders(token: token),
      );

      final data = _decodeJsonObject(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AuthResult(
          ok: false,
          error: _readError(data) ?? 'Failed to remove featured photo.',
          statusCode: response.statusCode,
        );
      }

      final user = _readUser(data);
      if (user == null) {
        return const AuthResult(ok: false, error: 'No user returned.');
      }

      await _saveUser(user);
      return AuthResult(ok: true, user: user);
    } catch (_) {
      return const AuthResult(
        ok: false,
        error: 'Unable to connect to KatsKlub. Check your internet connection.',
      );
    }
  }

  Future<Map<String, dynamic>?> fetchLinkMetadata(String url) async {
    try {
      final token = await getToken();
      if (token == null || token.isEmpty) return null;

      final response = await _client.post(
        ApiConfig.uri('/api/profile-links/metadata'),
        headers: _buildAuthHeaders(
          token: token,
          includeJsonContentType: true,
        ),
        body: jsonEncode({'url': url.trim()}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic> && data['metadata'] is Map<String, dynamic>) {
          return Map<String, dynamic>.from(data['metadata']);
        }
      }
    } catch (_) {}
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
