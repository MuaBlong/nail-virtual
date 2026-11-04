import 'dart:math' as math;
import 'package:flutter/material.dart';

enum NailShape { natural, square, oval, round, pointed, coffin }

extension NailShapeLabel on NailShape {
  String get label => switch (this) {
    NailShape.natural => 'Dáng gốc',
    NailShape.square => 'Vuông',
    NailShape.coffin => 'Hình thang',
    NailShape.oval => 'Oval',
    NailShape.round => 'Bầu',
    NailShape.pointed => 'Nhọn',
  };
}

/// Change the free edge, preserving the detected cuticle and lower sidewalls.
List<Offset>? nailShapePolygon(NailShape shape, List<Offset>? detected) {
  if (shape == NailShape.natural) return detected;
  final source = detected != null && detected.length >= 3
      ? detected
      : const [
          Offset(.15, 0),
          Offset(.85, 0),
          Offset(1, .3),
          Offset(1, .85),
          Offset(.75, 1),
          Offset(.25, 1),
          Offset(0, .85),
          Offset(0, .3),
        ];
  (double, double) span(double y) {
    final xs = <double>[];
    for (var i = 0; i < source.length; i++) {
      final a = source[i], b = source[(i + 1) % source.length];
      if ((a.dy <= y && b.dy > y) || (b.dy <= y && a.dy > y)) {
        xs.add(a.dx + (y - a.dy) * (b.dx - a.dx) / (b.dy - a.dy));
      }
    }
    if (xs.length < 2) {
      final edge =
          source.where((p) => (p.dy - y).abs() < .002).map((p) => p.dx).toList()
            ..sort();
      return edge.isEmpty ? (.5, .5) : (edge.first, edge.last);
    }
    xs.sort();
    return (xs.first, xs.last);
  }

  const join = .65;
  final (left, right) = span(join);
  final center = (left + right) / 2, half = (right - left) / 2;
  final result = <Offset>[];
  final opposite = <Offset>[];
  // Preserve all lower contour vertices exactly, so selecting another tip shape
  // cannot relocate the cuticle. Only generate the upper part of the silhouette.
  for (var i = 0; i <= 52; i++) {
    final y = join * i / 52;
    final double factor;
    switch (shape) {
      case NailShape.square:
        factor = y < .035 ? .90 + .10 * math.sqrt(y / .035) : 1;
      case NailShape.coffin:
        // Flat free edge, tapered straight sides, exact lower contour junction.
        factor = .58 + .42 * y / join;
      case NailShape.oval:
      case NailShape.round:
        final cap = shape == NailShape.oval ? .60 : .30;
        final t = (y / cap).clamp(0.0, 1.0);
        factor = math.sqrt(math.max(0, 1 - (1 - t) * (1 - t)));
      case NailShape.pointed:
        factor = math.pow(y / join, .80).toDouble();
      case NailShape.natural:
        factor = 1;
    }
    result.add(Offset(center - half * factor, y));
    opposite.add(Offset(center + half * factor, y));
  }
  // Trace lower vertices from the left junction to the right junction in their
  // original cyclic order, choosing the arc that contains the cuticle (max y).
  final lower = source.where((p) => p.dy > join).toList();
  if (lower.isNotEmpty) {
    final start = source.indexWhere(
      (p) =>
          p.dy > join &&
          source[(source.indexOf(p) - 1 + source.length) % source.length].dy <=
              join,
    );
    final arc = <Offset>[];
    if (start >= 0) {
      var i = start;
      while (source[i].dy > join) {
        arc.add(source[i]);
        i = (i + 1) % source.length;
        if (i == start) break;
      }
    } else {
      arc.addAll(lower);
    }
    if (arc.isNotEmpty && arc.first.dx > arc.last.dx) {
      result.addAll(arc.reversed);
    } else {
      result.addAll(arc);
    }
  }
  result.addAll(opposite.reversed);
  return result;
}
