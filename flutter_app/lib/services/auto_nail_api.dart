import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'app_config.dart';

class AutoNailApi {
  // Địa chỉ Python AI chạy trên cùng máy tính
  static const String baseUrl = AppConfig.aiBaseUrl;

  // Gửi ảnh bàn tay đến AI
  static Future<Map<String, dynamic>> detectHand(Uint8List imageBytes) =>
      _upload(imageBytes, '/detect-hand');
  static Future<Map<String, dynamic>> extractDesign(Uint8List imageBytes) =>
      _upload(imageBytes, '/extract-nail-design');
  static Future<Map<String, dynamic>> _upload(
    Uint8List imageBytes,
    String route,
  ) async {
    final request = http.MultipartRequest('POST', Uri.parse('$baseUrl$route'));

    // Đính kèm ảnh
    request.files.add(
      http.MultipartFile.fromBytes('file', imageBytes, filename: 'hand.jpg'),
    );

    // Gửi yêu cầu đến Python
    final client = http.Client();
    late final http.Response response;
    try {
      response = await (() async {
        final streamedResponse = await client.send(request);
        return http.Response.fromStream(streamedResponse);
      })().timeout(const Duration(seconds: 60));
    } on TimeoutException {
      throw const FormatException(
        'AI xử lý quá lâu. Hãy thử lại với ảnh nhỏ hơn.',
      );
    } on http.ClientException {
      throw FormatException(
        'Không kết nối được AI tại $baseUrl. Hãy chạy dịch vụ AI hoặc mở ứng dụng bằng CHAY_UNG_DUNG.cmd.',
      );
    } finally {
      client.close();
    }
    final body = utf8.decode(response.bodyBytes);

    if (response.statusCode != 200) {
      throw Exception('Lỗi AI ${response.statusCode}: $body');
    }

    // Chuyển kết quả JSON thành dữ liệu Dart
    return Map<String, dynamic>.from(jsonDecode(body) as Map);
  }
}
