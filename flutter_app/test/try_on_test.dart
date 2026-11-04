import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_app/models/nail_set.dart';
import 'package:flutter_app/services/api.dart';
import 'package:flutter_app/screens/try_nail.dart';
import 'package:flutter_app/widgets/nail_fitted_artwork.dart';
import 'package:flutter_app/widgets/nail_catalog.dart';
import 'package:flutter_app/services/try_on_history.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_app/services/nail_surface_service.dart';

String surfaceUri(int value, {bool mask = false}) {
  final image = img.Image(width: 16, height: 24, numChannels: 4);
  for (var y = 0; y < 24; y++) {
    for (var x = 0; x < 16; x++) {
      image.setPixelRgba(x, y, value, value, value, mask && x == 0 ? 70 : 255);
    }
  }
  return 'data:image/png;base64,${base64Encode(img.encodePng(image))}';
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final count in [4, 6]) {
    testWidgets('automatic try-on accepts $count nails and defaults to oval', (
      tester,
    ) async {
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 200, height: 200)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TryNailScreen(
            nailSet: const NailSet(id: 'plain', name: 'Plain'),
            initialImage: bytes,
            autoStart: true,
            detector: (_) async => {
              'success': true,
              'image_width': 200,
              'image_height': 200,
              'nails': [
                for (var i = 0; i < count; i++)
                  {
                    'finger': i < 5 ? fingerOrder[i] : 'extra_6',
                    'design_index': i < 5 ? i : 4,
                    'x': .1 + i * .15,
                    'y': .3,
                    'width': .08,
                    'height': .15,
                    'rotation': 0,
                    'visible': true,
                    'polygon': [
                      [0, 0],
                      [1, 0],
                      [1, 1],
                      [0, 1],
                    ],
                  },
              ],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NailFittedArtwork), findsNWidgets(count));
      final oval = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Oval'),
      );
      expect(oval.selected, true);
      expect(
        tester
            .widgetList<NailFittedArtwork>(find.byType(NailFittedArtwork))
            .every((w) => w.finger >= 0 && w.finger < 5),
        true,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
  }
  testWidgets('material finish controls reflections and feathers coverage', (
    tester,
  ) async {
    final surface = <String, dynamic>{
      'lighting': surfaceUri(128),
      'highlights': surfaceUri(255),
      'coverage': surfaceUri(255, mask: true),
    };
    await tester.runAsync(() async {
      await NailSurfaceService.load(surface);
    });
    Future<(int, int)> render(NailFinish finish) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 42,
                height: 72,
                child: NailFittedArtwork(
                  set: const NailSet(
                    id: 'material',
                    name: 'Material',
                    palette: [Color(0xFF8C1738)],
                  ),
                  finger: 0,
                  polygon: const [
                    Offset(0, 0),
                    Offset(1, 0),
                    Offset(1, 1),
                    Offset(0, 1),
                  ],
                  surface: surface,
                  finish: finish,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      var center = 0, edgeAlpha = 0;
      await tester.runAsync(() async {
        final image =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final pixels = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        center = pixels!.getUint8((72 * image.width + 42) * 4);
        edgeAlpha = pixels.getUint8((72 * image.width + 1) * 4 + 3);
        final centerAlpha = pixels.getUint8((72 * image.width + 42) * 4 + 3);
        expect(edgeAlpha, lessThan(centerAlpha));
        image.dispose();
      });
      return (center, edgeAlpha);
    }

    final natural = await render(NailFinish.natural);
    final glossy = await render(NailFinish.glossy);
    final matte = await render(NailFinish.matte);
    expect(glossy.$1, greaterThan(natural.$1));
    expect(natural.$1, greaterThan(matte.$1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('fitted solid polish has no horizontal striping', (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: RepaintBoundary(
            key: key,
            child: const SizedBox(
              width: 42,
              height: 72,
              child: NailFittedArtwork(
                set: NailSet(
                  id: 'flat',
                  name: 'Flat',
                  palette: [Color(0xFF8C1738)],
                ),
                finger: 0,
                polygon: [
                  Offset(0, 0),
                  Offset(1, 0),
                  Offset(1, 1),
                  Offset(0, 1),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final reference = (20 * image.width + 40) * 4;
      for (var y = 10; y < 130; y++) {
        final index = (y * image.width + 40) * 4;
        for (var channel = 0; channel < 4; channel++) {
          expect(
            (bytes!.getUint8(index + channel) -
                    bytes.getUint8(reference + channel))
                .abs(),
            lessThanOrEqualTo(1),
          );
        }
      }
      image.dispose();
    });
  });
  test('history retains the five most recent results', () async {
    final bytes = Uint8List.fromList(
      img.encodePng(img.Image(width: 20, height: 30)),
    );
    for (var i = 0; i < 6; i++) {
      await TryOnHistory.add(
        bytes,
        bytes,
        NailSet(id: 'history_$i', name: 'Result $i'),
      );
    }
    final records = await TryOnHistory.load();
    expect(records.length, 5);
    expect(records.first.set.name, 'Result 5');
    expect(records.last.set.name, 'Result 1');
  });
  test('photo library replaces retired designs and supplies five fingers', () {
    expect(nailSets.length, 32);
    expect(nailSets.map((s) => s.id).toSet().length, 32);
    for (final set in nailSets.where((s) => s.images.isNotEmpty)) {
      expect(set.images.length, 5);
      expect(set.images.toSet().length, 5);
      expect(set.images.every((p) => p.contains('/prepared/')), isTrue);
    }
    expect(nailSets.any((s) => s.id == 'set_01' || s.id == 'ruby'), isFalse);
  });
  testWidgets('library supports unaccented search and favorites', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: NailCatalog(onSelect: (_) {})),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'dinh da');
    await tester.pumpAndSettle();
    expect(find.text('3 bộ mẫu'), findsOneWidget);
    await tester.tap(find.byTooltip('Thêm yêu thích').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Yêu thích'));
    await tester.pumpAndSettle();
    expect(find.text('1 bộ mẫu'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
  test(
    'catalog rejects missing finger while keeping built-in designs available',
    () async {
      final client = MockClient(
        (_) async => http.Response(
          jsonEncode([
            {
              'id': 1,
              'name': 'Broken',
              'designs': {'thumb': 'a.png'},
            },
            {
              'id': 2,
              'name': 'Remote',
              'designs': {for (final f in fingerOrder) f: '$f.png'},
            },
          ]),
          200,
        ),
      );
      final result = await NailCatalogApi.load(client: client);
      expect(result.sets.any((s) => s.name == 'Broken'), false);
      expect(result.sets.last.name, 'Remote');
      expect(result.sets.last.images.last, 'pinky.png');
      expect(result.sets.length, nailSets.length + 1);
      expect(result.message, isNotNull);
      client.close();
    },
  );
  test('catalog works offline', () async {
    final client = MockClient(
      (_) async => throw const FormatException('offline'),
    );
    final result = await NailCatalogApi.load(client: client);
    expect(result.sets.length, nailSets.length);
    expect(result.sets.length, greaterThanOrEqualTo(12));
    expect(result.message, isNotNull);
    client.close();
  });
  testWidgets(
    'automatic try-on clips only visible nails and draws selected design',
    (tester) async {
      final bytes = Uint8List.fromList(
        img.encodePng(img.Image(width: 100, height: 125)),
      );
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: TryNailScreen(
            nailSet: const NailSet(
              id: 'test_french',
              name: 'French',
              pattern: 'french',
            ),
            initialImage: bytes,
            autoStart: true,
            detector: (_) async {
              calls++;
              return {
                'success': true,
                'image_width': 100,
                'image_height': 125,
                'warning': 'Nhận diện 4/5 móng',
                'nails': [
                  for (var i = 0; i < 5; i++)
                    {
                      'finger': fingerOrder[i],
                      'x': .15 + .17 * i,
                      'y': .3,
                      'width': .08,
                      'height': .12,
                      'rotation': 0,
                      'visible': i != 4,
                      'polygon': [
                        [0, 0],
                        [1, 0],
                        [1, 1],
                        [0, 1],
                      ],
                    },
                ],
              };
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(find.byType(NailFittedArtwork), findsNWidgets(4));
      Offset cuticlePosition() {
        final target = find.byType(NailFittedArtwork).first;
        final box = tester.renderObject<RenderBox>(target);
        final canvas = tester.renderObject<RenderBox>(
          find
              .ancestor(of: target, matching: find.byType(RepaintBoundary))
              .first,
        );
        return canvas.globalToLocal(
          box.localToGlobal(Offset(box.size.width / 2, box.size.height)),
        );
      }

      final before = cuticlePosition();
      final longer = find.widgetWithText(OutlinedButton, 'Dài hơn');
      await tester.ensureVisible(longer);
      await tester.tap(longer);
      await tester.pumpAndSettle();
      expect(find.text('Chiều dài cả bộ: 110%'), findsOneWidget);
      expect((cuticlePosition() - before).distance, lessThan(.001));
      final square = find.widgetWithText(ChoiceChip, 'Vuông');
      await tester.ensureVisible(square);
      await tester.tap(square);
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<NailFittedArtwork>(find.byType(NailFittedArtwork))
            .every((w) => !w.useDetectedCoverage),
        true,
      );
      expect((cuticlePosition() - before).distance, lessThan(.001));
      expect(calls, 1);
      expect(
        find.byWidgetPredicate(
          (w) => w is ClipPath && w.clipper is NailBoundaryClipper,
        ),
        findsNWidgets(4),
      );
      expect(find.text('Nhận diện 4/5 móng'), findsWidgets);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
}
