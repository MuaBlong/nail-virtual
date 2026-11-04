# Nail Virtual — thử nail tự động

## Chức năng hiện có

- Người dùng phải đăng ký hoặc đăng nhập trước khi sử dụng ứng dụng. Phiên web còn hiệu lực được khôi phục tự động; đăng xuất đưa về màn hình đăng nhập và xóa các màn hình đang mở. Nút tài khoản ở góc phải trang chủ; xem backend/AUTH.md.

- Chụp bằng webcam/camera hoặc chọn ảnh bàn tay.
- Thư viện 51 bộ mẫu: 1 bộ PNG Sweet Pink và 50 bộ thiết kế vẽ bằng Flutter, gồm French, ombre, mắt mèo, ánh kim, nhũ, hoa, vân đá, tối giản, cá tính và mẫu cưới.
- Tìm tên/phong cách có dấu hoặc không dấu, lọc phong cách/tông màu, lưu yêu thích trên thiết bị.
- Đọc thêm bộ mẫu 5 ngón từ Node.js/MySQL; dùng thư viện có sẵn nếu backend dữ liệu chưa chạy.
- Lấy thiết kế theo từng ngón từ ảnh một bàn tay đã làm nail, yêu cầu nhìn rõ đủ 5 móng.
- MediaPipe xác định các ngón; YOLOv8-seg ONNX tìm vùng móng thật; ghép một-một để không dùng chung một vùng cho hai ngón.
- Căn tâm/kích thước/góc theo vùng móng, co giãn thiết kế theo bề rộng từng hàng, cắt theo đường viền và điều chỉnh ánh sáng theo ảnh đích.
- Không ghép vào ngón chưa nhận diện được khi dùng mô hình ONNX. Có công cụ chỉnh tay tùy chọn.
- Số móng ghép không bắt buộc bằng 5: có thể ghép 4 hoặc 6 vùng móng nếu mô hình tìm được các vùng riêng biệt đủ rõ. Vùng bổ sung được kiểm tra độ tin cậy, vị trí gần bàn tay và trùng lặp; dùng thiết kế của ngón chuẩn gần nhất. Mặc định sau nhận diện là dáng oval. Kiểm thử 4/6 vùng dùng dữ liệu mô phỏng, chưa có bộ ảnh tay 4/6 ngón thực tế để đánh giá độ chính xác riêng.
- Đổi bộ mẫu trên cùng ảnh mà không gọi lại nhận diện; xem ảnh gốc/kết quả; lưu PNG và mở bảng chia sẻ hệ điều hành/trình duyệt.
- Điều chỉnh chiều dài giữ nguyên chân móng; đầu móng dài/ngắn theo hướng ngón, kể cả khi xoay nghiêng. Phóng to/thu nhỏ và đặt lại kích thước cũng giữ điểm neo chân móng.
- Sau khi ghép có thể chọn dáng gốc, vuông, oval, bầu hoặc nhọn; phần chân móng được giữ theo đường viền nhận diện. Thanh chiều dài cả bộ từ 60% đến 200%, có nút dài hơn/ngắn hơn và trở về chiều dài ban đầu. Đổi dáng/chiều dài không gọi lại AI và vẫn xuất vào ảnh lưu/chia sẻ.
- Bề mặt tự nhiên/bóng/lì: lấy ánh sáng và phản chiếu từ ảnh đích, pha một lượng nhỏ sắc ánh sáng từ phản chiếu gần trung tính, làm mềm viền vào trong và làm mượt đường viền nhận diện. Không dùng lại màu sơn cũ làm lớp ánh sáng.
- Chọn “LƯU VÀO TÀI KHOẢN” để ghi vào hand_images và try_on_history của MySQL theo tài khoản, không tự tải ảnh xuống thiết bị người dùng. Database lưu đường dẫn ảnh; các tệp ảnh và thông tin mẫu nằm trong backend/storage/try-on. Lịch sử đọc qua API, phân trang 10 mẫu, xem được trên thiết bị khác khi đăng nhập cùng tài khoản; có thể xóa, thử lại hoặc dùng cùng mẫu cho tay khác. Ảnh lịch sử được thu nhỏ tối đa 720 px. Sao lưu cần cả database và thư mục storage. Yêu thích vẫn lưu trên thiết bị. Lịch sử cục bộ cũ chưa được chuyển tự động vào database.

## Chạy trên máy tính

AI, từ ai_service:

    .\.venv\Scripts\python.exe -m uvicorn app:app --host 127.0.0.1 --port 8001

Backend mẫu nail, từ backend (MySQL đã bật và .env được cấu hình):

    node server.js

Flutter, từ flutter_app:

    flutter pub get
    flutter run -d chrome

Có thể cấu hình địa chỉ máy chủ bằng --dart-define=AI_BASE_URL=... và --dart-define=API_BASE_URL=.... Khi chạy điện thoại, 127.0.0.1 là điện thoại, cần đặt địa chỉ máy chủ phù hợp. Camera trình duyệt cần localhost hoặc HTTPS. Android yêu cầu API 24+; iOS 13+. Chưa kiểm thử trên điện thoại thật.

Đang có bản xem thử mới tại http://127.0.0.1:8766 dùng AI cổng 18002. Phiên cũ cổng 8765 được giữ riêng để không làm mất ảnh đang thử.

## Kiểm thử

    # trong ai_service
    .\.venv\Scripts\python.exe -m unittest discover -s tests -v
    # trong backend
    node --test tests/nailSets.test.js
    # trong flutter_app
    flutter analyze
    flutter test

Kiểm tra trực quan bằng ảnh công khai (không cần ảnh cá nhân):

    # trong ai_service
    .\.venv\Scripts\python.exe tests/render_fixture.py
    # trong flutter_app
    flutter test --dart-define=VISUAL_QA=true test/render_natural_preview_test.dart

Ảnh render kiểm tra: flutter_app/build/visual_qa/{natural,glossy,matte}.png.

## Giới hạn và nguồn tham khảo

Tự căn ban đầu bám theo dáng và chiều dài móng thật. Đổi dáng/chiều dài là mô phỏng lớp thiết kế trên ảnh; chưa tái dựng nền ảnh bị lộ khi thu ngắn móng và không tái dựng đá nổi 3D. Ánh kim/nhũ là hiệu ứng xem trước. Ảnh mẫu riêng phải là một bàn tay nhìn rõ đủ 5 móng; chưa hỗ trợ tách tùy ý từ ảnh collage hoặc ảnh hộp móng giả.

Mô hình đã chạy được trên CPU và smoke test nhận diện 5/5 móng trên một ảnh công khai của chính kho mô hình. Đây không phải tập đánh giá độc lập; ảnh mờ, che khuất, phản sáng mạnh hoặc góc nghiêng vẫn có thể sai. Cần bộ ảnh thực tế có nhãn để đo IoU và tỷ lệ đúng theo từng ngón.

Mô hình ONNX và ảnh kiểm thử từ https://github.com/austingg/finger-nail-seg, nguồn/giấy phép/hash trong ai_service/models/nail-seg.SOURCE.md và nail-seg.LICENSE (GPL-3.0). Thư viện suy luận dùng OpenCV DNN. Xem lại điều kiện giấy phép trước khi phát hành bản phân phối chứa mô hình.

Tham khảo luồng sản phẩm công khai của Nailumi: Salon Nail Try-On (9VIL): https://play.google.com/store/apps/details?id=com.ninevil.nailumi. Không sử dụng mã nguồn, logo hoặc ảnh mẫu của Nailumi. Không khẳng định thuật toán hay chất lượng tương đương Nailumi.

## Mẫu trơn và tự trang trí

Thư viện có 20 màu trơn và 12 bộ ảnh mẫu. Sau khi ghép lên bàn tay, phần **Tự trang trí móng** cho phép chọn ngón và thêm 22 loại đá, ngọc trai, hoa, nơ, bướm, sao, tim và vỏ sò. Có thể kéo phụ kiện trực tiếp trên móng, chỉnh kích thước/góc xoay, xóa riêng hoặc xóa trên một ngón. Ảnh lưu/chia sẻ/lịch sử chứa cả trang trí; lịch sử lưu ảnh kết quả, chưa lưu các lớp phụ kiện để chỉnh lại.

Bản web: `flutter build web --release --no-web-resources-cdn --no-wasm-dry-run --dart-define=AI_BASE_URL=http://127.0.0.1:18002 --dart-define=API_BASE_URL=http://127.0.0.1:5000`, rồi chạy `python tool/serve_preview.py` trong flutter_app. CanvasKit được tải cục bộ.

## Chuẩn bị ảnh mẫu mới

Từ flutter_app chạy `dart run tool/prepare_nail_assets.dart` để tách sheet gốc thành 60 PNG trong assets/nails/prepared và cập nhật catalog JSON cho ứng dụng/backend. Khi thêm thư mục assets mới phải đóng gói lại bản web; hot restart không cập nhật đầy đủ các thư mục mới.
