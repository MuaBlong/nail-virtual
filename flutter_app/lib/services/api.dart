import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/nail_set.dart';
import 'app_config.dart';

class NailCatalogResult {
  final List<NailSet> sets;
  final String? message;
  NailCatalogResult(this.sets, [this.message]);
}

class NailCatalogApi {
  static Future<NailCatalogResult> load({http.Client? client}) async {
    final ownClient = client == null;
    final connection = client ?? http.Client();
    try {
      final response = await connection
          .get(Uri.parse('${AppConfig.dataBaseUrl}/api/nail-sets'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        throw const FormatException('Kho mẫu chưa sẵn sàng');
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is! List) {
        throw const FormatException('Dữ liệu kho mẫu không hợp lệ');
      }
      final remote = <NailSet>[];
      var invalid = 0;
      for (final item in data) {
        try {
          final set = NailSet.fromJson(Map<String, dynamic>.from(item as Map));
          // Retired legacy assets must not reappear from an older server.
          if (set.images.any(
            (p) => p.contains('/sets/set_01/') || p == 'assets/nails/hong.png',
          )) {
            continue;
          }
          remote.add(set);
        } catch (_) {
          invalid++;
        }
      }
      return NailCatalogResult([
        ...nailSets,
        ...remote.where(
          (r) => !nailSets.any((s) => r.id == s.id || r.name == s.name),
        ),
      ], invalid > 0 ? 'Một số bộ mẫu chưa đủ 5 ảnh nên chưa hiển thị.' : null);
    } catch (_) {
      return NailCatalogResult(
        nailSets,
        'Đang dùng bộ mẫu có sẵn. Chưa kết nối được kho mẫu mở rộng.',
      );
    } finally {
      if (ownClient) connection.close();
    }
  }
}
