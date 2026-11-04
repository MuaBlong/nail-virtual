import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/nail_set.dart';
import 'user_storage.dart';
import 'auth_service.dart';

class TryOnRecord {
  final String id;
  final DateTime created;
  final Uint8List before;
  final Uint8List result;
  final NailSet set;
  TryOnRecord(this.id, this.created, this.before, this.result, this.set);
  Map<String, dynamic> toJson() => {
    'id': id,
    'created': created.toIso8601String(),
    'before': base64Encode(before),
    'result': base64Encode(result),
    'set': {
      'id': set.id,
      'name': set.name,
      'category': set.category,
      'images': set.images,
      'pattern': set.pattern,
      'palette': set.palette.map((c) => c.toARGB32()).toList(),
    },
  };
  factory TryOnRecord.fromJson(Map<String, dynamic> json) {
    final s = json['set'] as Map;
    return TryOnRecord(
      json['id'] as String,
      DateTime.parse(json['created'] as String),
      base64Decode(json['before'] as String),
      base64Decode(json['result'] as String),
      NailSet(
        id: s['id'] as String,
        name: s['name'] as String,
        category: s['category'] as String,
        images: (s['images'] as List).cast<String>(),
        pattern: s['pattern'] as String,
        palette: (s['palette'] as List).map((c) => Color(c as int)).toList(),
      ),
    );
  }
}

class TryOnHistory {
  static const key = 'nail_try_on_history_v1';
  static Future<List<TryOnRecord>> load({
    int offset = 0,
    AuthService? auth,
  }) async {
    final account = auth ?? AuthService.instance;
    if (account.user != null) {
      final response = await account.historyRequest(
        'GET',
        null,
        '?offset=$offset',
      );
      return (response['records'] as List)
          .map((r) => TryOnRecord.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList();
    }
    return _load(userStorageKey(key));
  }

  static Future<List<TryOnRecord>> _load(String storageKey) async {
    final prefs = await SharedPreferences.getInstance();
    final output = <TryOnRecord>[];
    for (final text in prefs.getStringList(storageKey) ?? <String>[]) {
      try {
        output.add(
          TryOnRecord.fromJson(jsonDecode(text) as Map<String, dynamic>),
        );
      } catch (_) {
        /* skip damaged entry */
      }
    }
    return output;
  }

  static Uint8List thumbnail(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw const FormatException('Không đọc được ảnh lịch sử');
    }
    final normalized = img.bakeOrientation(image);
    final resized = normalized.width > 720 || normalized.height > 720
        ? img.copyResize(
            normalized,
            width: normalized.width >= normalized.height ? 720 : null,
            height: normalized.height > normalized.width ? 720 : null,
          )
        : normalized;
    return Uint8List.fromList(img.encodeJpg(resized, quality: 82));
  }

  static Future<void> add(
    Uint8List before,
    Uint8List result,
    NailSet set, {
    AuthService? auth,
  }) async {
    final account = auth ?? AuthService.instance;
    final now = DateTime.now().toUtc();
    final record = TryOnRecord(
      now.microsecondsSinceEpoch.toString(),
      now,
      thumbnail(before),
      thumbnail(result),
      set,
    );
    if (account.user != null) {
      await account.historyRequest('POST', record.toJson());
      return;
    }
    final storageKey = userStorageKey(key);
    final records = await _load(storageKey);
    records.insert(0, record);
    await _write(records.take(5).toList(), storageKey);
  }

  static Future<void> remove(String id, {AuthService? auth}) async {
    final account = auth ?? AuthService.instance;
    if (account.user != null) {
      await account.historyRequest(
        'DELETE',
        null,
        '/${Uri.encodeComponent(id)}',
      );
      return;
    }
    final storageKey = userStorageKey(key);
    await _write(
      (await _load(storageKey)).where((r) => r.id != id).toList(),
      storageKey,
    );
  }

  static Future<void> _write(
    List<TryOnRecord> records,
    String storageKey,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final success = await prefs.setStringList(
      storageKey,
      records.map((r) => jsonEncode(r.toJson())).toList(),
    );
    if (!success) throw StateError('Không đủ dung lượng để lưu lịch sử');
  }
}
