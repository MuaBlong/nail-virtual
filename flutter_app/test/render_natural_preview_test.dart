import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/nail_set.dart';
import 'package:flutter_app/screens/try_nail.dart';
import 'package:flutter_app/services/nail_surface_service.dart';

void main() {
  testWidgets(
    'render public sample for visual material inspection',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final response =
          jsonDecode(File('build/visual_qa/detection.json').readAsStringSync())
              as Map<String, dynamic>;
      await tester.runAsync(() async {
        for (final nail in response['nails'] as List) {
          if (nail['surface'] is Map) {
            await NailSurfaceService.load(
              Map<String, dynamic>.from(nail['surface'] as Map),
            );
          }
        }
      });
      final hand = base64Decode(response['normalized_image'] as String);
      final detectorResponse = {...response}..remove('normalized_image');
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.runAsync(() async {
        await precacheImage(
          MemoryImage(hand),
          tester.element(find.byType(Scaffold)),
        );
      });
      await tester.pumpWidget(
        MaterialApp(
          home: TryNailScreen(
            nailSet: const NailSet(
              id: 'test_ruby',
              name: 'Ruby',
              palette: [Color(0xFF8C1738)],
            ),
            initialImage: hand,
            autoStart: true,
            detector: (_) async => detectorResponse,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final finish in ['Tự nhiên', 'Bóng', 'Lì']) {
        final chip = find.widgetWithText(ChoiceChip, finish);
        await tester.ensureVisible(chip);
        await tester.tap(chip);
        await tester.ensureVisible(find.byType(Image).first);
        await tester.pumpAndSettle();
        final target = find
            .ancestor(
              of: find.byType(Image).first,
              matching: find.byType(RepaintBoundary),
            )
            .first;
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(target);
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final name = {
            'Tự nhiên': 'natural',
            'Bóng': 'glossy',
            'Lì': 'matte',
          }[finish];
          File(
            'build/visual_qa/$name.png',
          ).writeAsBytesSync(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      expect(tester.takeException(), isNull);
    },
    skip: !const bool.fromEnvironment('VISUAL_QA'),
  );
}
