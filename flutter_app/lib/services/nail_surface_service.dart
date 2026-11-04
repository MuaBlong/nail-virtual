import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

class NailSurfaceImages {
  final ui.Image lighting;
  final ui.Image highlights;
  final ui.Image coverage;
  final List<double> tint;
  NailSurfaceImages(this.lighting, this.highlights, this.coverage, this.tint);
}

class NailSurfaceService {
  static final Map<String, Future<NailSurfaceImages>> _cache = {};
  static final Map<String, NailSurfaceImages> _ready = {};
  static Future<ui.Image> _decode(String uri) async {
    const prefix = 'data:image/png;base64,';
    if (!uri.startsWith(prefix) || uri.length > 200000) {
      throw const FormatException('Dữ liệu bề mặt móng không hợp lệ');
    }
    final codec = await ui.instantiateImageCodec(
      base64Decode(uri.substring(prefix.length)),
    );
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  static Future<NailSurfaceImages> load(Map<String, dynamic> surface) {
    final key =
        '${surface['lighting']}|${surface['highlights']}|${surface['coverage']}|${surface['tint']}';
    if (_ready.containsKey(key)) return SynchronousFuture(_ready[key]!);
    if (_cache.length > 24 && !_cache.containsKey(key)) {
      final oldest = _cache.keys.first;
      _cache.remove(oldest);
      _ready.remove(oldest);
    }
    return _cache.putIfAbsent(key, () async {
      final images = <ui.Image>[];
      try {
        for (final name in ['lighting', 'highlights', 'coverage']) {
          images.add(await _decode(surface[name] as String));
        }
        final supplied = surface['tint'];
        final tint = supplied is List && supplied.length == 3
            ? supplied
                  .map((v) => (v as num).toDouble().clamp(.94, 1.06))
                  .toList()
            : <double>[1, 1, 1];
        final result = NailSurfaceImages(images[0], images[1], images[2], tint);
        _ready[key] = result;
        return result;
      } catch (_) {
        for (final image in images) {
          image.dispose();
        }
        rethrow;
      }
    });
  }
}
