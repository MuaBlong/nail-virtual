import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_app/services/auth_service.dart';
import 'package:flutter_app/services/try_on_history.dart';
import 'package:flutter_app/models/nail_set.dart';
import 'package:flutter_app/screens/auth_screen.dart';
import 'package:flutter_app/services/app_config.dart';

const account = {
  'id': '42',
  'fullName': 'Người thử',
  'email': 'test@example.invalid',
  'role': 'user',
};
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'login keeps native token in memory and logout clears account',
    () async {
      final requests = <http.Request>[];
      final auth = AuthService(
        cookieAuth: false,
        client: MockClient((request) async {
          requests.add(request);
          if (request.url.path.endsWith('/logout')) {
            return http.Response('', 204);
          }
          return http.Response(
            jsonEncode({'user': account, 'sessionToken': 'test-token'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(auth.dispose);
      await auth.login('test@example.invalid', 'test password 123!');
      expect(auth.user!.fullName, 'Người thử');
      await auth.logout();
      expect(auth.user, isNull);
      expect(requests.last.headers['Authorization'], 'Bearer test-token');
    },
  );
  test('web restores cookie session and never adds bearer token', () async {
    final auth = AuthService(
      cookieAuth: true,
      client: MockClient((request) async {
        expect(request.headers.containsKey('Authorization'), false);
        expect(request.headers['X-Auth-Client'], 'web');
        return http.Response(
          jsonEncode({'user': account}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(auth.dispose);
    await auth.restore();
    expect(auth.user!.id, '42');
  });
  test('late restore response cannot erase a successful login', () async {
    final restoreResponse = Completer<http.Response>();
    bool restoring = true;
    final auth = AuthService(
      cookieAuth: true,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/me') && restoring) {
          restoring = false;
          return restoreResponse.future;
        }
        return http.Response(
          jsonEncode({'user': account}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(auth.dispose);
    final restore = auth.restore();
    await auth.login('test@example.invalid', 'test password 123!');
    restoreResponse.complete(http.Response('{"message":"expired"}', 401));
    await restore;
    expect(auth.user!.id, '42');
  });
  test('local account API uses the same hostname as the web page', () {
    expect(
      AppConfig.resolveAccountBaseUrl(
        'http://127.0.0.1:5000',
        Uri.parse('http://localhost:8770'),
      ),
      'http://localhost:5000',
    );
    expect(
      AppConfig.resolveAccountBaseUrl(
        'http://localhost:5000',
        Uri.parse('http://127.0.0.1:8770'),
      ),
      'http://127.0.0.1:5000',
    );
    expect(
      AppConfig.resolveAccountBaseUrl(
        'https://api.example.com',
        Uri.parse('https://app.example.com'),
      ),
      'https://api.example.com',
    );
  });
  test(
    'web login is not accepted when the session cookie is missing',
    () async {
      final auth = AuthService(
        cookieAuth: true,
        client: MockClient(
          (request) async => request.url.path.endsWith('/me')
              ? http.Response('{"message":"missing session"}', 401)
              : http.Response(
                  jsonEncode({'user': account}),
                  200,
                  headers: {'content-type': 'application/json; charset=utf-8'},
                ),
        ),
      );
      addTearDown(auth.dispose);
      await expectLater(
        auth.login('test@example.invalid', 'password123'),
        throwsA(isA<AuthException>().having((e) => e.status, 'status', 401)),
      );
      expect(auth.user, isNull);
    },
  );
  test(
    'web login verifies cookie before saving history with the same client',
    () async {
      final paths = <String>[];
      final auth = AuthService(
        cookieAuth: true,
        client: MockClient((request) async {
          paths.add('${request.method} ${request.url.path}');
          expect(request.headers['X-Auth-Client'], 'web');
          expect(request.headers.containsKey('Authorization'), false);
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('/history')
                  ? {'id': '1'}
                  : {'user': account},
            ),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(auth.dispose);
      await auth.login('test@example.invalid', 'password123');
      await auth.historyRequest('POST', {});
      expect(paths, [
        'POST /api/auth/login',
        'GET /api/auth/me',
        'POST /api/auth/history',
      ]);
    },
  );
  test('failed logout leaves the account visible for retry', () async {
    final auth = AuthService(
      cookieAuth: true,
      client: MockClient(
        (request) async => request.url.path.endsWith('/logout')
            ? http.Response('{"message":"offline"}', 503)
            : http.Response(
                jsonEncode({'user': account}),
                200,
                headers: {'content-type': 'application/json; charset=utf-8'},
              ),
      ),
    );
    addTearDown(auth.dispose);
    await auth.login('test@example.invalid', 'test password 123!');
    await expectLater(auth.logout(), throwsA(isA<AuthException>()));
    expect(auth.user, isNotNull);
  });
  test('local histories are isolated between guest and accounts', () async {
    final original = AuthService.instance.user;
    addTearDown(() => AuthService.instance.user = original);
    final photo = Uint8List.fromList(
      img.encodePng(img.Image(width: 10, height: 10)),
    );
    AuthService.instance.user = null;
    await TryOnHistory.add(
      photo,
      photo,
      const NailSet(id: 'guest', name: 'Guest'),
    );
    AuthService.instance.user = AccountUser.fromJson(account);
    final saved = <Map<String, dynamic>>[];
    final cloudAuth = AuthService(
      cookieAuth: true,
      client: MockClient((request) async {
        if (request.method == 'POST') {
          saved.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('{"id":"saved"}', 201);
        }
        return http.Response(
          jsonEncode({'records': saved}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    cloudAuth.user = AccountUser.fromJson(account);
    addTearDown(cloudAuth.dispose);
    expect(await TryOnHistory.load(auth: cloudAuth), isEmpty);
    await TryOnHistory.add(
      photo,
      photo,
      const NailSet(id: 'user', name: 'User'),
      auth: cloudAuth,
    );
    expect((await TryOnHistory.load(auth: cloudAuth)).single.set.id, 'user');
    AuthService.instance.user = null;
    expect((await TryOnHistory.load()).single.set.id, 'guest');
  });
  testWidgets('registration validates confirmation and submits the form', (
    tester,
  ) async {
    Map<String, dynamic>? sent;
    final auth = AuthService(
      cookieAuth: true,
      client: MockClient((request) async {
        if (request.method == 'POST') {
          sent = jsonDecode(request.body) as Map<String, dynamic>;
        }
        return http.Response(
          jsonEncode({'user': account}),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => AuthScreen(auth: auth)),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng ký'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Họ và tên'),
      'Người thử',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'test@example.invalid',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mật khẩu'),
      'test password 123!',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Xác nhận mật khẩu'),
      'wrong',
    );
    final submit = find.widgetWithText(FilledButton, 'TẠO TÀI KHOẢN');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu xác nhận chưa khớp.'), findsOneWidget);
    expect(sent, isNull);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Xác nhận mật khẩu'),
      'test password 123!',
    );
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(sent!['fullName'], 'Người thử');
    expect(auth.user, isNotNull);
    expect(find.text('Open'), findsOneWidget);
  });
}
