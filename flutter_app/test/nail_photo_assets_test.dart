import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_app/models/nail_set.dart';
import 'package:flutter_app/services/nail_asset_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'each photographic sheet separates into five upright transparent nails',
    () async {
      for (final set in nailSets.where((s) => s.images.isNotEmpty)) {
        final data = await rootBundle.load(
          'assets/nails/collections/${set.id}.png',
        );
        final sheet = img.decodeImage(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        )!;
        for (var i = 0; i < 5; i++) {
          final nail = NailAssetService.sliceAtlas(sheet, i);
          expect(nail.width, greaterThan(100), reason: '${set.id}:$i');
          expect(nail.height, greaterThan(nail.width));
          expect(nail.getPixel(nail.width ~/ 2, 0).a, 0);
          expect(
            nail.getPixel(nail.width ~/ 2, nail.height ~/ 2).a,
            greaterThan(40),
          );
        }
      }
    },
  );
}
