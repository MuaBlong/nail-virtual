import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/nail_set.dart';
import '../services/nail_asset_service.dart';

class NailArtwork extends StatelessWidget {
  final NailSet set;
  final int finger;
  final bool preview;
  const NailArtwork({
    super.key,
    required this.set,
    this.finger = 0,
    this.preview = false,
  });
  @override
  Widget build(BuildContext context) {
    final Widget child = set.images.isNotEmpty
        ? FutureBuilder<Uint8List>(
            future: NailAssetService.load(set.images[finger % 5]),
            builder: (context, snapshot) => snapshot.hasData
                ? Image.memory(
                    snapshot.data!,
                    fit: BoxFit.fill,
                    gaplessPlayback: true,
                  )
                : Center(
                    child: Icon(
                      snapshot.hasError
                          ? Icons.broken_image_outlined
                          : Icons.more_horiz,
                      color: Colors.pink.shade200,
                    ),
                  ),
          )
        : CustomPaint(
            painter: NailPatternPainter(set, finger),
            size: Size.infinite,
          );
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(preview ? 24 : 5),
        bottom: const Radius.circular(8),
      ),
      child: child,
    );
  }
}

class NailPatternPainter extends CustomPainter {
  final NailSet set;
  final int finger;
  final bool surfaceGloss;
  NailPatternPainter(this.set, this.finger, {this.surfaceGloss = true});
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = ['solid', 'flower', 'dots', 'marble'].contains(set.pattern)
        ? set.palette[finger % set.palette.length]
        : set.palette.first;
    final paint = Paint()..color = base;
    if (set.pattern == 'ombre') {
      paint.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [set.palette.first, set.palette.last],
      ).createShader(rect);
    }
    if (set.pattern == 'chrome') {
      paint.shader = LinearGradient(
        colors: [base, set.palette.last, Colors.white, base, set.palette.last],
        stops: const [0, .3, .45, .68, 1],
      ).createShader(rect);
    }
    if (set.pattern == 'cat_eye') {
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [base, base, set.palette.last, base, base],
        stops: const [0, .36, .5, .64, 1],
      ).createShader(rect);
    }
    if (set.pattern == 'aura') {
      paint.shader = RadialGradient(
        radius: .9,
        colors: [set.palette.last, base],
      ).createShader(rect);
    }
    canvas.drawRect(rect, paint);
    paint.shader = null;
    final accent = set.palette.last;
    if (set.pattern == 'double_french' || set.pattern == 'diagonal') {
      paint.color = accent;
      final tip = Path()
        ..moveTo(0, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, size.height * .16)
        ..quadraticBezierTo(
          size.width * .5,
          size.height * (set.pattern == 'diagonal' ? .1 : .3),
          0,
          size.height * (set.pattern == 'diagonal' ? .4 : .16),
        )
        ..close();
      canvas.drawPath(tip, paint);
      if (set.pattern == 'double_french') {
        paint
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * .025;
        canvas.drawPath(
          Path()
            ..moveTo(0, size.height * .24)
            ..quadraticBezierTo(
              size.width / 2,
              size.height * .38,
              size.width,
              size.height * .24,
            ),
          paint,
        );
        paint.style = PaintingStyle.fill;
      }
    }
    if (set.pattern == 'checker') {
      paint.color = accent;
      for (var row = 0; row < 8; row++) {
        for (var col = 0; col < 4; col++) {
          if ((row + col).isEven) {
            canvas.drawRect(
              Rect.fromLTWH(
                col * size.width / 4,
                row * size.height / 8,
                size.width / 4 + .2,
                size.height / 8 + .2,
              ),
              paint,
            );
          }
        }
      }
    }
    if (['glitter', 'foil', 'tortoise', 'leopard'].contains(set.pattern)) {
      final random = math.Random(53 + finger);
      final count = set.pattern == 'glitter'
          ? 200
          : (set.pattern == 'foil' ? 16 : 18);
      for (var i = 0; i < count; i++) {
        final center = Offset(
          random.nextDouble() * size.width,
          random.nextDouble() * size.height,
        );
        paint.color = (i.isEven ? accent : Colors.white).withValues(
          alpha: .35 + random.nextDouble() * .5,
        );
        if (set.pattern == 'glitter') {
          canvas.drawCircle(
            center,
            size.width * (.008 + random.nextDouble() * .018),
            paint,
          );
        } else if (set.pattern == 'foil') {
          final r = size.width * (.05 + random.nextDouble() * .1);
          canvas.drawPath(
            Path()
              ..moveTo(center.dx - r, center.dy)
              ..lineTo(center.dx, center.dy - r)
              ..lineTo(center.dx + r, center.dy + r * .3)
              ..lineTo(center.dx - r * .2, center.dy + r)
              ..close(),
            paint,
          );
        } else {
          paint.color = accent.withValues(
            alpha: set.pattern == 'tortoise' ? .55 : .9,
          );
          final r = size.width * (.07 + random.nextDouble() * .08);
          if (set.pattern == 'leopard') {
            paint
              ..style = PaintingStyle.stroke
              ..strokeWidth = size.width * .045;
            canvas.drawArc(
              Rect.fromCircle(center: center, radius: r),
              .4,
              4.5,
              false,
              paint,
            );
            paint.style = PaintingStyle.fill;
          } else {
            canvas.drawOval(
              Rect.fromCenter(center: center, width: r * 3, height: r * 2),
              paint,
            );
          }
        }
      }
    }
    if (set.pattern == 'hearts') {
      paint.color = accent;
      for (var i = 0; i < 3; i++) {
        final x = size.width * (i.isEven ? 0.35 : .65),
            y = size.height * (.2 + i * .28),
            r = size.width * .16;
        canvas.drawPath(
          Path()
            ..moveTo(x, y + r)
            ..cubicTo(x - r * 2, y, x - r, y - r, x, y - r * .3)
            ..cubicTo(x + r, y - r, x + r * 2, y, x, y + r)
            ..close(),
          paint,
        );
      }
    }
    if (set.pattern == 'leaves' ||
        set.pattern == 'line_art' ||
        set.pattern == 'zebra') {
      paint
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .035;
      if (set.pattern == 'leaves') {
        canvas.drawPath(
          Path()
            ..moveTo(size.width * .25, size.height)
            ..quadraticBezierTo(
              size.width * .7,
              size.height * .5,
              size.width * .5,
              0,
            ),
          paint,
        );
        paint.style = PaintingStyle.fill;
        for (var i = 0; i < 5; i++) {
          final y = size.height * (.15 + i * .17),
              x = size.width * (i.isEven ? 0.35 : .64);
          canvas.save();
          canvas.translate(x, y);
          canvas.rotate(i.isEven ? -.6 : .6);
          canvas.drawOval(
            Rect.fromCenter(
              center: Offset.zero,
              width: size.width * .3,
              height: size.height * .055,
            ),
            paint,
          );
          canvas.restore();
        }
      } else {
        for (var i = 0; i < (set.pattern == 'zebra' ? 9 : 3); i++) {
          paint.strokeWidth =
              size.width * (set.pattern == 'zebra' ? 0.045 : .025);
          canvas.drawPath(
            Path()
              ..moveTo(-size.width * .1, size.height * (i * .12))
              ..cubicTo(
                size.width * .8,
                size.height * (i * .12 + .12),
                size.width * .1,
                size.height * (i * .12 + .3),
                size.width * 1.1,
                size.height * (i * .12 + .2),
              ),
            paint,
          );
        }
      }
      paint.style = PaintingStyle.fill;
    }
    if (set.pattern == 'pearls') {
      for (var i = 0; i < 9; i++) {
        final center = Offset(
          size.width * (i.isEven ? 0.17 : .83),
          size.height * (.12 + i * .09),
        );
        final r = size.width * .065;
        paint.shader = RadialGradient(
          colors: [Colors.white, const Color(0xFFBFB7B1)],
        ).createShader(Rect.fromCircle(center: center, radius: r));
        canvas.drawCircle(center, r, paint);
      }
      paint.shader = null;
    }
    if (set.pattern == 'plaid') {
      paint.color = accent.withValues(alpha: .6);
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(
          Rect.fromLTWH(i * size.width * .32, 0, size.width * .11, size.height),
          paint,
        );
      }
      for (var i = 0; i < 6; i++) {
        canvas.drawRect(
          Rect.fromLTWH(0, i * size.height * .2, size.width, size.height * .06),
          paint,
        );
      }
      paint.color = Colors.white.withValues(alpha: .7);
      canvas.drawRect(
        Rect.fromLTWH(size.width * .45, 0, size.width * .025, size.height),
        paint,
      );
    }
    if (set.pattern == 'french') {
      paint.color = set.palette.length > 1 ? set.palette.last : Colors.white;
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(size.width, 0)
          ..lineTo(size.width, size.height * .22)
          ..quadraticBezierTo(
            size.width / 2,
            size.height * .38,
            0,
            size.height * .22,
          )
          ..close(),
        paint,
      );
    }
    if (set.pattern == 'dots' || set.pattern == 'flower') {
      for (var row = 0; row < 3; row++) {
        for (var col = 0; col < 2; col++) {
          final c = Offset(
            size.width * (.28 + col * .45),
            size.height * (.23 + row * .29),
          );
          paint.color = Colors.white.withValues(alpha: .9);
          if (set.pattern == 'flower') {
            for (var i = 0; i < 5; i++) {
              final angle = i * math.pi * 2 / 5;
              canvas.drawCircle(
                c + Offset(math.cos(angle), math.sin(angle)) * size.width * .09,
                size.width * .065,
                paint,
              );
            }
            paint.color = const Color(0xFFEBC35F);
          }
          canvas.drawCircle(c, size.width * .045, paint);
        }
      }
    }
    if (set.pattern == 'stars') {
      paint.color = const Color(0xFFFFE5A5);
      for (var i = 0; i < 4; i++) {
        final x = size.width * (i.isEven ? .3 : .7);
        final y = size.height * (.16 + i * .22);
        final r = size.width * .13;
        canvas.drawPath(
          Path()
            ..moveTo(x, y - r)
            ..lineTo(x + r * .3, y - r * .3)
            ..lineTo(x + r, y)
            ..lineTo(x + r * .3, y + r * .3)
            ..lineTo(x, y + r)
            ..lineTo(x - r * .3, y + r * .3)
            ..lineTo(x - r, y)
            ..lineTo(x - r * .3, y - r * .3)
            ..close(),
          paint,
        );
      }
    }
    if (set.pattern == 'marble') {
      paint
        ..color = Colors.white.withValues(alpha: .8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, size.width * .025);
      for (var i = 0; i < 3; i++) {
        canvas.drawPath(
          Path()
            ..moveTo(size.width * (i * .4 - .1), 0)
            ..cubicTo(
              size.width,
              size.height * .25,
              -size.width * .2,
              size.height * .65,
              size.width * (i * .35 + .2),
              size.height,
            ),
          paint,
        );
      }
      paint.style = PaintingStyle.fill;
    }
    if (!surfaceGloss) return;
    paint.shader = LinearGradient(
      colors: [
        Colors.white.withValues(alpha: .28),
        Colors.transparent,
        Colors.black.withValues(alpha: .08),
      ],
      stops: const [0, .4, 1],
    ).createShader(rect);
    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(NailPatternPainter old) =>
      old.set != set ||
      old.finger != finger ||
      old.surfaceGloss != surfaceGloss;
}
