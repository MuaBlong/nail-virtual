import 'package:flutter/material.dart';

// Import các màn hình
import 'try_on_flow.dart';
import 'try_on_history_screen.dart';
import 'nail_library.dart';
import 'nail_sets.dart';
import '../widgets/account_button.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  final AuthService? auth;
  const HomeScreen({super.key, this.auth});

  // Hàm chuyển sang màn hình khác
  void moTrang(BuildContext context, Widget trang) {
    Navigator.push(context, MaterialPageRoute(builder: (context) => trang));
  }

  // Tạo nút chức năng dùng chung
  Widget nutChucNang({
    required String ten,
    required IconData icon,
    required VoidCallback onPressed,
    bool outlined = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: outlined
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(ten),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB44570),
                side: const BorderSide(color: Color(0xFFF2A6C1)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
          : ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: Text(ten),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFF5B4CD),
                foregroundColor: const Color(0xFF65263D),
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7FA),

      appBar: AppBar(
        actions: [AccountButton(auth: auth)],
        title: const Text(
          'NAIL VIRTUAL',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFF5B4CD),
      ),

      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),

          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => moTrang(context, const TryOnHistoryScreen()),
                  icon: const Icon(Icons.history),
                  label: const Text('LỊCH SỬ THỬ NAIL'),
                ),
                // Biểu tượng ứng dụng
                Container(
                  width: 115,
                  height: 115,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD6E5),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Icon(
                    Icons.back_hand,
                    size: 72,
                    color: Color(0xFFD65A89),
                  ),
                ),

                const SizedBox(height: 25),

                // Tên ứng dụng
                const Text(
                  'ỨNG DỤNG THỬ MẪU NAIL ẢO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF65263D),
                  ),
                ),

                const SizedBox(height: 14),

                // Giới thiệu
                const Text(
                  'Khám phá những mẫu Nail yêu thích, '
                  'thử trực tiếp trên hình ảnh bàn tay '
                  'và lưu lại thiết kế của riêng bạn.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Colors.black54,
                  ),
                ),

                const SizedBox(height: 35),

                // 1. Thử mẫu Nail
                nutChucNang(
                  ten: 'BẮT ĐẦU THỬ NAIL',
                  icon: Icons.auto_awesome,
                  onPressed: () {
                    moTrang(context, const TryOnFlowScreen());
                  },
                ),

                const SizedBox(height: 14),

                // 2. Thư viện các mẫu Nail đơn
                nutChucNang(
                  ten: 'THƯ VIỆN MẪU NAIL',
                  icon: Icons.grid_view,
                  outlined: true,
                  onPressed: () {
                    moTrang(context, const NailLibraryScreen());
                  },
                ),

                const SizedBox(height: 14),

                // 3. Bộ mẫu Nail gồm 5 ngón
                nutChucNang(
                  ten: 'BỘ MẪU NAIL',
                  icon: Icons.collections,
                  onPressed: () {
                    moTrang(context, const NailSetsScreen());
                  },
                ),

                const SizedBox(height: 35),

                // Ghi chú cuối trang
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF8D3E0)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.favorite, color: Colors.pink, size: 28),
                      SizedBox(height: 8),
                      Text(
                        'Thiết kế Nail theo phong cách của bạn',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Chọn mẫu • Thử Nail • Lưu thiết kế',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                    ],
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
