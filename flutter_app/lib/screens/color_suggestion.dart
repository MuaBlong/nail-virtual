import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

import '../services/skin_color_service.dart';

class ColorSuggestionScreen extends StatefulWidget {
  final Uint8List imageBytes;

  const ColorSuggestionScreen({super.key, required this.imageBytes});

  @override
  State<ColorSuggestionScreen> createState() => _ColorSuggestionScreenState();
}

class _ColorSuggestionScreenState extends State<ColorSuggestionScreen> {
  img.Image? decodedImage;

  Color? sampledColor;
  Color? selectedColor;

  List<Color> suggestions = [];

  bool imageError = false;

  @override
  void initState() {
    super.initState();
    loadImage();
  }

  // 1. Giải mã ảnh
  Future<void> loadImage() async {
    try {
      final image = SkinColorService.decode(widget.imageBytes);

      if (!mounted) return;

      setState(() {
        decodedImage = image;
        imageError = image == null;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        imageError = true;
      });
    }
  }

  // 2. Chọn vùng da trên ảnh bàn tay
  void pickSkinColor(TapDownDetails details, Size viewSize) {
    final image = decodedImage;
    if (image == null) return;

    final color = SkinColorService.sampleFromTap(
      image: image,
      position: details.localPosition,
      viewSize: viewSize,
    );

    if (color == null) return;

    setState(() {
      sampledColor = color;

      suggestions = SkinColorService.suggestColors(color);

      selectedColor = suggestions.first;
    });
  }

  // 3. Hiển thị hình ảnh để chọn vùng da
  Widget handPreview() {
    if (imageError) {
      return const Center(child: Text('Không thể đọc hình ảnh'));
    }

    if (decodedImage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.clamp(0.0, 460.0).toDouble();

        final height = width * 1.25;

        return Center(
          child: SizedBox(
            width: width,
            height: height,
            child: GestureDetector(
              onTapDown: (details) {
                pickSkinColor(details, Size(width, height));
              },

              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),

                child: Image.memory(
                  widget.imageBytes,
                  width: width,
                  height: height,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // 4. Một ô màu Nail
  Widget colorItem(Color color) {
    final active = selectedColor == color;

    return GestureDetector(
      onTap: () {
        setState(() {
          selectedColor = color;
        });
      },

      child: Container(
        padding: const EdgeInsets.all(7),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),

          border: Border.all(
            color: active ? Colors.pink : Colors.grey.shade300,
            width: active ? 3 : 1,
          ),
        ),

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 55,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              SkinColorService.toHex(color),
              style: const TextStyle(fontSize: 11),
            ),

            if (active)
              const Icon(Icons.check_circle, color: Colors.pink, size: 18),
          ],
        ),
      ),
    );
  }

  // 5. Bảng gợi ý màu Nail
  Widget suggestionPanel() {
    if (sampledColor == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Chạm vào vùng da trên hình ảnh bàn tay '
            'để xem các màu Nail gợi ý.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MÀU DA THAM KHẢO',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: sampledColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),

            const SizedBox(width: 12),

            Text(
              SkinColorService.toHex(sampledColor!),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),

        const SizedBox(height: 20),

        const Text(
          'CÁC MÀU NAIL GỢI Ý',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            mainAxisExtent: 115,
          ),
          itemCount: suggestions.length,
          itemBuilder: (context, index) {
            return colorItem(suggestions[index]);
          },
        ),

        const SizedBox(height: 14),

        const Text(
          'Màu được gợi ý theo sắc độ trong ảnh. '
          'Ánh sáng và bộ lọc có thể ảnh hưởng '
          'đến độ chính xác.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  // 6. Giao diện chính
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),

      appBar: AppBar(
        title: const Text('Gợi ý màu Nail'),
        backgroundColor: Colors.pink.shade100,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                const Text(
                  'CHỌN VÙNG DA BÀN TAY',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Chạm vào một vùng da rõ nét, '
                  'không bị bóng đổ hoặc che khuất.',
                ),

                const SizedBox(height: 14),

                handPreview(),

                const SizedBox(height: 18),

                suggestionPanel(),

                const SizedBox(height: 20),

                // Trả màu đã chọn về trang thử Nail
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: selectedColor == null
                        ? null
                        : () {
                            Navigator.pop(context, selectedColor);
                          },
                    icon: const Icon(Icons.palette),
                    label: const Text('CHỌN MÀU NÀY ĐỂ THỬ'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
