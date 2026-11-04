import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/nail_set.dart';
import '../widgets/nail_catalog.dart';
import 'try_nail.dart';
import 'capture_hand.dart';
import '../services/auto_nail_api.dart';
import '../widgets/nail_artwork.dart';

class TryOnFlowScreen extends StatefulWidget {
  const TryOnFlowScreen({super.key});
  @override
  State<TryOnFlowScreen> createState() => _TryOnFlowScreenState();
}

class _TryOnFlowScreenState extends State<TryOnFlowScreen> {
  Uint8List? image;
  NailSet? selected;
  bool picking = false;
  NailSet? customSet;
  bool extracting = false;
  bool get cameraSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> pick(ImageSource source) async {
    if (picking) return;
    setState(() => picking = true);
    try {
      if (source == ImageSource.camera) {
        final bytes = await Navigator.push<Uint8List>(
          context,
          MaterialPageRoute(builder: (_) => const CaptureHandScreen()),
        );
        if (mounted && bytes != null) setState(() => image = bytes);
        return;
      }
      final file = await ImagePicker().pickImage(
        source: source,
        imageQuality: 92,
        maxWidth: 2048,
        maxHeight: 2048,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        throw const FormatException('Ảnh cần nhỏ hơn 10 MB');
      }
      if (mounted) setState(() => image = bytes);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không mở được ảnh/camera. Hãy kiểm tra quyền truy cập hoặc chọn ảnh từ thư viện.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  Future<void> importDesign(ImageSource source) async {
    if (extracting || picking) return;
    Uint8List? bytes;
    try {
      if (source == ImageSource.camera) {
        bytes = await Navigator.push<Uint8List>(
          context,
          MaterialPageRoute(builder: (_) => const CaptureHandScreen()),
        );
      } else {
        final photo = await ImagePicker().pickImage(
          source: source,
          maxWidth: 2048,
          maxHeight: 2048,
        );
        bytes = await photo?.readAsBytes();
      }
      if (bytes == null || !mounted) return;
      setState(() => extracting = true);
      final response = await AutoNailApi.extractDesign(bytes);
      final set = NailSet.fromJson({
        'id': 'custom_${DateTime.now().millisecondsSinceEpoch}',
        'name': 'Mẫu từ ảnh của bạn',
        'category': 'Mẫu riêng',
        'designs': response['designs'],
      });
      if (mounted) {
        setState(() {
          customSet = set;
          selected = set;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chưa lấy được mẫu. Hãy chọn ảnh một bàn tay làm nail, nhìn rõ đủ 5 móng, và kiểm tra kết nối xử lý ảnh.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => extracting = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFFFF7FA),
    appBar: AppBar(title: const Text('Thử nail trên bàn tay của bạn')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '1. Chụp hoặc chọn ảnh bàn tay',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Úp lòng bàn tay xuống, hướng mu bàn tay về camera. Xòe nhẹ 5 ngón, nhìn rõ các móng, chụp đủ sáng và tránh bóng đổ.',
              ),
              const SizedBox(height: 16),
              if (image != null)
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.memory(
                      image!,
                      height: 260,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              if (image == null)
                Container(
                  height: 160,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.pink.shade50,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.back_hand_outlined,
                    size: 90,
                    color: Colors.pinkAccent,
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  if (cameraSupported)
                    FilledButton.icon(
                      onPressed: picking
                          ? null
                          : () => pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Chụp bàn tay'),
                    ),
                  OutlinedButton.icon(
                    onPressed: picking ? null : () => pick(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(image == null ? 'Chọn ảnh' : 'Đổi ảnh'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                '2. Chọn bộ nail yêu thích',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Hoặc lấy thiết kế từ ảnh một bàn tay đã làm nail, nhìn rõ cả 5 móng.',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: extracting || picking
                        ? null
                        : () => importDesign(ImageSource.gallery),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Tải ảnh mẫu nail'),
                  ),
                  if (cameraSupported)
                    OutlinedButton.icon(
                      onPressed: extracting || picking
                          ? null
                          : () => importDesign(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Chụp mẫu nail'),
                    ),
                ],
              ),
              if (extracting)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 12),
                      Text('Đang lấy thiết kế từ ảnh...'),
                    ],
                  ),
                ),
              if (customSet != null)
                Card(
                  child: ListTile(
                    title: Text(customSet!.name),
                    subtitle: const Text('Đã lấy thiết kế cho 5 ngón'),
                    leading: SizedBox(
                      width: 35,
                      height: 55,
                      child: NailArtwork(set: customSet!),
                    ),
                    trailing: Icon(
                      selected == customSet
                          ? Icons.check_circle
                          : Icons.circle_outlined,
                      color: Colors.pink,
                    ),
                    onTap: () => setState(() => selected = customSet),
                  ),
                ),
              const SizedBox(height: 12),
              NailCatalog(
                selectedId: selected?.id,
                onSelect: (set) => setState(() => selected = set),
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: image == null || selected == null || picking || extracting
              ? null
              : () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TryNailScreen(
                        nailSet: selected,
                        initialImage: image,
                        autoStart: true,
                      ),
                    ),
                  );
                },
          icon: const Icon(Icons.auto_awesome),
          label: Text(
            selected == null
                ? 'Chọn ảnh và bộ nail để tiếp tục'
                : 'Thử ngay · ${selected!.name}',
          ),
        ),
      ),
    ),
  );
}
