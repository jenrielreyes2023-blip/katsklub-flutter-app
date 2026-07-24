import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:katsklub_flutter/services/auth_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService Tests', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('checkIdentifier returns correct availability when user exists', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.url.path, '/api/auth/check-identifier');
        expect(request.method, 'POST');
        final body = jsonDecode(request.body);
        expect(body['identifier'], 'testuser');

        return http.Response(
          jsonEncode({
            'exists': true,
          }),
          200,
        );
      });

      final authService = AuthService(client: mockClient);
      final result = await authService.checkIdentifier('testuser');

      expect(result.ok, isTrue);
      expect(result.exists, isTrue);
      expect(result.error, isNull);
    });

    test('checkUsernameAvailability returns correct response when username is taken', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.url.path, '/api/users/check-username');
        expect(request.method, 'GET');
        expect(request.url.queryParameters['username'], 'taken_username');

        return http.Response(
          jsonEncode({
            'available': false,
            'reason': 'Username already taken',
          }),
          200,
        );
      });

      final authService = AuthService(client: mockClient);
      final result = await authService.checkUsernameAvailability('taken_username');

      expect(result.ok, isTrue);
      expect(result.available, isFalse);
      expect(result.reason, 'Username already taken');
    });

    test('login stores token and returns user on success', () async {
      final mockUserJson = {
        'id': 'user-123',
        'username': 'kat_user',
        'email': 'kat@katsklub.top',
        'fullName': 'Kat Lover',
        'is_admin': false,
        'is_verified': true,
      };

      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/api/auth/login') {
          return http.Response(
            jsonEncode({
              'user': mockUserJson,
              'token': 'mock-jwt-token',
            }),
            200,
            headers: {
              'set-cookie': 'session=mock-session-cookie; Path=/',
            },
          );
        } else if (request.url.path == '/api/auth/me') {
          // fetchMe step
          return http.Response(
            jsonEncode({
              'user': mockUserJson,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final authService = AuthService(client: mockClient);
      final result = await authService.login(
        identifier: 'kat_user',
        password: 'securepassword',
        persistSession: true,
      );

      expect(result.ok, isTrue);
      expect(result.user, isNotNull);
      expect(result.user!.username, 'kat_user');
      expect(result.user!.id, 'user-123');

      // Verify that data is persisted in SharedPreferences
      final savedPrefs = await SharedPreferences.getInstance();
      expect(savedPrefs.getString('katsklub_auth_token'), 'mock-jwt-token');
      expect(savedPrefs.getString('katsklub_session_cookie'), 'session=mock-session-cookie');
      expect(savedPrefs.getString('katsklub_user'), isNotNull);
    });

    test('sendLoginOtp returns success on standard response', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.url.path, '/api/auth/phone-login/send-otp');
        final body = jsonDecode(request.body);
        expect(body['phone'], '+639187843417');

        return http.Response(
          jsonEncode({'success': true}),
          200,
        );
      });

      final authService = AuthService(client: mockClient);
      final result = await authService.sendLoginOtp(phone: '+639187843417');

      expect(result.ok, isTrue);
      expect(result.error, isNull);
    });

    test('signupStart returns draftId on email registration step 1', () async {
      final mockClient = http_testing.MockClient((request) async {
        expect(request.url.path, '/api/signup/start');
        final body = jsonDecode(request.body);
        expect(body['fullName'], 'Kat Lover');
        expect(body['email'], 'new@katsklub.top');
        expect(body['password'], 'securepassword');
        expect(body['confirmPassword'], 'securepassword');

        return http.Response(
          jsonEncode({
            'draftId': 'draft-999',
            'email': 'new@katsklub.top',
            'fullName': 'Kat Lover',
          }),
          200,
        );
      });

      final authService = AuthService(client: mockClient);
      final result = await authService.signupStart(
        fullName: 'Kat Lover',
        email: 'new@katsklub.top',
        password: 'securepassword',
        confirmPassword: 'securepassword',
      );

      expect(result.ok, isTrue);
      expect(result.draftId, 'draft-999');
      expect(result.email, 'new@katsklub.top');
    });

    test('signupComplete registers and logs in user successfully', () async {
      final mockUserJson = {
        'id': 'user-new',
        'username': 'new_user',
        'email': 'new@katsklub.top',
        'fullName': 'New KatsKlub User',
        'is_admin': false,
        'is_verified': true,
      };

      final mockClient = http_testing.MockClient((request) async {
        if (request.url.path == '/api/signup/complete') {
          return http.Response(
            jsonEncode({
              'user': mockUserJson,
              'token': 'mock-new-user-token',
            }),
            200,
          );
        } else if (request.url.path == '/api/auth/me') {
          return http.Response(
            jsonEncode({
              'user': mockUserJson,
            }),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final authService = AuthService(client: mockClient);
      final result = await authService.signupComplete(
        draftId: 'draft-999',
        username: 'new_user',
        gender: 'Male',
        birthday: '2000-01-01',
        location: 'Manila, Philippines',
        fullName: 'New KatsKlub User',
      );

      expect(result.ok, isTrue);
      expect(result.user, isNotNull);
      expect(result.user!.username, 'new_user');
      expect(result.user!.email, 'new@katsklub.top');

      final savedPrefs = await SharedPreferences.getInstance();
      expect(savedPrefs.getString('katsklub_auth_token'), 'mock-new-user-token');
    });
  });
}
