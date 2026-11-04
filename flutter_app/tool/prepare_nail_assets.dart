import 'dart:convert';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:flutter_app/services/nail_atlas.dart';

// Compile original transparent sheets into ready-to-load per-finger assets.
void main() {
  final catalogFile = File('assets/nails/collections/catalog.json');
  final catalog = jsonDecode(catalogFile.readAsStringSync()) as List;
  Directory('assets/nails/prepared').createSync(recursive: true);
  for (final set in catalog) {
    final id = set['id'];
    final source = img.decodeImage(
      File('assets/nails/collections/$id.png').readAsBytesSync(),
    )!;
    final paths = <String>[];
    for (var finger = 0; finger < 5; finger++) {
      final nail = sliceNailAtlas(source, finger);
      var top = nail.height, bottom = -1;
      for (var y = 0; y < nail.height; y++) {
        for (var x = 0; x < nail.width; x++) {
          if (nail.getPixel(x, y).a > 8) {
            if (y < top) top = y;
            if (y > bottom) bottom = y;
          }
        }
      }
      if (bottom < top) throw StateError('Empty nail: $id/$finger');
      var texture = img.copyCrop(
        nail,
        x: 0,
        y: top,
        width: nail.width,
        height: bottom - top + 1,
      );
      if (texture.height > 480) {
        texture = img.copyResize(
          texture,
          height: 480,
          interpolation: img.Interpolation.average,
        );
      }
      final path = 'assets/nails/prepared/${id}_$finger.png';
      File(path).writeAsBytesSync(img.encodePng(texture));
      paths.add(path);
    }
    set['images'] = paths;
    stdout.writeln('$id: 5 fingers ready');
  }
  final json = const JsonEncoder.withIndent('  ').convert(catalog);
  catalogFile.writeAsStringSync(json);
  File('../backend/catalog.json').writeAsStringSync(json);
}
