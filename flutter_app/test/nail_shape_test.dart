import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/nail_shape.dart';

void main() {
  test('coffin has a flat tapered tip and preserves the cuticle', () {
    const detected = [
      Offset(.1, 0),
      Offset(.9, 0),
      Offset(1, .65),
      Offset(.9, .9),
      Offset(.7, 1),
      Offset(.3, 1),
      Offset(.1, .9),
      Offset(0, .65),
    ];
    final shape = nailShapePolygon(NailShape.coffin, detected)!;
    final tip = shape.where((p) => p.dy == 0).toList();
    expect(tip.length, 2);
    expect(tip.last.dx - tip.first.dx, closeTo(.58, .0001));
    for (final p in detected.where((p) => p.dy > .65)) {
      expect(shape, contains(p));
    }
    expect(
      shape.every((p) => p.dx >= 0 && p.dx <= 1 && p.dy >= 0 && p.dy <= 1),
      isTrue,
    );
    expect(nailShapePolygon(NailShape.coffin, null), isNotEmpty);
  });
}
