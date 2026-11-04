import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:flutter_app/models/nail_set.dart';
import 'package:flutter_app/screens/try_nail.dart';
import 'package:flutter_app/widgets/nail_decorations.dart';

void main() {
  test('solid catalog and decoration movement keep valid values', () {
    expect(nailSets.where((s) => s.category == 'Màu trơn').length, 20);
    final original = nailSets.first;
    final remote = NailSet.fromJson({
      'id': original.id,
      'name': original.name,
      'images': [],
      'pattern': 'solid',
      'palette': [original.palette.first.toARGB32()],
    });
    expect(remote.palette.first, original.palette.first);
    final decoration = NailDecoration(nailCharms.first);
    decoration.move(const Offset(5, -5));
    expect(decoration.position, const Offset(.94, .06));
  });
  testWidgets(
    'add, resize, rotate and delete a decoration on a chosen finger',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 1500);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final hand = Uint8List.fromList(
        img.encodePng(img.Image(width: 200, height: 250)),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: TryNailScreen(
            nailSet: nailSets.first,
            initialImage: hand,
            autoStart: true,
            detector: (_) async => {
              'success': true,
              'image_width': 200,
              'image_height': 250,
              'nails': [
                for (var i = 0; i < 5; i++)
                  {
                    'finger': fingerOrder[i],
                    'visible': true,
                    'x': .2 + i * .13,
                    'y': .3,
                    'width': .08,
                    'height': .15,
                    'rotation': 0.0,
                    'polygon': [
                      [0.0, 0.0],
                      [1.0, 0.0],
                      [1.0, 1.0],
                      [0.0, 1.0],
                    ],
                  },
              ],
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final add = find.widgetWithText(OutlinedButton, 'Đá tròn pha lê');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pump();
      expect(find.text('Đang chỉnh: Đá tròn pha lê'), findsOneWidget);
      final resize = find.byType(Slider).at(1); // length slider is first
      await tester.ensureVisible(resize);
      final slider = tester.widget<Slider>(resize);
      slider.onChanged!(.55);
      await tester.pump();
      final rotate = find.byType(Slider).at(2);
      tester.widget<Slider>(rotate).onChanged!(.7);
      await tester.pump();
      final remove = find.widgetWithText(TextButton, 'Xóa phụ kiện đang chọn');
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pump();
      expect(find.text('Đang chỉnh: Đá tròn pha lê'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
