import 'package:flutter/material.dart';
import '../services/try_on_history.dart';
import 'try_nail.dart';

class TryOnHistoryScreen extends StatefulWidget {
  const TryOnHistoryScreen({super.key});
  @override
  State<TryOnHistoryScreen> createState() => _TryOnHistoryScreenState();
}

class _TryOnHistoryScreenState extends State<TryOnHistoryScreen> {
  late Future<List<TryOnRecord>> records;
  bool loadingMore = false, hasMore = true;
  @override
  void initState() {
    super.initState();
    records = TryOnHistory.load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Lịch sử thử nail')),
    body: FutureBuilder<List<TryOnRecord>>(
      future: records,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Chưa tải được mẫu đã lưu. Hãy kiểm tra kết nối.'),
                TextButton(
                  onPressed: () => setState(() {
                    hasMore = true;
                    records = TryOnHistory.load();
                  }),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;
        if (data.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Chưa có lượt thử đã lưu. Sau khi tạo ảnh, chọn “LƯU VÀO TÀI KHOẢN” để xem lại tại đây.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Mẫu đã lưu trong tài khoản của bạn.'),
            const SizedBox(height: 12),
            ...data.map(
              (record) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        record.set.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        record.created.toLocal().toString().substring(0, 16),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              children: [
                                const Text('Trước'),
                                Image.memory(record.before, height: 200),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              children: [
                                const Text('Sau'),
                                Image.memory(record.result, height: 200),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => TryNailScreen(
                                  nailSet: record.set,
                                  initialImage: record.before,
                                  autoStart: true,
                                ),
                              ),
                            ),
                            child: const Text('Thử lại trên ảnh này'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TryNailScreen(nailSet: record.set),
                              ),
                            ),
                            child: const Text('Thử trên tay khác'),
                          ),
                          IconButton(
                            tooltip: 'Xóa kết quả khỏi lịch sử',
                            onPressed: () async {
                              try {
                                await TryOnHistory.remove(record.id);
                                if (mounted) {
                                  setState(() {
                                    hasMore = true;
                                    records = TryOnHistory.load();
                                  });
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Chưa xóa được kết quả.'),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (hasMore && data.length >= 10 && data.length % 10 == 0)
              TextButton(
                onPressed: loadingMore
                    ? null
                    : () async {
                        setState(() => loadingMore = true);
                        try {
                          final more = await TryOnHistory.load(
                            offset: data.length,
                          );
                          if (mounted) {
                            setState(() {
                              hasMore = more.length == 10;
                              records = Future.value([...data, ...more]);
                            });
                          }
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Chưa tải thêm được mẫu. Hãy thử lại.',
                                ),
                              ),
                            );
                          }
                        } finally {
                          if (mounted) setState(() => loadingMore = false);
                        }
                      },
                child: Text(loadingMore ? 'Đang tải...' : 'Xem thêm'),
              ),
          ],
        );
      },
    ),
  );
}
