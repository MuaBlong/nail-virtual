import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/nail_set.dart';
import 'package:flutter_app/screens/try_nail.dart';
import 'package:flutter_app/services/nail_asset_service.dart';
import 'package:flutter_app/services/nail_surface_service.dart';
import 'package:flutter_app/widgets/nail_fitted_artwork.dart';

void main() {
  testWidgets(
    'all new photo sets render on the live AI fixture',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final response =
          jsonDecode(File('build/visual_qa/detection.json').readAsStringSync())
              as Map<String, dynamic>;
      expect(response['segmented_count'], 5);
      final hand = base64Decode(response['normalized_image'] as String);
      final detection = {...response}..remove('normalized_image');
      await tester.pumpWidget(const MaterialApp(home: Scaffold()));
      await tester.runAsync(() async {
        await precacheImage(
          MemoryImage(hand),
          tester.element(find.byType(Scaffold)),
        );
        for (final nail in response['nails'] as List) {
          await NailSurfaceService.load(
            Map<String, dynamic>.from(nail['surface'] as Map),
          );
        }
        for (final set in nailSets) {
          for (final path in set.images) {
            await NailAssetService.load(path);
            await NailAssetService.decoded(path);
          }
        }
      });
      Directory('build/visual_qa/catalog').createSync(recursive: true);
      for (final set in nailSets) {
        await tester.pumpWidget(
          MaterialApp(
            home: TryNailScreen(
              key: ValueKey(set.id),
              nailSet: set,
              initialImage: hand,
              autoStart: true,
              detector: (_) async => detection,
            ),
          ),
        );
        // Real image codecs finish outside the test's simulated clock.
        for (var frame = 0; frame < 12; frame++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump(const Duration(milliseconds: 500));
        }
        final fitted = tester
            .widgetList<NailFittedArtwork>(find.byType(NailFittedArtwork))
            .toList();
        expect(fitted.length, 5, reason: set.id);
        expect(fitted.map((n) => n.finger).toSet(), {0, 1, 2, 3, 4});
        expect(fitted.every((n) => n.set.id == set.id), isTrue);
        expect(tester.takeException(), isNull, reason: set.id);
        if (set.id == 'plain_jelly_pink') {
          final add = find.widgetWithText(OutlinedButton, 'Đá tròn pha lê');
          await tester.ensureVisible(add);
          await tester.tap(add);
          await tester.pump();
          expect(find.text('Đang chỉnh: Đá tròn pha lê'), findsOneWidget);
          // Finish editing by choosing a different finger before capturing.
          final picker = find.byWidgetPredicate(
            (w) => w is DropdownButton<int>,
          );
          final dropdown = tester.widget<DropdownButton<int>>(picker);
          dropdown.onChanged!(dropdown.items![1].value);
          await tester.pump();
          await tester.ensureVisible(find.byType(Image).first);
          await tester.pump();
        }
        final target = find
            .ancestor(
              of: find.byType(Image).first,
              matching: find.byType(RepaintBoundary),
            )
            .first;
        await tester.runAsync(() async {
          final image = await tester
              .renderObject<RenderRepaintBoundary>(target)
              .toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          File(
            'build/visual_qa/catalog/${set.id}.png',
          ).writeAsBytesSync(png!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
    skip: !const bool.fromEnvironment('VISUAL_QA'),
  );
}
