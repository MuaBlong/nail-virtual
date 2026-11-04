import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'app_config.dart';
import 'auth_client.dart';

class AccountUser {
  final String id, fullName, email;
  const AccountUser({
    required this.id,
    required this.fullName,
    required this.email,
  });
  factory AccountUser.fromJson(Map<String, dynamic> json) => AccountUser(
    id: json['id'].toString(),
    fullName: json['fullName'] as String,
    email: json['email'] as String,
  );
}

class AuthException implements Exception {
  final String message;
  final int? status;
  const AuthException(this.message, [this.status]);
  @override
  String toString() => message;
}

class AuthService extends ChangeNotifier {
  static final instance = AuthService();
  final http.Client _client;
  final bool _cookieAuth;
  String? _token;
  AccountUser? user;
  bool _initialized = false;
  Future<void>? _restoration;
  int _revision = 0;
  AuthService({http.Client? client, bool? cookieAuth})
    : _client = client ?? createAuthClient(),
      _cookieAuth = cookieAuth ?? usesCookieAuth();

  Future<Map<String, dynamic>> _request(
    String method,
    String route, [
    Map<String, dynamic>? data,
  ]) async {
    final request = http.Request(
      method,
      Uri.parse('${AppConfig.accountBaseUrl}/api/auth/$route'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.headers['X-Auth-Client'] = _cookieAuth ? 'web' : 'native';
    if (_token != null) request.headers['Authorization'] = 'Bearer $_token';
    if (data != null) request.body = jsonEncode(data);
    try {
      final response = await (() async => http.Response.fromStream(
        await _client.send(request),
      ))().timeout(const Duration(seconds: 15));
      if (response.statusCode == 204) return {};
      final raw = jsonDecode(utf8.decode(response.bodyBytes));
      final json = Map<String, dynamic>.from(raw as Map);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(
          json['message']?.toString() ?? 'Chưa thực hiện được. Hãy thử lại.',
          response.statusCode,
        );
      }
      return json;
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Không kết nối được máy chủ tài khoản. Hãy kiểm tra kết nối và thử lại.',
      );
    }
  }

  Future<void> restore() {
    if (_initialized) return Future.value();
    return _restoration ??= () async {
      final revision = _revision;
      try {
        final json = await _request('GET', 'me');
        if (revision == _revision) {
          user = AccountUser.fromJson(
            Map<String, dynamic>.from(json['user'] as Map),
          );
        }
      } on AuthException catch (error) {
        if (revision == _revision && error.status == 401) {
          user = null;
          _token = null;
        }
      } finally {
        if (revision == _revision) {
          _initialized = true;
          notifyListeners();
        }
      }
    }();
  }

  Future<void> _authenticate(String route, Map<String, dynamic> data) async {
    final revision = ++_revision;
    final json = await _request('POST', route, data);
    if (revision != _revision) return;
    final account = AccountUser.fromJson(
      Map<String, dynamic>.from(json['user'] as Map),
    );
    if (!_cookieAuth && json['sessionToken'] is! String) {
      throw const AuthException(
        'Phản hồi đăng nhập không hợp lệ. Hãy thử lại.',
      );
    }
    if (_cookieAuth) {
      // A successful POST alone does not prove the browser kept the cookie.
      final session = await _request('GET', 'me');
      if (revision != _revision) return;
      if (session['user'] is! Map ||
          session['user']['id'].toString() != account.id) {
        throw const AuthException(
          'Chưa xác nhận được phiên đăng nhập. Hãy tải lại trang và thử lại.',
        );
      }
    }
    _token = _cookieAuth ? null : json['sessionToken'] as String?;
    user = account;
    _initialized = true;
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) =>
      _authenticate('register', {
        'fullName': name.trim(),
        'email': email.trim(),
        'password': password,
      });
  Future<void> login(String email, String password) =>
      _authenticate('login', {'email': email.trim(), 'password': password});
  Future<Map<String, dynamic>> historyRequest(
    String method, [
    Map<String, dynamic>? data,
    String suffix = '',
  ]) => _request(method, 'history$suffix', data);
  Future<void> logout() async {
    _revision++;
    await _request('POST', 'logout', {});
    user = null;
    _token = null;
    _initialized = true;
    notifyListeners();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
