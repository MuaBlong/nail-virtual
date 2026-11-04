import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/nail_set.dart';
import '../services/nail_asset_service.dart';
import 'nail_artwork.dart';
import '../services/nail_surface_service.dart';

enum NailFinish { natural, glossy, matte }

/// Fit the complete design across the width of the measured nail at every row,
/// rather than cutting off the sides of a rectangular sticker.
class NailFittedArtwork extends StatelessWidget {
  final NailSet set;
  final int finger;
  final List<Offset>? polygon;
  final List<double>? shading;
  final Map<String, dynamic>? surface;
  final NailFinish finish;
  final bool useDetectedCoverage;
  const NailFittedArtwork({
    super.key,
    required this.set,
    required this.finger,
    this.polygon,
    this.shading,
    this.surface,
    this.finish = NailFinish.natural,
    this.useDetectedCoverage = true,
  });
  Widget _render(ui.Image? image) {
    Widget render(NailSurfaceImages? textures) => CustomPaint(
      painter: _FittedPainter(
        set,
        finger,
        polygon!,
        shading,
        image,
        textures,
        finish,
        useDetectedCoverage,
      ),
      size: Size.infinite,
    );
    if (surface == null) return render(null);
    return FutureBuilder<NailSurfaceImages>(
      future: NailSurfaceService.load(surface!),
      builder: (context, snapshot) => render(snapshot.data),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (polygon == null || polygon!.length < 3) {
      return NailArtwork(set: set, finger: finger);
    }
    if (set.images.isEmpty) {
      return _render(null);
    }
    return FutureBuilder<ui.Image>(
      future: NailAssetService.decoded(set.images[finger % 5]),
      builder: (context, snapshot) =>
          snapshot.hasData ? _render(snapshot.data) : const SizedBox(),
    );
  }
}

class _FittedPainter extends CustomPainter {
  final NailSet set;
  final int finger;
  final List<Offset> polygon;
  final List<double>? shading;
  final ui.Image? image;
  final NailSurfaceImages? surface;
  final NailFinish finish;
  final bool useDetectedCoverage;
  _FittedPainter(
    this.set,
    this.finger,
    this.polygon,
    this.shading,
    this.image,
    this.surface,
    this.finish,
    this.useDetectedCoverage,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addPolygon(
        polygon
            .map((p) => Offset(p.dx * size.width, p.dy * size.height))
            .toList(),
        true,
      );
    canvas.save();
    canvas.clipPath(path, doAntiAlias: true);
    final rect = Offset.zero & size;
    // Isolate all material passes before compositing with the photographed hand.
    final materialPaint = Paint()..color = Colors.white.withValues(alpha: .975);
    if (surface != null) {
      final tint = surface!.tint;
      materialPaint.colorFilter = ColorFilter.matrix([
        tint[0],
        0,
        0,
        0,
        0,
        0,
        tint[1],
        0,
        0,
        0,
        0,
        0,
        tint[2],
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]);
    }
    canvas.saveLayer(rect, materialPaint);
    ui.Picture? picture;
    if (image == null) {
      final recorder = ui.PictureRecorder();
      NailPatternPainter(
        set,
        finger,
        surfaceGloss: false,
      ).paint(Canvas(recorder), size);
      picture = recorder.endRecording();
    }
    final paint = Paint()..filterQuality = FilterQuality.high;
    for (var y = 0.0; y < size.height; y += .75) {
      final sample = ((y + .375) / size.height).clamp(.001, .999);
      final crossings = <double>[];
      for (var i = 0; i < polygon.length; i++) {
        final a = polygon[i], b = polygon[(i + 1) % polygon.length];
        if ((a.dy <= sample && b.dy > sample) ||
            (b.dy <= sample && a.dy > sample)) {
          crossings.add(a.dx + (sample - a.dy) * (b.dx - a.dx) / (b.dy - a.dy));
        }
      }
      if (crossings.length < 2) continue;
      crossings.sort();
      final left = crossings.first * size.width,
          right = crossings.last * size.width;
      if (image != null) {
        final sy = y / size.height * image!.height;
        final bottom = ((y + .85) / size.height * image!.height).clamp(
          0.0,
          image!.height.toDouble(),
        );
        canvas.drawImageRect(
          image!,
          Rect.fromLTRB(0, sy, image!.width.toDouble(), bottom),
          Rect.fromLTRB(left, y, right, y + .85),
          paint,
        );
      } else {
        canvas.save();
        // Adjacent subpixel strips must not each antialias their shared edge:
        // that produces visible horizontal bands after the nail is scaled.
        canvas.clipRect(
          Rect.fromLTRB(left, y, right, y + .85),
          doAntiAlias: false,
        );
        canvas.translate(left, 0);
        canvas.scale((right - left) / size.width, 1);
        canvas.drawPicture(picture!);
        canvas.restore();
      }
    }
    picture?.dispose();
    if (surface != null) {
      paint
        ..shader = null
        ..color = Colors.white.withValues(alpha: .85)
        ..blendMode = BlendMode.softLight
        ..filterQuality = FilterQuality.high;
      canvas.drawImageRect(
        surface!.lighting,
        Rect.fromLTWH(
          0,
          0,
          surface!.lighting.width.toDouble(),
          surface!.lighting.height.toDouble(),
        ),
        rect,
        paint,
      );
      if (finish != NailFinish.matte) {
        paint
          ..color = Colors.white.withValues(
            alpha: finish == NailFinish.glossy ? .65 : .36,
          )
          ..blendMode = BlendMode.screen;
        canvas.drawImageRect(
          surface!.highlights,
          Rect.fromLTWH(
            0,
            0,
            surface!.highlights.width.toDouble(),
            surface!.highlights.height.toDouble(),
          ),
          rect,
          paint,
        );
      }
    } else if (shading?.length == 128) {
      paint
        ..blendMode = BlendMode.softLight
        ..filterQuality = FilterQuality.none;
      for (var y = 0; y < 16; y++) {
        for (var x = 0; x < 8; x++) {
          final grey = (shading![y * 8 + x].clamp(0.0, 1.0) * 255).round();
          paint.color = Color.fromARGB(150, grey, grey, grey);
          canvas.drawRect(
            Rect.fromLTWH(
              x * size.width / 8,
              y * size.height / 16,
              size.width / 8 + .1,
              size.height / 16 + .1,
            ),
            paint,
          );
        }
      }
    }
    // A restrained lateral falloff suggests the curved nail plate, not a flat sticker.
    paint
      ..blendMode = BlendMode.srcOver
      ..color = Colors.white
      ..shader = LinearGradient(
        colors: [
          Colors.black.withValues(alpha: .18),
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: .14),
        ],
        stops: const [0, .22, .72, 1],
      ).createShader(rect);
    canvas.drawRect(rect, paint);
    paint
      ..shader = null
      ..color = Colors.white
      ..blendMode = BlendMode.dstIn;
    if (surface != null && useDetectedCoverage) {
      canvas.drawImageRect(
        surface!.coverage,
        Rect.fromLTWH(
          0,
          0,
          surface!.coverage.width.toDouble(),
          surface!.coverage.height.toDouble(),
        ),
        rect,
        paint,
      );
    } else {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, .55);
      canvas.drawPath(path, paint);
    }
    canvas.restore(); // Material layer, including inward edge feather.
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FittedPainter old) =>
      old.set != set ||
      old.finger != finger ||
      old.polygon != polygon ||
      old.shading != shading ||
      old.surface != surface ||
      old.useDetectedCoverage != useDetectedCoverage ||
      old.finish != finish ||
      old.image != image;
}
