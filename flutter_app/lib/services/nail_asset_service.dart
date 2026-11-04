import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui' as ui;
import 'nail_atlas.dart';

/// Remove transparent padding without modifying the original design assets.
class NailAssetService {
  static final Map<String, Future<Uint8List>> _cache = {};
  static final Map<String, Future<img.Image>> _atlases = {};

  // Locate the five opaque nail columns; generated sheets have unequal gaps.
  static img.Image sliceAtlas(img.Image sheet, int index) =>
      sliceNailAtlas(sheet, index);
  static final Map<String, Future<ui.Image>> _decoded = {};
  static Future<ui.Image> decoded(String path) => _decoded.putIfAbsent(
    path,
    () async {
      final source = img.decodeImage(await load(path))!;
      final edges = <(int, int)>[];
      for (var y = 0; y < source.height; y++) {
        var left = source.width, right = -1;
        for (var x = 0; x < source.width; x++) {
          if (source.getPixel(x, y).a > 8) {
            if (x < left) left = x;
            if (x > right) right = x;
          }
        }
        edges.add((left, right));
      }
      final rectified = img.Image(
        width: source.width,
        height: source.height,
        numChannels: 4,
      );
      for (var y = 0; y < source.height; y++) {
        var row = y;
        if (edges[row].$2 < edges[row].$1) {
          for (var delta = 1; delta < source.height; delta++) {
            if (y + delta < source.height &&
                edges[y + delta].$2 >= edges[y + delta].$1) {
              row = y + delta;
              break;
            }
            if (y - delta >= 0 && edges[y - delta].$2 >= edges[y - delta].$1) {
              row = y - delta;
              break;
            }
          }
        }
        final (left, right) = edges[row];
        for (var x = 0; x < source.width; x++) {
          final sx =
              left +
              ((right - left) * x / (source.width - 1).clamp(1, source.width))
                  .round();
          final pixel = source.getPixel(sx, row);
          rectified.setPixelRgba(x, y, pixel.r, pixel.g, pixel.b, 255);
        }
      }
      final codec = await ui.instantiateImageCodec(
        Uint8List.fromList(img.encodePng(rectified)),
      );
      try {
        return (await codec.getNextFrame()).image;
      } finally {
        codec.dispose();
      }
    },
  );

  static Future<Uint8List> load(String path) => _cache.putIfAbsent(
    path,
    () async {
      late final Uint8List bytes;
      final atlas = RegExp(r'^(.+)#nail=([0-4])$').firstMatch(path);
      if (atlas != null) {
        final source = atlas.group(1)!;
        final sheet = await _atlases.putIfAbsent(source, () async {
          final data = await rootBundle.load(source);
          return img.decodeImage(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          )!;
        });
        bytes = Uint8List.fromList(
          img.encodePng(sliceAtlas(sheet, int.parse(atlas.group(2)!))),
        );
      } else if (path.startsWith('data:image/png;base64,')) {
        bytes = base64Decode(path.substring('data:image/png;base64,'.length));
      } else if (path.startsWith('http://') || path.startsWith('https://')) {
        final response = await http
            .get(Uri.parse(path))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw const FormatException('Không tải được ảnh mẫu');
        }
        if (response.bodyBytes.length > 5 * 1024 * 1024) {
          throw const FormatException('Ảnh mẫu quá lớn');
        }
        bytes = response.bodyBytes;
      } else {
        final data = await rootBundle.load(path);
        bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      }
      if (path.startsWith('assets/nails/prepared/')) return bytes;
      final image = img.decodeImage(bytes);
      if (image == null) throw FormatException('Không đọc được mẫu $path');
      var left = image.width;
      var top = image.height;
      var right = -1;
      var bottom = -1;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          if (image.getPixel(x, y).a <= 8) continue;
          if (x < left) left = x;
          if (x > right) right = x;
          if (y < top) top = y;
          if (y > bottom) bottom = y;
        }
      }
      if (right < left || bottom < top) {
        throw FormatException('Mẫu $path hoàn toàn trong suốt');
      }
      return Uint8List.fromList(
        img.encodePng(
          img.copyCrop(
            image,
            x: left,
            y: top,
            width: right - left + 1,
            height: bottom - top + 1,
          ),
        ),
      );
    },
  );
}
