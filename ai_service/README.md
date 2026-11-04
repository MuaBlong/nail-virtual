# AI nhận diện móng

Từ thư mục này:

    .\.venv\Scripts\python.exe -m uvicorn app:app --host 127.0.0.1 --port 8001
    .\.venv\Scripts\python.exe -m unittest discover -s tests -v

POST /detect-hand nhận multipart file. MediaPipe phát hiện một bàn tay, ONNX YOLOv8-seg (models/nail-seg.onnx) nhận diện từng vùng móng. Phép ghép một-một dựa trên khoảng cách và hướng ngón, có thể bỏ ngón không thấy móng. PCA điều chỉnh hướng theo vùng móng nếu hình dáng cho phép.

Các trường: success, image_width, image_height, nails, normalized_image (PNG base64 đã sửa EXIF và thu nhỏ cạnh tối đa 2048), segmented_count, warning. Mỗi nail chứa finger, x, y, width, height chuẩn hóa, rotation radian, polygon tọa độ cục bộ 0..1, shading gồm 128 giá trị soft-light 8x16, method, score, visible và needs_review. Score là điểm của mô hình, không phải xác suất độ khớp đã hiệu chuẩn. Flutter phải dùng normalized_image và cùng quy ước tọa độ.

Mỗi vùng móng nhận diện được còn có surface: lighting (PNG xám 64x96), highlights (PNG RGBA trắng với alpha từ phản chiếu ảnh thật), coverage (PNG RGBA, alpha làm mềm vào trong vùng móng), tint (3 hệ số màu giới hạn 0.94..1.06 suy ra từ phản chiếu gần trắng, mặc định 1). PNG được trả dạng data URI. Ánh sáng được làm trơn chỉ trong vùng móng bằng tích chập chuẩn hóa; không lấy RGB màu sơn cũ làm ánh sáng. Renderer pha các lớp trong một nhóm riêng và nội suy ánh sáng liên tục. shading 8x16 giữ để tương thích bản cũ.

Phản hồi thành công gồm 5 mục theo tên ngón chuẩn; visible=false nghĩa là không có vùng móng đáng tin để ghép. Có thể có thêm các mục extra_* cho vùng móng riêng biệt ngoài 5 nhãn MediaPipe. Các vùng bổ sung cần score >= 0.6, kích thước tương ứng móng đã ghép, nằm gần đầu ngón/bàn tay và không trùng vùng đã dùng; design_index chỉ mẫu 0..4 của ngón chuẩn gần nhất. Flutter ghép mọi mục visible, không yêu cầu đúng 5; 4 vùng nhìn thấy sẽ ghép 4. Đây là hỗ trợ hậu xử lý, chưa huấn luyện lại mô hình trên tay 4/6 ngón. Khi không có checkpoint ONNX mới dùng GrabCut/ước lượng dự phòng và thông báo rõ; chế độ dự phòng chỉ có 5 nhãn ước lượng, không suy ra móng thứ sáu. Nếu có checkpoint nhưng không chạy được, trả lỗi 503. Ảnh không có tay, nhiều tay hoặc không thấy rõ móng được trả thông báo để chụp lại.

POST /extract-nail-design nhận ảnh tham chiếu của một bàn tay có đủ 5 móng, trả designs là bản đồ thumb/index/middle/ring/pinky sang PNG data URI với nền trong suốt. Ảnh không đủ 5 vùng móng được từ chối với 422.

Giới hạn ảnh: 10 MB, 24 triệu pixel; xử lý nặng trong worker đồng bộ FastAPI; khóa việc dùng chung OpenCV DNN Net để tránh tranh chấp giữa các request.

Giấy phép/provenance của checkpoint: models/nail-seg.SOURCE.md và models/nail-seg.LICENSE. Xem ../README.md để biết các chức năng và giới hạn nghiệm thu.
