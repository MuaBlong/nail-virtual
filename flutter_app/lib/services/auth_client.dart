import 'package:http/http.dart' as http;
import 'auth_client_native.dart'
    if (dart.library.js_interop) 'auth_client_web.dart'
    as platform;

http.Client createAuthClient() => platform.createClient();
bool usesCookieAuth() => platform.cookieAuth;
