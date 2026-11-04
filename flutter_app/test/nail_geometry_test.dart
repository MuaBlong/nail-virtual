import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/nail_geometry.dart';

Offset base(Offset position, Size canvas, double height, double angle) =>
    Offset(position.dx * canvas.width + 21, position.dy * canvas.height + 36) +
    Offset(-math.sin(angle), math.cos(angle)) * (height / 2);

void main() {
  const canvas = Size(360, 450);
  const position = Offset(.4, .3);
  for (final angle in [0.0, math.pi / 2, -math.pi / 2, math.pi / 4, -2.4]) {
    test('base stays fixed when length changes at angle $angle', () {
      final root = base(position, canvas, 72, angle);
      final longer = anchorNailBase(
        position: position,
        canvas: canvas,
        oldHeight: 72,
        newHeight: 120,
        oldRotation: angle,
      );
      expect(
        (base(longer, canvas, 120, angle) - root).distance,
        lessThan(1e-9),
      );
      final shorter = anchorNailBase(
        position: longer,
        canvas: canvas,
        oldHeight: 120,
        newHeight: 36,
        oldRotation: angle,
      );
      expect(
        (base(shorter, canvas, 36, angle) - root).distance,
        lessThan(1e-9),
      );
    });
  }
  test('upright length increase moves only the tip upward', () {
    final longer = anchorNailBase(
      position: position,
      canvas: canvas,
      oldHeight: 72,
      newHeight: 120,
      oldRotation: 0,
    );
    expect(longer.dx, position.dx);
    expect(longer.dy, closeTo(position.dy - 24 / canvas.height, 1e-9));
  });
  test('resetting rotation and length also preserves base', () {
    final moved = anchorNailBase(
      position: position,
      canvas: canvas,
      oldHeight: 120,
      newHeight: 50.4,
      oldRotation: .7,
      newRotation: 0,
    );
    expect(
      (base(moved, canvas, 50.4, 0) - base(position, canvas, 120, .7)).distance,
      lessThan(1e-9),
    );
  });
}
