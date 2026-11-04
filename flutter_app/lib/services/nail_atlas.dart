import 'package:image/image.dart' as img;

img.Image sliceNailAtlas(img.Image sheet, int index) {
  if (index < 0 || index > 4) throw const FormatException('Invalid finger');
  final bands = <(int, int)>[];
  var start = -1;
  for (var x = 0; x <= sheet.width; x++) {
    var count = 0;
    if (x < sheet.width) {
      for (var y = 0; y < sheet.height; y++) {
        if (sheet.getPixel(x, y).a > 40) count++;
      }
    }
    final active = count > sheet.height * .08;
    if (active && start < 0) start = x;
    if (!active && start >= 0) {
      if (x - start > sheet.width * .04) bands.add((start, x));
      start = -1;
    }
  }
  if (bands.length != 5) throw const FormatException('Expected five nails');
  final (left, right) = bands[index];
  final crop = img.copyCrop(
    sheet,
    x: left,
    y: 0,
    width: right - left,
    height: sheet.height,
  );
  // Remove faint isolated background specks without touching the source file.
  for (var x = 0; x < crop.width; x++) {
    var top = -1, bottom = -1;
    for (var y = 0; y < crop.height; y++) {
      if (crop.getPixel(x, y).a > 120) {
        if (top < 0) top = y;
        bottom = y;
      }
    }
    for (var y = 0; y < crop.height; y++) {
      if (top < 0 || y < top - 1 || y > bottom + 1) crop.getPixel(x, y).a = 0;
    }
  }
  return crop;
}
