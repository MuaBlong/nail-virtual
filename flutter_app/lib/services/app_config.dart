import 'package:flutter/foundation.dart';

class AppConfig {
  static const aiBaseUrl = String.fromEnvironment(
    'AI_BASE_URL',
    defaultValue: 'http://127.0.0.1:8001',
  );
  static const dataBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:5000',
  );

  static String get accountBaseUrl =>
      kIsWeb ? resolveAccountBaseUrl(dataBaseUrl, Uri.base) : dataBaseUrl;

  static String resolveAccountBaseUrl(String configured, Uri page) {
    final api = Uri.parse(configured);
    const localHosts = {'localhost', '127.0.0.1', '::1'};
    if (localHosts.contains(api.host) && localHosts.contains(page.host)) {
      return api.replace(host: page.host).toString();
    }
    return configured;
  }
}
