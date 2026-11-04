import 'dart:math' as math;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import '../services/auto_nail_api.dart';
import '../services/nail_asset_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import 'color_suggestion.dart';
import '../models/nail_set.dart';
import '../models/nail_geometry.dart';
import '../models/nail_shape.dart';
import '../widgets/nail_fitted_artwork.dart';
import '../widgets/nail_catalog.dart';
import '../widgets/nail_decorations.dart';
import '../services/try_on_history.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';
import 'package:share_plus/share_plus.dart';
import '../services/nail_surface_service.dart';

// THÔNG TIN CỦA MỖI MẪU NAIL TRÊN ẢNH
class NailLayer {
  final int id;
  final List<NailDecoration> decorations = [];
  int design;
  String? imagePath;
  Color? solidColor;
  final List<Offset>? polygon;
  final List<double>? shading;
  final Map<String, dynamic>? surface;
  NailSet? artworkSet;

  // Vị trí theo tỷ lệ 0 - 1
  Offset position;

  double widthScale;
  double heightScale;
  double rotation;

  NailLayer({
    required this.id,
    required this.design,
    required this.position,
    this.imagePath,
    this.solidColor,
    this.polygon,
    this.shading,
    this.surface,
    this.artworkSet,
    this.widthScale = 0.7,
    this.heightScale = 0.7,
    this.rotation = 0,
  });
}

// MÀN HÌNH THỬ NAIL
class NailBoundaryClipper extends CustomClipper<Path> {
  final List<Offset> points;
  NailBoundaryClipper(this.points);

  @override
  Path getClip(Size size) {
    final path = Path();
    if (points.length < 3) {
      return path..addRect(Offset.zero & size);
    }
    path.moveTo(points.first.dx * size.width, points.first.dy * size.height);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx * size.width, point.dy * size.height);
    }
    return path..close();
  }

  @override
  bool shouldReclip(NailBoundaryClipper oldClipper) =>
      oldClipper.points != points;
}

class TryNailScreen extends StatefulWidget {
  // Nhận bộ Nail từ màn hình nail_sets.dart
  // Nếu null thì người dùng thử từng mẫu riêng lẻ
  final NailSet? nailSet;
  final Uint8List? initialImage;
  final bool autoStart;
  final Future<Map<String, dynamic>> Function(Uint8List)? detector;

  const TryNailScreen({
    super.key,
    this.nailSet,
    this.initialImage,
    this.autoStart = false,
    this.detector,
  });

  @override
  State<TryNailScreen> createState() => _TryNailScreenState();
}

class _TryNailScreenState extends State<TryNailScreen> {
  NailSet? activeSet;
  final handView = TransformationController();
  static const maxHandZoom = 4.0;

  @override
  void dispose() {
    handView.dispose();
    super.dispose();
  }

  void zoomHand(double factor) {
    final zoom = (handView.value.getMaxScaleOnAxis() * factor)
        .clamp(1.0, maxHandZoom)
        .toDouble();
    if (zoom == 1) {
      handView.value = Matrix4.identity();
      return;
    }
    final center = Offset(canvasW / 2, canvasH / 2);
    final imagePoint = handView.toScene(center);
    final x = (center.dx - imagePoint.dx * zoom)
        .clamp(canvasW * (1 - zoom), 0.0)
        .toDouble();
    final y = (center.dy - imagePoint.dy * zoom)
        .clamp(canvasH * (1 - zoom), 0.0)
        .toDouble();
    handView.value = Matrix4.diagonal3Values(zoom, zoom, zoom)
      ..setTranslationRaw(x, y, 0);
  }

  @override
  void initState() {
    super.initState();
    activeSet = widget.nailSet;
    handImage = widget.initialImage;
    if (widget.autoStart && handImage != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) autoPlaceNails();
      });
    }
  }

  Future<void> chooseSet() async {
    if (analyzing || saving) return;
    final set = await showModalBottomSheet<NailSet>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheetContext).height * .85,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Đổi bộ nail',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                NailCatalog(
                  selectedId: activeSet?.id,
                  onSelect: (value) => Navigator.pop(sheetContext, value),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (set == null || !mounted) return;
    try {
      await Future.wait(set.images.map(NailAssetService.load));
      if (!mounted) return;
      setState(() {
        activeSet = set;
        for (var i = 0; i < nails.length; i++) {
          nails[i]
            ..artworkSet = set
            ..solidColor = null;
        }
      });
      if (nails.isEmpty && handImage != null) await autoPlaceNails();
    } catch (_) {
      notice('Không tải được bộ nail này. Hãy chọn bộ khác.');
    }
  }

  final GlobalKey captureKey = GlobalKey();

  Uint8List? handImage;

  final List<NailLayer> nails = [];

  NailLayer? selected;
  NailDecoration? selectedDecoration;
  Widget decorationPanel() {
    final target = selected != null && nails.contains(selected)
        ? selected!
        : nails.first;
    final item = target.decorations.contains(selectedDecoration)
        ? selectedDecoration
        : null;
    const fingerNames = [
      'Ngón cái',
      'Ngón trỏ',
      'Ngón giữa',
      'Áp út',
      'Ngón út',
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tự trang trí móng',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Chọn ngón rồi chọn phụ kiện. Kéo phụ kiện trên móng để đặt vị trí.',
            ),
            DropdownButton<int>(
              value: target.id,
              isExpanded: true,
              items: nails
                  .map(
                    (n) => DropdownMenuItem(
                      value: n.id,
                      child: Text(
                        '${fingerNames[n.design % 5]} · ${n.decorations.length} phụ kiện',
                      ),
                    ),
                  )
                  .toList(),
              onChanged: saving || analyzing
                  ? null
                  : (id) => setState(() {
                      selected = nails.firstWhere((n) => n.id == id);
                      selectedDecoration = null;
                    }),
            ),
            if (!saving && !analyzing)
              CharmLibrary(
                onAdd: (charm) => setState(() {
                  if (target.decorations.length >= 30) {
                    notice('Mỗi móng tối đa 30 phụ kiện.');
                    return;
                  }
                  final decoration = NailDecoration(
                    charm,
                    scale: charm.category == 'Cụm đá & dây' ? .72 : .32,
                  );
                  target.decorations.add(decoration);
                  selected = target;
                  selectedDecoration = decoration;
                }),
              ),
            if (item != null) ...[
              Text('Đang chỉnh: ${item.charm.name}'),
              const Text('Kích thước phụ kiện'),
              Slider(
                value: item.scale,
                min: .12,
                max: .85,
                onChanged: saving || analyzing
                    ? null
                    : (value) => setState(() => item.scale = value),
              ),
              const Text('Xoay phụ kiện'),
              Slider(
                value: item.rotation,
                min: -math.pi,
                max: math.pi,
                onChanged: saving || analyzing
                    ? null
                    : (value) => setState(() => item.rotation = value),
              ),
              TextButton.icon(
                onPressed: saving || analyzing
                    ? null
                    : () => setState(() {
                        target.decorations.remove(item);
                        selectedDecoration = null;
                      }),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Xóa phụ kiện đang chọn'),
              ),
            ],
            if (target.decorations.isNotEmpty)
              Wrap(
                spacing: 4,
                children: [
                  for (final decoration in target.decorations)
                    ChoiceChip(
                      label: Text(
                        '${decoration.charm.name} ${target.decorations.indexOf(decoration) + 1}',
                      ),
                      selected: identical(item, decoration),
                      onSelected: saving || analyzing
                          ? null
                          : (_) => setState(() {
                              selected = target;
                              selectedDecoration = decoration;
                            }),
                    ),
                ],
              ),
            TextButton(
              onPressed: saving || analyzing || target.decorations.isEmpty
                  ? null
                  : () => setState(() {
                      target.decorations.clear();
                      selectedDecoration = null;
                    }),
              child: const Text('Xóa trang trí trên ngón này'),
            ),
          ],
        ),
      ),
    );
  }

  int selectedDesign = 0;
  int nextId = 1;

  bool saving = false;
  bool showOriginal = false;
  NailFinish finish = NailFinish.natural;
  NailShape nailShape = NailShape.oval;
  double lengthFactor = 1;

  void changeLength(double value) {
    if (saving || analyzing || nails.isEmpty) return;
    final next = value.clamp(.60, 2.0);
    final ratio = next / lengthFactor;
    setState(() {
      for (final nail in nails) {
        updateGeometry(nail, height: nail.heightScale * ratio);
      }
      lengthFactor = next;
      showOriginal = false;
    });
  }

  Widget shapeAndLengthControls() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dáng móng',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final shape in NailShape.values)
                ChoiceChip(
                  label: Text(shape.label),
                  avatar: Icon(switch (shape) {
                    NailShape.natural => Icons.auto_fix_high,
                    NailShape.square => Icons.crop_square,
                    NailShape.coffin => Icons.filter_alt_outlined,
                    NailShape.oval => Icons.egg_outlined,
                    NailShape.round => Icons.circle_outlined,
                    NailShape.pointed => Icons.change_history_outlined,
                  }, size: 18),
                  selected: nailShape == shape,
                  onSelected: saving || analyzing
                      ? null
                      : (_) => setState(() {
                          nailShape = shape;
                          selected = null;
                        }),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Chiều dài cả bộ: ${(lengthFactor * 100).round()}%',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Slider(
            key: const ValueKey('set-length-slider'),
            min: .60,
            max: 2.0,
            value: lengthFactor,
            label: '${(lengthFactor * 100).round()}%',
            onChanged: saving || analyzing ? null : changeLength,
          ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: saving || analyzing || lengthFactor <= .60
                    ? null
                    : () => changeLength(lengthFactor - .10),
                icon: const Icon(Icons.remove),
                label: const Text('Ngắn hơn'),
              ),
              OutlinedButton.icon(
                onPressed: saving || analyzing || lengthFactor >= 2
                    ? null
                    : () => changeLength(lengthFactor + .10),
                icon: const Icon(Icons.add),
                label: const Text('Dài hơn'),
              ),
              TextButton(
                onPressed: saving || analyzing ? null : () => changeLength(1),
                child: const Text('Về chiều dài ban đầu'),
              ),
            ],
          ),
          const Text(
            'Áp dụng cho tất cả móng đã ghép. Chân móng giữ cố định.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      ),
    ),
  );
  String? detectionSummary;
  bool analyzing = false; // AI đang nhận diện ảnh

  static const double nailW = 42;
  static const double nailH = 72;

  double canvasW = 360;
  double canvasH = 450;

  final List<String> names = const [
    'Hồng',
    'Đỏ',
    'French',
    'Hoa',
    'Tím',
    'Xanh',
  ];

  final List<Color> colors = const [
    Color(0xFFF48FB1),
    Color(0xFFC62828),
    Color(0xFFF2D4C6),
    Color(0xFFFFB6C1),
    Color(0xFF9575CD),
    Color(0xFF4DB6AC),
  ];

  // THÔNG BÁO
  void notice(String text) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // 1. TẢI ẢNH BÀN TAY
  Future<void> pickImage({ImageSource source = ImageSource.gallery}) async {
    if (analyzing || saving) return;
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 90,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      if (!mounted) return;

      setState(() {
        handImage = bytes;
        handView.value = Matrix4.identity();
        nails.clear();
        selected = null;
        detectionSummary = null;
      });

      // Không đặt 5 móng ở tọa độ cố định ngay sau khi tải ảnh.
      // Người dùng bấm TẠO ẢNH TỰ ĐỘNG để AI chọn vị trí thật.
      notice('Đã tải ảnh! Nhấn TẠO ẢNH TỰ ĐỘNG để thử Nail.');
    } catch (e) {
      notice('Không thể tải ảnh: $e');
    }
  }

  // Ghép vào các vùng móng nhìn thấy, kể cả móng bổ sung ngoài năm nhãn chuẩn.
  Future<void> autoPlaceNails() async {
    final bytes = handImage;
    if (bytes == null) {
      notice('Hãy tải ảnh bàn tay trước!');
      return;
    }
    if (analyzing || saving) return;

    final set = activeSet;
    if (set != null && set.images.isNotEmpty && set.images.length != 5) {
      notice('Bộ Nail phải có đúng 5 ảnh PNG.');
      return;
    }

    setState(() => analyzing = true);
    try {
      final result = await (widget.detector ?? AutoNailApi.detectHand)(bytes);
      if (!mounted || !identical(handImage, bytes)) return;

      if (result['success'] != true) {
        notice(
          result['message']?.toString() ??
              'AI chưa tìm thấy bàn tay. Hãy chọn ảnh nhìn rõ các móng.',
        );
        return;
      }

      final rawNails = result['nails'];
      if (rawNails is! List || rawNails.isEmpty || rawNails.length > 15) {
        throw const FormatException('Danh sách vùng móng không hợp lệ.');
      }

      final imageW = (result['image_width'] as num).toDouble();
      final imageH = (result['image_height'] as num).toDouble();
      if (imageW <= 0 || imageH <= 0 || canvasW <= 0 || canvasH <= 0) {
        throw const FormatException('Kích thước ảnh không hợp lệ.');
      }

      // Image.memory hiện đang dùng BoxFit.contain. Phải tính cả
      // khoảng trống hai bên / trên dưới để Nail nằm đúng vị trí.
      final fitScale = math.min(canvasW / imageW, canvasH / imageH);
      final shownW = imageW * fitScale;
      final shownH = imageH * fitScale;
      final padX = (canvasW - shownW) / 2;
      final padY = (canvasH - shownH) / 2;

      // Tạo danh sách mới trước khi setState, tránh xóa mẫu cũ nếu lỗi.
      final newNails = <NailLayer>[];
      const fingerOrder = ['thumb', 'index', 'middle', 'ring', 'pinky'];
      for (var i = 0; i < rawNails.length; i++) {
        final item = Map<String, dynamic>.from(rawNails[i] as Map);
        if (item['visible'] == false) continue;
        final canonicalIndex = fingerOrder.indexOf(item['finger'].toString());
        final providedIndex = item['design_index'];
        final designIndex =
            providedIndex is int && providedIndex >= 0 && providedIndex < 5
            ? providedIndex
            : canonicalIndex >= 0
            ? canonicalIndex
            : i % 5;

        final normalizedX = (item['x'] as num).toDouble();
        final normalizedY = (item['y'] as num).toDouble();
        final width = (item['width'] as num).toDouble() * imageW * fitScale;
        final height = (item['height'] as num).toDouble() * imageH * fitScale;
        final angle = (item['rotation'] as num).toDouble();

        final centerX = padX + normalizedX * shownW;
        final centerY = padY + normalizedY * shownH;

        // NailLayer.position lưu GÓC TRÊN TRÁI của khung 42 x 72.
        // Transform.scale / rotate xoay theo TÂM khung.
        final left = centerX - nailW / 2;
        final top = centerY - nailH / 2;

        // Thanh trượt trong code cũ sử dụng góc [-pi, pi].
        final normalizedAngle = math.atan2(math.sin(angle), math.cos(angle));
        final design = set == null ? selectedDesign : designIndex;

        newNails.add(
          NailLayer(
            id: nextId++,
            design: design,
            position: Offset(left / canvasW, top / canvasH),
            artworkSet: set,
            surface: item['surface'] is Map
                ? Map<String, dynamic>.from(item['surface'] as Map)
                : null,
            shading: (item['shading'] as List?)
                ?.map((v) => (v as num).toDouble())
                .toList(),
            imagePath: set != null && set.images.isNotEmpty
                ? set.images[designIndex]
                : (set == null && design == 0 ? 'assets/nails/hong.png' : null),
            widthScale: (width / nailW).clamp(0.05, 20.0).toDouble(),
            heightScale: (height / nailH).clamp(0.05, 20.0).toDouble(),
            rotation: normalizedAngle,
            polygon: item['polygon'] is List
                ? (item['polygon'] as List)
                      .map(
                        (p) => Offset(
                          (p[0] as num).toDouble(),
                          (p[1] as num).toDouble(),
                        ),
                      )
                      .toList()
                : null,
          ),
        );
      }

      if (newNails.isEmpty) {
        notice(
          'Chưa thấy vùng móng đủ rõ để ghép. Hãy chọn ảnh khác hoặc chỉnh tay.',
        );
        return;
      }

      // Display the exact EXIF-normalized image used by Python.
      final normalizedImage = result['normalized_image'] is String
          ? base64Decode(result['normalized_image'] as String)
          : bytes;
      await Future.wait(
        newNails
            .where((n) => n.imagePath != null)
            .map((n) => NailAssetService.load(n.imagePath!)),
      );
      for (final nail in newNails) {
        updateGeometry(nail, height: nail.heightScale * lengthFactor);
      }
      await Future.wait(
        newNails
            .where((n) => n.surface != null)
            .map((n) => NailSurfaceService.load(n.surface!)),
      );
      if (!mounted || !identical(handImage, bytes)) return;
      setState(() {
        handImage = normalizedImage;
        showOriginal = false;
        nailShape = NailShape.oval;
        detectionSummary = result['warning']?.toString();
        nails
          ..clear()
          ..addAll(newNails);
        selected = null; // Không hiện viền vàng khi vừa tạo ảnh.
      });
      notice(
        result['warning']?.toString() ??
            'Đã ghép ${newNails.length} móng ở dáng oval. Hãy kiểm tra kết quả.',
      );
    } catch (error) {
      if (mounted) notice('Không thể tự gắn Nail: $error');
    } finally {
      if (mounted) setState(() => analyzing = false);
    }
  }

  // 2. THÊM MỘT MẪU NAIL ĐƠN
  void addNail() {
    if (handImage == null) {
      notice('Vui lòng tải ảnh bàn tay trước!');
      return;
    }

    setState(() {
      final nail = NailLayer(
        id: nextId++,
        design: selectedDesign,
        position: const Offset(0.42, 0.30),
        imagePath: (activeSet ?? nailSets.first).images.isEmpty
            ? null
            : (activeSet ?? nailSets.first).images.first,
        artworkSet: activeSet ?? nailSets.first,
      );

      nails.add(nail);
      selected = nail;
    });
  }

  Widget coloredNail(Color color) {
    return Container(
      width: nailW,
      height: nailH,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(21),
          topRight: Radius.circular(21),
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        border: Border.all(color: Colors.white54, width: 1),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
      ),
    );
  }

  // 3. THÊM BỘ 5 MẪU NAIL THẬT
  void addNailSet() {
    final set = activeSet;

    if (handImage == null || set == null) return;

    if (set.images.isNotEmpty && set.images.length != 5) {
      notice('Bộ Nail phải có đúng 5 ảnh!');
      return;
    }

    // Vị trí ban đầu, người dùng tự kéo chỉnh lại
    const positions = [
      Offset(0.10, 0.43), // Ngón cái
      Offset(0.28, 0.34), // Ngón trỏ
      Offset(0.45, 0.26), // Ngón giữa
      Offset(0.62, 0.36), // Ngón áp út
      Offset(0.79, 0.53), // Ngón út
    ];

    setState(() {
      nails.clear();

      for (int i = 0; i < 5; i++) {
        nails.add(
          NailLayer(
            id: nextId++,
            design: i,
            position: positions[i],
            imagePath: set.images.isEmpty ? null : set.images[i],
            artworkSet: set,
            widthScale: 0.65,
            heightScale: 0.65,
          ),
        );
      }

      selected = nails.first;
    });

    notice('Đã áp dụng bộ ${set.name}!');
  }

  // 4. THỬ 5 MẪU MINH HỌA
  void addFiveSamples() {
    activeSet ??= nailSets.first;
    addNailSet();
  }

  // 5. THAY MẪU NAIL ĐANG CHỌN
  void selectDesign(int index) {
    setState(() {
      selectedDesign = index;

      if (selected != null) {
        selected!.design = index;
        selected!.imagePath = index == 0 ? 'assets/nails/hong.png' : null;
        // Chọn mẫu PNG khác thì bỏ lớp màu trơn cũ.
        selected!.solidColor = null;
        selected!.artworkSet = null;
      }
    });
  }

  // 6. XÓA MẪU ĐANG CHỌN
  void deleteNail() {
    if (selected == null) return;

    setState(() {
      nails.remove(selected);
      selected = null;
    });
  }

  // 7. XÓA TOÀN BỘ MẪU
  void clearAll() {
    setState(() {
      nails.clear();
      selected = null;
    });
  }

  // 8. HÌNH NAIL MINH HỌA
  Widget sampleNail(int index) {
    final safeIndex = index % colors.length;

    return Container(
      width: nailW,
      height: nailH,
      decoration: BoxDecoration(
        color: colors[safeIndex],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(21),
          topRight: Radius.circular(21),
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (safeIndex == 2)
            Positioned(
              top: 0,
              child: Container(
                width: 34,
                height: 15,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(18),
                    bottom: Radius.circular(5),
                  ),
                ),
              ),
            ),
          if (safeIndex == 3)
            const Icon(Icons.local_florist, color: Colors.white),
          if (safeIndex == 4)
            const Icon(Icons.auto_awesome, color: Colors.white),
          if (safeIndex == 5) const Icon(Icons.star, color: Colors.white),
        ],
      ),
    );
  }

  // 9. HIỂN THỊ ẢNH NAIL PNG
  Widget nailDesign(int index, {String? path}) {
    final asset = path ?? (index == 0 ? 'assets/nails/hong.png' : null);

    if (asset == null) {
      return sampleNail(index);
    }

    return FutureBuilder<Uint8List>(
      future: NailAssetService.load(asset),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox(
            width: nailW,
            height: nailH,
            child: Icon(Icons.broken_image, color: Colors.red),
          );
        }
        if (!snapshot.hasData) {
          return const SizedBox(width: nailW, height: nailH);
        }
        return Image.memory(
          snapshot.data!,
          width: nailW,
          height: nailH,
          fit: BoxFit.fill,
          gaplessPlayback: true,
        );
      },
    );
  }

  // 10. KÉO THẢ MẪU TRỰC TIẾP TRÊN ẢNH
  Widget movableNail(NailLayer nail) {
    final outline = nailShapePolygon(nailShape, nail.polygon);
    final isSelected = selected?.id == nail.id;

    return Positioned(
      key: ValueKey(nail.id),
      left: nail.position.dx * canvasW,
      top: nail.position.dy * canvasH,

      child: GestureDetector(
        behavior: HitTestBehavior.opaque,

        // Nhấp chuột để chọn mẫu
        onTap: () {
          setState(() {
            selected = nail;
          });
        },

        // Bắt đầu kéo
        onPanStart: (_) {
          setState(() {
            selected = nail;
          });
        },

        // Kéo mẫu theo di chuyển của chuột
        onPanUpdate: (details) {
          setState(() {
            final newX = nail.position.dx + details.delta.dx / canvasW;

            final newY = nail.position.dy + details.delta.dy / canvasH;

            nail.position = Offset(
              newX.clamp(0.0, 1 - nailW / canvasW).toDouble(),
              newY.clamp(0.0, 1 - nailH / canvasH).toDouble(),
            );
          });
        },

        child: SizedBox(
          width: nailW,
          height: nailH,

          child: Transform.rotate(
            angle: nail.rotation,

            child: Transform.scale(
              scaleX: nail.widthScale,
              scaleY: nail.heightScale,

              child: Stack(
                children: [
                  // Có màu được chọn thì hiện Nail màu trơn;
                  // nếu không, tiếp tục hiển thị mẫu PNG như trước.
                  ClipPath(
                    clipper: outline == null
                        ? null
                        : NailBoundaryClipper(outline),
                    child: nail.solidColor != null
                        ? SizedBox(
                            width: nailW,
                            height: nailH,
                            child: NailFittedArtwork(
                              set: NailSet(
                                id: 'custom_color',
                                name: 'Màu chọn',
                                palette: [nail.solidColor!],
                              ),
                              finger: nail.design % 5,
                              polygon: outline,
                              useDetectedCoverage:
                                  nailShape == NailShape.natural,
                              shading: nail.shading,
                              surface: nail.surface,
                              finish: finish,
                            ),
                          )
                        : nail.artworkSet != null
                        ? SizedBox(
                            width: nailW,
                            height: nailH,
                            child: NailFittedArtwork(
                              set: nail.artworkSet!,
                              finger: nail.design % 5,
                              polygon: outline,
                              useDetectedCoverage:
                                  nailShape == NailShape.natural,
                              shading: nail.shading,
                              surface: nail.surface,
                              finish: finish,
                            ),
                          )
                        : nailDesign(nail.design, path: nail.imagePath),
                  ),

                  if (nail.decorations.isNotEmpty)
                    Positioned.fill(
                      child: ClipPath(
                        clipper: outline == null
                            ? null
                            : NailBoundaryClipper(outline),
                        child: Stack(
                          children: [
                            for (final decoration in nail.decorations)
                              Positioned(
                                left:
                                    decoration.position.dx * nailW -
                                    decoration.scale * nailW / 2,
                                top:
                                    decoration.position.dy * nailH -
                                    decoration.scale * nailW / 2,
                                width: decoration.scale * nailW,
                                height: decoration.scale * nailW,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: saving || analyzing
                                      ? null
                                      : () => setState(() {
                                          selected = nail;
                                          selectedDecoration = decoration;
                                        }),
                                  onPanUpdate: saving || analyzing
                                      ? null
                                      : (details) => setState(() {
                                          selected = nail;
                                          selectedDecoration = decoration;
                                          decoration.move(
                                            Offset(
                                              details.delta.dx / nailW,
                                              details.delta.dy / nailH,
                                            ),
                                          );
                                        }),
                                  child: Transform.rotate(
                                    angle: decoration.rotation,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        border:
                                            !saving &&
                                                identical(
                                                  selectedDecoration,
                                                  decoration,
                                                )
                                            ? Border.all(
                                                color: Colors.amber,
                                                width: .7,
                                              )
                                            : null,
                                      ),
                                      child: CharmArtwork(decoration.charm),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                  // Viền vàng chỉ hiện khi chỉnh sửa
                  if (isSelected && !saving)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.amber, width: 2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 11. PHÓNG TO / THU NHỎ MẪU ĐANG CHỌN
  void resizeSelected(double factor) {
    final nail = selected;
    if (nail == null) return;

    setState(() {
      updateGeometry(
        nail,
        height: (nail.heightScale * factor).clamp(0.05, 20.0),
      );
      nail.widthScale = (nail.widthScale * factor).clamp(0.05, 20.0).toDouble();
    });
  }

  void updateGeometry(NailLayer nail, {num? height, double? rotation}) {
    final nextHeight = height?.toDouble() ?? nail.heightScale;
    final nextRotation = rotation ?? nail.rotation;
    nail.position = anchorNailBase(
      position: nail.position,
      canvas: Size(canvasW, canvasH),
      oldHeight: nailH * nail.heightScale,
      newHeight: nailH * nextHeight,
      oldRotation: nail.rotation,
      newRotation: nextRotation,
    );
    nail.heightScale = nextHeight;
    nail.rotation = nextRotation;
  }

  // 12. XOAY MẪU ĐANG CHỌN
  void rotateSelected(double degrees) {
    final nail = selected;
    if (nail == null) return;

    setState(() {
      updateGeometry(
        nail,
        rotation: (nail.rotation + degrees * math.pi / 180)
            .clamp(-math.pi, math.pi)
            .toDouble(),
      );
    });
  }

  // 13. TẠO NÚT CÔNG CỤ
  Widget toolButton(IconData icon, String tooltip, VoidCallback action) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,

        child: IconButton(
          tooltip: tooltip,
          onPressed: action,
          icon: Icon(icon, color: Colors.pink.shade700),
        ),
      ),
    );
  }

  // 14. VÙNG ẢNH BÀN TAY
  Widget handCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        canvasW = math.min(460.0, constraints.maxWidth);
        canvasH = canvasW * 1.25;

        return Center(
          child: SizedBox(
            width: canvasW,
            height: canvasH,

            child: Stack(
              children: [
                // Chỉ vùng ảnh này được lưu thành PNG
                ValueListenableBuilder<Matrix4>(
                  valueListenable: handView,
                  builder: (context, transform, child) => InteractiveViewer(
                    transformationController: handView,
                    minScale: 1,
                    maxScale: maxHandZoom,
                    panEnabled: transform.getMaxScaleOnAxis() > 1,
                    scaleEnabled: handImage != null && !saving,
                    child: child!,
                  ),
                  child: RepaintBoundary(
                    key: captureKey,

                    child: Container(
                      width: canvasW,
                      height: canvasH,
                      clipBehavior: Clip.hardEdge,

                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),

                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: handImage == null
                                ? const Center(
                                    child: Text('Hãy tải ảnh bàn tay lên'),
                                  )
                                : Image.memory(
                                    handImage!,
                                    fit: BoxFit.contain,
                                    gaplessPlayback: true,
                                  ),
                          ),

                          // Hiển thị các mẫu Nail lên ảnh
                          if (!showOriginal || saving)
                            ...nails.map(movableNail),
                        ],
                      ),
                    ),
                  ),
                ),

                // Công cụ điều chỉnh ngay trên ảnh
                if (selected != null)
                  Positioned(
                    right: 7,
                    top: 7,

                    child: Column(
                      children: [
                        toolButton(
                          Icons.add,
                          'Phóng to',
                          () => resizeSelected(1.1),
                        ),
                        toolButton(
                          Icons.remove,
                          'Thu nhỏ',
                          () => resizeSelected(0.9),
                        ),
                        toolButton(
                          Icons.rotate_left,
                          'Xoay trái',
                          () => rotateSelected(-5),
                        ),
                        toolButton(
                          Icons.rotate_right,
                          'Xoay phải',
                          () => rotateSelected(5),
                        ),
                        toolButton(Icons.delete_outline, 'Xóa mẫu', deleteNail),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 15. BẢNG CHỈNH KÍCH THƯỚC VÀ GÓC XOAY
  Widget adjustPanel() {
    final nail = selected;

    if (nail == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Text('Nhấn vào một mẫu Nail trên ảnh để điều chỉnh.'),
        ),
      );
    }

    return Card(
      color: Colors.white,

      child: Padding(
        padding: const EdgeInsets.all(12),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ĐIỀU CHỈNH MẪU NAIL',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              activeSet == null
                  ? 'Mẫu đang chọn: ${names[nail.design]}'
                  : 'Bộ Nail: ${activeSet!.name}',
            ),

            const SizedBox(height: 8),

            Text(
              'Chiều rộng: '
              '${nail.widthScale.toStringAsFixed(2)}',
            ),

            Slider(
              min: math.min(0.2, nail.widthScale),
              max: math.max(3.0, nail.widthScale),
              value: nail.widthScale,
              onChanged: (value) {
                setState(() {
                  nail.widthScale = value;
                });
              },
            ),

            Text(
              'Chiều dài (giữ chân móng): '
              '${nail.heightScale.toStringAsFixed(2)}',
            ),

            Slider(
              min: math.min(0.2, nail.heightScale),
              max: math.max(3.0, nail.heightScale),
              value: nail.heightScale,
              onChanged: (value) {
                setState(() {
                  updateGeometry(nail, height: value);
                });
              },
            ),

            Text(
              'Góc xoay: '
              '${(nail.rotation * 180 / math.pi).round()}°',
            ),

            Slider(
              min: -math.pi,
              max: math.pi,
              value: nail.rotation.clamp(-math.pi, math.pi).toDouble(),
              onChanged: (value) {
                setState(() {
                  updateGeometry(nail, rotation: value);
                });
              },
            ),

            TextButton.icon(
              onPressed: () {
                setState(() {
                  nail.widthScale = 0.7;
                  updateGeometry(nail, height: 0.7, rotation: 0);
                });
              },
              icon: const Icon(Icons.restart_alt),
              label: const Text('Đặt lại kích thước'),
            ),
          ],
        ),
      ),
    );
  }

  // 16. THƯ VIỆN MẪU NAIL ĐƠN
  Widget nailLibrary() {
    return SizedBox(
      height: 145,

      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: names.length,

        itemBuilder: (context, index) {
          final active = selectedDesign == index;

          return GestureDetector(
            onTap: () => selectDesign(index),

            child: Container(
              width: 90,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(8),

              decoration: BoxDecoration(
                color: active ? Colors.pink.shade100 : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? Colors.pink : Colors.pink.shade100,
                  width: 2,
                ),
              ),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,

                children: [
                  nailDesign(index),

                  const SizedBox(height: 7),

                  Text(names[index], style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // 17. MỞ BẢNG GỢI Ý MÀU NAIL THEO ẢNH BÀN TAY
  Future<void> openColorSuggestion() async {
    if (handImage == null) {
      notice('Vui lòng tải ảnh bàn tay trước!');
      return;
    }

    final Color? color = await Navigator.push<Color>(
      context,
      MaterialPageRoute(
        builder: (_) => ColorSuggestionScreen(imageBytes: handImage!),
      ),
    );

    if (!mounted || color == null) return;

    // Nếu chưa đặt móng nào, tạo 5 móng để xem trước màu mới.
    if (nails.isEmpty) {
      await autoPlaceNails();
      if (!mounted || nails.isEmpty) return;
    }

    setState(() {
      // Áp dụng màu lên tất cả móng đang có.
      for (final nail in nails) {
        nail.solidColor = color;
      }
    });

    notice('Đã áp dụng màu Nail lên các móng!');
  }

  // 18. Lưu kết quả vào tài khoản hoặc chia sẻ khi người dùng chọn.
  Future<void> saveImage({bool share = false}) async {
    if (handImage == null || nails.isEmpty) {
      notice('Hãy tải ảnh và thêm mẫu Nail trước!');
      return;
    }

    if (saving || analyzing) return;
    bool retryAfterLogin = false;

    try {
      setState(() {
        saving = true;
      });

      await precacheImage(MemoryImage(handImage!), context);
      if (!mounted) return;

      for (final nail in nails) {
        if (nail.surface != null) await NailSurfaceService.load(nail.surface!);
        final set = nail.artworkSet;
        final asset = set != null && set.images.isNotEmpty
            ? set.images[nail.design % 5]
            : nail.imagePath;
        if (asset != null) {
          await NailAssetService.decoded(asset);
          final imageBytes = await NailAssetService.load(asset);
          if (!mounted) return;
          await precacheImage(MemoryImage(imageBytes), context);
        }
      }

      // Chờ Flutter ẩn viền vàng
      await WidgetsBinding.instance.endOfFrame;

      final boundary =
          captureKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('Không tìm thấy vùng ảnh');
      }

      final image = await boundary.toImage(pixelRatio: 2.5);

      final data = await image.toByteData(format: ui.ImageByteFormat.png);

      image.dispose();

      if (data == null) {
        throw Exception('Không thể tạo ảnh PNG');
      }

      final output = data.buffer.asUint8List();
      if (!share) {
        if (AuthService.instance.user == null) {
          throw const AuthException(
            'Hãy đăng nhập để lưu mẫu vào tài khoản.',
            401,
          );
        }
        await TryOnHistory.add(handImage!, output, activeSet ?? nailSets.first);
        notice(
          'Đã lưu mẫu vào tài khoản. Bạn có thể xem trong lịch sử thử nail.',
        );
        return;
      }
      if (share) {
        if (!mounted) return;
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile.fromData(output, mimeType: 'image/png')],
            fileNameOverrides: ['nail_virtual.png'],
            title: 'Mẫu nail của tôi',
          ),
        );
        return;
      }
    } on AuthException catch (e) {
      if (e.status == 401 && mounted) {
        notice(
          'Phiên đăng nhập cần xác nhận lại. Ảnh đang chỉnh vẫn được giữ.',
        );
        retryAfterLogin =
            await Navigator.push<bool>(
              context,
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            ) ==
            true;
      } else {
        notice('Chưa lưu được ảnh: ${e.message}');
      }
    } catch (e) {
      notice('Lỗi lưu ảnh: $e');
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
    if (retryAfterLogin && mounted) {
      await saveImage(share: share);
    }
  }

  // 19. GIAO DIỆN CHÍNH
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),

      appBar: AppBar(
        title: Text(
          activeSet == null ? 'Thử mẫu Nail' : 'Thử bộ ${activeSet!.name}',
        ),
        backgroundColor: Colors.pink.shade100,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            const Text(
              'Thử Nail tự động trên ảnh bàn tay',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            handCanvas(),

            if (handImage != null)
              ValueListenableBuilder<Matrix4>(
                valueListenable: handView,
                builder: (context, transform, _) {
                  final zoom = transform.getMaxScaleOnAxis();
                  return Center(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Thu nhỏ ảnh bàn tay',
                          onPressed: zoom <= 1 || saving
                              ? null
                              : () => zoomHand(1 / 1.25),
                          icon: const Icon(Icons.zoom_out),
                        ),
                        Text('${(zoom * 100).round()}%'),
                        IconButton(
                          tooltip: 'Phóng to ảnh bàn tay',
                          onPressed: zoom >= maxHandZoom || saving
                              ? null
                              : () => zoomHand(1.25),
                          icon: const Icon(Icons.zoom_in),
                        ),
                        IconButton(
                          tooltip: 'Đặt lại góc nhìn bàn tay',
                          onPressed: zoom <= 1 || saving
                              ? null
                              : () => handView.value = Matrix4.identity(),
                          icon: const Icon(Icons.fit_screen),
                        ),
                      ],
                    ),
                  );
                },
              ),

            if (nails.isNotEmpty)
              Center(
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Ảnh gốc')),
                    ButtonSegment(value: false, label: Text('Kết quả')),
                  ],
                  selected: {showOriginal},
                  onSelectionChanged: saving || analyzing
                      ? null
                      : (values) => setState(() {
                          showOriginal = values.first;
                          selected = null;
                        }),
                ),
              ),

            const SizedBox(height: 12),

            const SizedBox(height: 10),

            if (nails.isNotEmpty && !showOriginal) shapeAndLengthControls(),
            if (nails.isNotEmpty && !showOriginal) decorationPanel(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: pickImage,
                icon: const Icon(Icons.add_photo_alternate),
                label: const Text('TẢI ẢNH BÀN TAY'),
              ),
            ),

            const SizedBox(height: 10),

            // Chế độ chính: AI nhận diện 5 ngón và tự ghép mẫu Nail.
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: handImage == null || analyzing || saving
                    ? null
                    : autoPlaceNails,
                icon: analyzing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(
                  analyzing
                      ? 'ĐANG NHẬN DIỆN BÀN TAY...'
                      : 'TẠO ẢNH TỰ ĐỘNG (AI)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE91E63),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            if (detectionSummary != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  detectionSummary!,
                  style: const TextStyle(color: Colors.brown),
                ),
              ),
            const SizedBox(height: 10),

            // Nút mới: lấy mẫu màu da từ ảnh và gợi ý màu Nail
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: handImage == null ? null : openColorSuggestion,
                icon: const Icon(Icons.palette),
                label: const Text('GỢI Ý MÀU NAIL THEO BÀN TAY'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.pink.shade100,
                  foregroundColor: Colors.pink.shade900,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Chế độ bộ Nail thật
            if (activeSet != null) ...[
              Text(
                'BỘ ĐANG THỬ: ${activeSet!.name}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: handImage == null || analyzing || saving
                      ? null
                      : autoPlaceNails,
                  icon: const Icon(Icons.refresh),
                  label: const Text('NHẬN DIỆN LẠI 5 MÓNG'),
                ),
              ),

              const SizedBox(height: 12),
            ],

            const Text(
              'CHỌN MẪU NAIL',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),

            const SizedBox(height: 10),

            FilledButton.tonalIcon(
              onPressed: analyzing || saving ? null : chooseSet,
              icon: const Icon(Icons.collections_outlined),
              label: const Text('ĐỔI BỘ NAIL'),
            ),

            const SizedBox(height: 12),
            const Text('Bề mặt nail'),
            if (nails.isNotEmpty && nails.any((n) => n.surface == null))
              const Text(
                'Tạo lại ảnh tự động để cập nhật ánh sáng theo ảnh móng.',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            Wrap(
              spacing: 8,
              children: [
                for (final option in NailFinish.values)
                  ChoiceChip(
                    label: Text(switch (option) {
                      NailFinish.natural => 'Tự nhiên',
                      NailFinish.glossy => 'Bóng',
                      NailFinish.matte => 'Lì',
                    }),
                    selected: finish == option,
                    onSelected: saving || analyzing
                        ? null
                        : (_) => setState(() => finish = option),
                  ),
              ],
            ),

            ExpansionTile(
              title: const Text('Chỉnh tay khi cần'),
              children: [
                adjustPanel(),

                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,

                  children: [
                    ElevatedButton.icon(
                      onPressed: handImage == null ? null : addNail,
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm mẫu'),
                    ),

                    if (activeSet == null)
                      ElevatedButton.icon(
                        onPressed: handImage == null ? null : addFiveSamples,
                        icon: const Icon(Icons.back_hand),
                        label: const Text('Bộ 5 mẫu'),
                      ),

                    OutlinedButton.icon(
                      onPressed: nails.isEmpty ? null : clearAll,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Làm lại'),
                    ),

                    OutlinedButton.icon(
                      onPressed: selected == null ? null : deleteNail,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Xóa mẫu'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: saving || analyzing ? null : saveImage,
                icon: const Icon(Icons.cloud_upload_outlined),
                label: Text(saving ? 'ĐANG LƯU...' : 'LƯU VÀO TÀI KHOẢN'),
              ),
            ),

            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: nails.isEmpty || saving || analyzing
                      ? null
                      : () => saveImage(share: true),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Chia sẻ ảnh'),
                ),
              ],
            ),

            const SizedBox(height: 16),

            const Text(
              'Hướng dẫn:\n'
              '1. Chọn bộ Nail (nếu có) và tải ảnh bàn tay.\n'
              '2. Nhấn TẠO ẢNH TỰ ĐỘNG (AI).\n'
              '3. Chạm vào mẫu nếu muốn kéo, chỉnh kích thước hoặc xoay.\n'
              '4. Có thể thay màu, thay mẫu hay thử bộ 5 móng.\n'
              '5. Chọn LƯU VÀO TÀI KHOẢN để xem lại kết quả trong lịch sử.',
              style: TextStyle(color: Colors.black54, height: 1.6),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
