import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Position stores the top-left of an unscaled frame; transforms pivot on its
/// center. Offset that center so the base (local bottom center) stays fixed.
Offset anchorNailBase({
  required Offset position,
  required Size canvas,
  required double oldHeight,
  required double newHeight,
  required double oldRotation,
  double? newRotation,
}) {
  if (canvas.isEmpty) return position;
  final angle = newRotation ?? oldRotation;
  final oldBase =
      Offset(-math.sin(oldRotation), math.cos(oldRotation)) * (oldHeight / 2);
  final newBase = Offset(-math.sin(angle), math.cos(angle)) * (newHeight / 2);
  final delta = oldBase - newBase;
  return position + Offset(delta.dx / canvas.width, delta.dy / canvas.height);
}
