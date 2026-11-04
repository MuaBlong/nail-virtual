import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/main.dart';
import 'package:flutter_app/services/auth_service.dart';
import 'package:flutter_app/screens/auth_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  testWidgets('Signed out users must authenticate before using the app', (
    WidgetTester tester,
  ) async {
    final auth = AuthService(
      client: MockClient(
        (_) async => http.Response('{"message":"signed out"}', 401),
      ),
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(NailApp(auth: auth));
    await tester.pumpAndSettle();

    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('BẮT ĐẦU THỬ NAIL'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Login opens home and logout removes protected routes', (
    tester,
  ) async {
    bool signedIn = false;
    final auth = AuthService(
      cookieAuth: true,
      client: MockClient((request) async {
        if (request.url.path.endsWith('/me') && !signedIn) {
          return http.Response('{}', 401);
        }
        if (request.url.path.endsWith('/logout')) {
          signedIn = false;
          return http.Response('', 204);
        }
        signedIn = true;
        return http.Response(
          jsonEncode({
            'user': {
              'id': '42',
              'fullName': 'Test',
              'email': 'test@example.invalid',
            },
          }),
          200,
        );
      }),
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(NailApp(auth: auth));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email'),
      'test@example.invalid',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Mật khẩu'),
      'test password 123!',
    );
    await tester.ensureVisible(find.text('ĐĂNG NHẬP'));
    await tester.tap(find.text('ĐĂNG NHẬP'));
    await tester.pumpAndSettle();
    expect(find.text('BẮT ĐẦU THỬ NAIL'), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
    final context = tester.element(find.text('BẮT ĐẦU THỬ NAIL'));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Protected route')),
      ),
    );
    await tester.pumpAndSettle();
    await auth.logout();
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
    expect(find.text('Protected route'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(AuthScreen), findsOneWidget);
  });

  testWidgets('Valid saved session opens home directly', (tester) async {
    final auth = AuthService(
      cookieAuth: true,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'user': {
              'id': '42',
              'fullName': 'Test',
              'email': 'test@example.invalid',
            },
          }),
          200,
        ),
      ),
    );
    addTearDown(auth.dispose);
    await tester.pumpWidget(NailApp(auth: auth));
    await tester.pumpAndSettle();
    expect(find.text('BẮT ĐẦU THỬ NAIL'), findsOneWidget);
    expect(find.byType(AuthScreen), findsNothing);
  });
}
