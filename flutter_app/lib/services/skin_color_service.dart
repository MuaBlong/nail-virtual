import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class SkinColorService {
  // 1. Giải mã ảnh người dùng tải lên
  static img.Image? decode(Uint8List bytes) {
    return img.decodeImage(bytes);
  }

  // 2. Lấy màu trung bình quanh điểm được chọn
  static Color sampleColor(img.Image image, int x, int y) {
    int red = 0;
    int green = 0;
    int blue = 0;
    int count = 0;

    // Lấy vùng 7 x 7 pixel
    for (int dy = -3; dy <= 3; dy++) {
      for (int dx = -3; dx <= 3; dx++) {
        final px = x + dx;
        final py = y + dy;

        if (px < 0 || py < 0 || px >= image.width || py >= image.height) {
          continue;
        }

        final pixel = image.getPixel(px, py);

        red += pixel.r.round();
        green += pixel.g.round();
        blue += pixel.b.round();
        count++;
      }
    }

    if (count == 0) {
      return const Color(0xFFE7B49E);
    }

    return Color.fromARGB(
      255,
      (red / count).round().clamp(0, 255),
      (green / count).round().clamp(0, 255),
      (blue / count).round().clamp(0, 255),
    );
  }

  // 3. Xác định vị trí điểm chạm trên ảnh gốc
  // Ảnh đang hiển thị bằng BoxFit.contain
  static Color? sampleFromTap({
    required img.Image image,
    required Offset position,
    required Size viewSize,
  }) {
    final scale = math.min(
      viewSize.width / image.width,
      viewSize.height / image.height,
    );

    final displayedW = image.width * scale;
    final displayedH = image.height * scale;

    final left = (viewSize.width - displayedW) / 2;
    final top = (viewSize.height - displayedH) / 2;

    // Điểm chạm nằm ngoài phần ảnh thực tế
    if (position.dx < left ||
        position.dy < top ||
        position.dx >= left + displayedW ||
        position.dy >= top + displayedH) {
      return null;
    }

    final x = ((position.dx - left) / scale).floor().clamp(0, image.width - 1);

    final y = ((position.dy - top) / scale).floor().clamp(0, image.height - 1);

    return sampleColor(image, x, y);
  }

  // 4. Gợi ý màu theo độ sáng và sắc độ trong ảnh
  // Đây là quy tắc tham khảo, không phải AI
  static List<Color> suggestColors(Color skin) {
    final r = (skin.r * 255).round();
    final g = (skin.g * 255).round();
    final b = (skin.b * 255).round();

    final brightness = (r + g + b) / 3;
    final warm = (r - g) > (g - b);

    if (brightness < 115) {
      // Vùng màu tối trong ảnh
      return const [
        Color(0xFFF1D3BF),
        Color(0xFFE6A5AD),
        Color(0xFFCC6E62),
        Color(0xFF9D2447),
        Color(0xFFC7A6D9),
        Color(0xFFEFC6A7),
      ];
    }

    if (warm) {
      // Nhóm sắc ấm
      return const [
        Color(0xFFE8A68C),
        Color(0xFFEBC4A4),
        Color(0xFFD47B60),
        Color(0xFFAA4B42),
        Color(0xFFF2C8BD),
        Color(0xFF8B3048),
      ];
    }

    // Nhóm sắc trung tính / thiên lạnh
    return const [
      Color(0xFFE9B2C7),
      Color(0xFFD7B0D9),
      Color(0xFFB978A9),
      Color(0xFF963D68),
      Color(0xFFEEDCE2),
      Color(0xFF7D3657),
    ];
  }

  // 5. Đổi màu sang mã HEX để hiển thị
  static String toHex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;

    return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }
}
