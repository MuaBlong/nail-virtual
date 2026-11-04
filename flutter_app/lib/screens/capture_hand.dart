import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

class CaptureHandScreen extends StatefulWidget {
  const CaptureHandScreen({super.key});
  @override
  State<CaptureHandScreen> createState() => _CaptureHandScreenState();
}

class _CaptureHandScreenState extends State<CaptureHandScreen>
    with WidgetsBindingObserver {
  CameraController? controller;
  List<CameraDescription> cameras = [];
  int selected = 0;
  int generation = 0;
  bool loading = true;
  bool taking = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    discover();
  }

  Future<void> discover() async {
    try {
      cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) throw StateError('no cameras');
      final rear = cameras.indexWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
      );
      selected = rear < 0 ? 0 : rear;
      await start();
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          error =
              'Không mở được camera. Hãy cho phép truy cập camera trong trình duyệt hoặc chọn ảnh từ thư viện.';
        });
      }
    }
  }

  Future<void> start() async {
    if (!mounted || cameras.isEmpty) return;
    final current = ++generation;
    final previous = controller;
    controller = null;
    setState(() {
      loading = true;
      error = null;
    });
    await previous?.dispose();
    if (!mounted || current != generation) return;
    final next = CameraController(
      cameras[selected],
      ResolutionPreset.high,
      enableAudio: false,
    );
    try {
      await next.initialize();
      if (!mounted || current != generation) {
        await next.dispose();
        return;
      }
      setState(() {
        controller = next;
        loading = false;
      });
    } catch (_) {
      await next.dispose();
      if (mounted && current == generation) {
        setState(() {
          loading = false;
          error =
              'Camera chưa sẵn sàng. Kiểm tra quyền truy cập, đóng ứng dụng khác đang dùng camera rồi thử lại.';
        });
      }
    }
  }

  Future<void> capture() async {
    final camera = controller;
    if (camera == null || !camera.value.isInitialized || taking) return;
    setState(() => taking = true);
    try {
      final file = await camera.takePicture();
      final bytes = await file.readAsBytes();
      if (bytes.length > 10 * 1024 * 1024) {
        throw StateError('image too large');
      }
      if (mounted) Navigator.pop(context, bytes);
    } catch (_) {
      if (mounted) {
        setState(() => taking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chưa chụp được ảnh. Hãy thử lại.')),
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      generation++;
      final previous = controller;
      controller = null;
      unawaited(previous?.dispose());
      if (mounted) setState(() => loading = true);
    } else if (state == AppLifecycleState.resumed && cameras.isNotEmpty) {
      unawaited(start());
    }
  }

  @override
  void dispose() {
    generation++;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(controller?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      title: const Text('Chụp mu bàn tay'),
      actions: [
        if (cameras.length > 1)
          IconButton(
            tooltip: 'Đổi camera',
            onPressed: loading || taking
                ? null
                : () {
                    selected = (selected + 1) % cameras.length;
                    start();
                  },
            icon: const Icon(Icons.cameraswitch_outlined),
          ),
      ],
    ),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Hướng mu bàn tay vào camera, xòe nhẹ 5 ngón và để lộ rõ các móng.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
        Expanded(
          child: loading
              ? const Center(child: CircularProgressIndicator())
              : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton(
                          onPressed: discover,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                )
              : Center(
                  child: AspectRatio(
                    aspectRatio: controller!.value.aspectRatio,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(controller!),
                        IgnorePointer(
                          child: FractionallySizedBox(
                            widthFactor: .85,
                            heightFactor: .9,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white54,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: FilledButton.icon(
              onPressed: loading || error != null || taking ? null : capture,
              icon: const Icon(Icons.camera_alt),
              label: Text(taking ? 'Đang chụp...' : 'Chụp ảnh'),
            ),
          ),
        ),
      ],
    ),
  );
}
