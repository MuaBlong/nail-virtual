import 'dart:math' as math;
import 'package:flutter/material.dart';

class NailCharm {
  final String name, category, shape;
  final Color color;
  const NailCharm(this.name, this.category, this.shape, this.color);
}

const nailCharms = [
  NailCharm('Vương miện băng', 'Cụm đá & dây', 'crown', Color(0xFFE4F3FF)),
  NailCharm('Vương miện hồng', 'Cụm đá & dây', 'crown', Color(0xFFF4A2BF)),
  NailCharm('Vương miện tím', 'Cụm đá & dây', 'crown', Color(0xFFC5ADE7)),
  NailCharm('Hồ điệp xanh biển', 'Cụm đá & dây', 'wing', Color(0xFF57BEE8)),
  NailCharm('Hồ điệp ruby', 'Cụm đá & dây', 'wing', Color(0xFFE35A83)),
  NailCharm('Hồ điệp champagne', 'Cụm đá & dây', 'wing', Color(0xFFF0D38F)),
  NailCharm(
    'Ngọc xanh dây đôi',
    'Cụm đá & dây',
    'double_chain',
    Color(0xFF52B8CF),
  ),
  NailCharm(
    'Sapphire dây đôi',
    'Cụm đá & dây',
    'double_chain',
    Color(0xFF6292E1),
  ),
  NailCharm(
    'Ngọc lục bảo dây đôi',
    'Cụm đá & dây',
    'double_chain',
    Color(0xFF8BD9B2),
  ),
  NailCharm(
    'Giọt pha lê dây dài',
    'Cụm đá & dây',
    'pendant',
    Color(0xFFE4F3FF),
  ),
  NailCharm('Giọt tím dây dài', 'Cụm đá & dây', 'pendant', Color(0xFFC5ADE7)),
  NailCharm('Giọt hồng dây dài', 'Cụm đá & dây', 'pendant', Color(0xFFF4A2BF)),
  NailCharm('Đá tròn pha lê', 'Đính đá', 'round', Color(0xFFE4F3FF)),
  NailCharm('Đá kim cương', 'Đính đá', 'diamond', Color(0xFFE7EEFF)),
  NailCharm('Đá giọt nước', 'Đính đá', 'drop', Color(0xFFC5E8FF)),
  NailCharm('Đá mắt ngựa', 'Đính đá', 'marquise', Color(0xFFE9D5FF)),
  NailCharm('Đá ruby', 'Đính đá', 'round', Color(0xFFD53261)),
  NailCharm('Đá sapphire', 'Đính đá', 'diamond', Color(0xFF579FE3)),
  NailCharm('Đá champagne', 'Đính đá', 'round', Color(0xFFE5C27B)),
  NailCharm('Đá trái tim', 'Đính đá', 'heart', Color(0xFFF4A2BF)),
  NailCharm('Ngọc trai trắng', 'Ngọc trai', 'pearl', Color(0xFFFFF8E9)),
  NailCharm('Ngọc trai hồng', 'Ngọc trai', 'pearl', Color(0xFFF3C4D4)),
  NailCharm('Hạt vàng', 'Ngọc trai', 'pearl', Color(0xFFE2B650)),
  NailCharm('Hoa trắng nổi', 'Hoa & nơ', 'flower', Color(0xFFFFF7EF)),
  NailCharm('Hoa hồng nổi', 'Hoa & nơ', 'flower', Color(0xFFF2AEC6)),
  NailCharm('Hoa lavender', 'Hoa & nơ', 'flower', Color(0xFFC8B4EA)),
  NailCharm('Nơ hồng', 'Hoa & nơ', 'bow', Color(0xFFF1B0C6)),
  NailCharm('Nơ trắng', 'Hoa & nơ', 'bow', Color(0xFFFFF6ED)),
  NailCharm('Sao vàng', 'Charm', 'star', Color(0xFFE5BC61)),
  NailCharm('Sao bạc', 'Charm', 'star', Color(0xFFD9E9F6)),
  NailCharm('Tim hồng', 'Charm', 'heart', Color(0xFFECA1BC)),
  NailCharm('Bướm xanh', 'Charm', 'butterfly', Color(0xFFADCEEF)),
  NailCharm('Bướm tím', 'Charm', 'butterfly', Color(0xFFC5ADE7)),
  NailCharm('Vỏ sò', 'Charm', 'shell', Color(0xFFF2D6CA)),
];

class NailDecoration {
  final NailCharm charm;
  Offset position;
  double scale, rotation;
  NailDecoration(
    this.charm, {
    this.position = const Offset(.5, .5),
    this.scale = .32,
    this.rotation = 0,
  });
  void move(Offset delta) {
    position = Offset(
      (position.dx + delta.dx).clamp(.06, .94),
      (position.dy + delta.dy).clamp(.06, .94),
    );
  }
}

class CharmArtwork extends StatelessWidget {
  final NailCharm charm;
  const CharmArtwork(this.charm, {super.key});
  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: CharmPainter(charm), size: Size.infinite);
}

class CharmPainter extends CustomPainter {
  final NailCharm charm;
  CharmPainter(this.charm);
  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    canvas.save();
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side / 100);
    final bounds = const Rect.fromLTWH(10, 10, 80, 80);
    final path = Path();
    final shape = charm.shape;
    if (charm.category == 'Cụm đá & dây') {
      _paintJewelry(canvas);
      canvas.restore();
      return;
    }
    if (shape == 'heart') {
      path.moveTo(50, 88);
      path.cubicTo(-12, 44, 15, -2, 50, 30);
      path.cubicTo(85, -2, 112, 44, 50, 88);
    } else if (shape == 'diamond') {
      path.moveTo(50, 7);
      path.lineTo(91, 50);
      path.lineTo(50, 93);
      path.lineTo(9, 50);
      path.close();
    } else if (shape == 'drop') {
      path.moveTo(50, 5);
      path.cubicTo(40, 25, 10, 48, 18, 70);
      path.cubicTo(30, 104, 83, 96, 84, 67);
      path.cubicTo(84, 45, 60, 20, 50, 5);
    } else if (shape == 'marquise') {
      path.moveTo(50, 5);
      path.quadraticBezierTo(110, 50, 50, 95);
      path.quadraticBezierTo(-10, 50, 50, 5);
    } else if (shape == 'star') {
      for (var i = 0; i < 10; i++) {
        final a = -math.pi / 2 + i * math.pi / 5, r = i.isEven ? 44.0 : 20.0;
        final p = Offset(50 + math.cos(a) * r, 50 + math.sin(a) * r);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
    } else if (shape == 'flower') {
      for (var i = 0; i < 5; i++) {
        final a = i * math.pi * 2 / 5 - math.pi / 2;
        path.addOval(
          Rect.fromCircle(
            center: Offset(50 + 22 * math.cos(a), 50 + 22 * math.sin(a)),
            radius: 19,
          ),
        );
      }
    } else if (shape == 'bow' || shape == 'butterfly') {
      path.moveTo(50, 50);
      path.cubicTo(-10, 2, 0, 92, 50, 56);
      path.cubicTo(100, 92, 110, 2, 50, 50);
      if (shape == 'butterfly') {
        path.addOval(const Rect.fromLTWH(19, 52, 29, 34));
        path.addOval(const Rect.fromLTWH(52, 52, 29, 34));
      }
    } else if (shape == 'shell') {
      path.moveTo(50, 90);
      path.cubicTo(-20, 58, 12, 6, 50, 12);
      path.cubicTo(88, 6, 120, 58, 50, 90);
    } else {
      path.addOval(bounds);
    }
    canvas.drawShadow(path, const Color(0x99000000), 4, true);
    final paint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.45, -.5),
        colors: [
          Colors.white,
          charm.color,
          Color.lerp(charm.color, Colors.black, .32)!,
        ],
        stops: const [0, .48, 1],
      ).createShader(bounds);
    canvas.drawPath(path, paint);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = Color.lerp(charm.color, Colors.white, .65)!,
    );
    if (shape == 'round' ||
        shape == 'diamond' ||
        shape == 'drop' ||
        shape == 'marquise') {
      canvas.save();
      canvas.clipPath(path);
      for (var i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        final facet = Path()
          ..moveTo(50, 50)
          ..lineTo(50 + 60 * math.cos(a), 50 + 60 * math.sin(a))
          ..lineTo(50 + 60 * math.cos(a + .5), 50 + 60 * math.sin(a + .5))
          ..close();
        canvas.drawPath(
          facet,
          Paint()
            ..color = (i.isEven ? Colors.white : const Color(0xFF7692AA))
                .withValues(alpha: .25),
        );
      }
      canvas.drawOval(
        const Rect.fromLTWH(33, 30, 34, 37),
        Paint()..color = Colors.white.withValues(alpha: .24),
      );
      canvas.restore();
    }
    if (shape == 'flower' || shape == 'bow') {
      canvas.drawCircle(
        const Offset(50, 50),
        9,
        Paint()
          ..shader = const RadialGradient(
            colors: [Colors.white, Color(0xFFD7AA52)],
          ).createShader(const Rect.fromLTWH(41, 41, 18, 18)),
      );
    }
    if (shape == 'shell') {
      for (var i = 0; i < 5; i++) {
        canvas.drawLine(
          const Offset(50, 86),
          Offset(21 + i * 14, 23),
          Paint()
            ..color = Colors.white.withValues(alpha: .55)
            ..strokeWidth = 2,
        );
      }
    }
    if (shape == 'butterfly') {
      canvas.drawLine(
        const Offset(50, 27),
        const Offset(50, 79),
        Paint()
          ..color = const Color(0xFFC3A363)
          ..strokeWidth = 4,
      );
    }
    canvas.drawOval(
      const Rect.fromLTWH(25, 19, 16, 7),
      Paint()..color = Colors.white.withValues(alpha: .72),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(CharmPainter oldDelegate) => oldDelegate.charm != charm;

  void _paintJewelry(Canvas canvas) {
    const crystal = Color(0xFFE4F3FF);
    void gem(
      String shape,
      double x,
      double y,
      double width,
      double height, {
      Color color = crystal,
      double angle = 0,
    }) {
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle);
      canvas.scale(width / 100, height / 100);
      canvas.translate(-50, -50);
      CharmPainter(
        NailCharm('', '', shape, color),
      ).paint(canvas, const Size(100, 100));
      canvas.restore();
    }

    void chain(Offset start, Offset bend, Offset end) {
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..quadraticBezierTo(bend.dx, bend.dy, end.dx, end.dy);
      final paint = Paint()..color = const Color(0xFF687889);
      final highlight = Paint()..color = const Color(0xFFE8F2FA);
      final metric = path.computeMetrics().first;
      for (var distance = 0.0; distance <= metric.length; distance += 3) {
        final point = metric.getTangentForOffset(distance)!.position;
        canvas.drawCircle(point, 1.55, paint);
        canvas.drawCircle(point - const Offset(.35, .45), .8, highlight);
      }
    }

    switch (charm.shape) {
      case 'wing':
        chain(const Offset(36, 42), const Offset(43, 94), const Offset(72, 42));
        chain(const Offset(72, 42), const Offset(79, 70), const Offset(82, 87));
        gem('round', 54, 25, 42, 42, color: charm.color);
        gem('marquise', 26, 37, 17, 35, angle: 1.1);
        gem('marquise', 39, 48, 16, 30, angle: .6);
        gem('round', 72, 43, 12, 12);
        gem('drop', 82, 89, 11, 19, angle: -.2);
      case 'double_chain':
        chain(const Offset(20, 35), const Offset(50, 65), const Offset(80, 35));
        chain(const Offset(23, 51), const Offset(52, 99), const Offset(78, 53));
        gem('diamond', 50, 25, 48, 39, color: charm.color, angle: .22);
        for (final x in [21.0, 79.0]) {
          gem('round', x, 31, 17, 17);
          gem('marquise', x, 49, 13, 23, angle: x < 50 ? -.4 : .4);
        }
        gem('drop', 29, 85, 12, 22, angle: -.35);
        gem('drop', 78, 74, 11, 21, angle: .25);
      case 'pendant':
        chain(const Offset(50, 19), const Offset(51, 48), const Offset(50, 79));
        chain(const Offset(23, 62), const Offset(50, 95), const Offset(77, 62));
        gem('diamond', 50, 18, 21, 21);
        for (final x in [27.0, 38.0, 62.0, 73.0]) {
          gem('round', x, 19 + (x - 50).abs() * .35, 11, 11);
        }
        gem('round', 50, 45, 13, 13);
        gem('round', 50, 57, 15, 15);
        gem('drop', 50, 76, 26, 34, color: charm.color);
        gem('diamond', 50, 93, 11, 12);
      case 'crown':
        chain(const Offset(22, 36), const Offset(50, 68), const Offset(78, 36));
        chain(const Offset(22, 38), const Offset(21, 70), const Offset(17, 91));
        chain(const Offset(78, 38), const Offset(80, 72), const Offset(85, 94));
        gem('diamond', 50, 18, 28, 25, color: charm.color);
        for (final x in [21.0, 34.0, 66.0, 79.0]) {
          gem('round', x, 22 + (x - 50).abs() * .24, 13, 13);
        }
        gem('marquise', 22, 52, 15, 31, angle: -.25);
        gem('marquise', 78, 52, 15, 31, angle: .25);
        gem('round', 81, 73, 11, 11);
    }
  }
}

class CharmLibrary extends StatefulWidget {
  final ValueChanged<NailCharm> onAdd;
  const CharmLibrary({super.key, required this.onAdd});
  @override
  State<CharmLibrary> createState() => _CharmLibraryState();
}

class _CharmLibraryState extends State<CharmLibrary> {
  String category = 'Đính đá';
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        spacing: 6,
        children: ['Đính đá', 'Cụm đá & dây', 'Ngọc trai', 'Hoa & nơ', 'Charm']
            .map(
              (c) => ChoiceChip(
                label: Text(c),
                selected: category == c,
                onSelected: (_) => setState(() => category = c),
              ),
            )
            .toList(),
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: nailCharms
            .where((c) => c.category == category)
            .map(
              (c) => SizedBox(
                width: 94,
                child: OutlinedButton(
                  onPressed: () => widget.onAdd(c),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(6),
                  ),
                  child: Column(
                    children: [
                      SizedBox(width: 44, height: 44, child: CharmArtwork(c)),
                      Text(
                        c.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    ],
  );
}
