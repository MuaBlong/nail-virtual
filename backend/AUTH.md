# Tài khoản người dùng

API dưới /api/auth:

- POST /register: fullName, email, password. Email được chuẩn hóa, mật khẩu 8–128 ký tự; tạo tài khoản role=user và đăng nhập ngay.
- POST /login: email, password. Trả thông báo chung khi email/mật khẩu sai.
- GET /me: trả hồ sơ người dùng hoặc 401 nếu phiên không hợp lệ/hết hạn.
- POST /logout: thu hồi phiên phía server và xóa cookie.

Mật khẩu dùng scrypt (N=32768,r=8,p=1), salt ngẫu nhiên 16 byte, đối chiếu timingSafeEqual. Chỉ lưu password_hash. Phiên dùng token ngẫu nhiên 32 byte, database chỉ lưu SHA-256 của token; hết hạn sau 7 ngày. Web lưu phiên bằng cookie HttpOnly, SameSite=Strict; Secure khi NODE_ENV=production. Không trả token trong JSON cho web và không lưu token/mật khẩu trong localStorage. Native nhận token khi gửi X-Auth-Client:native, giữ trong bộ nhớ; đóng ứng dụng cần đăng nhập lại.

Auth POST chỉ nhận JSON và kiểm tra Origin. CORS nhận đúng origin được cấu hình; môi trường phát triển chấp nhận localhost/127.0.0.1. Đăng nhập/đăng ký giới hạn 20 lượt/IP trong 15 phút (bộ đếm nằm trong tiến trình). Đưa lên nhiều instance cần bộ đếm dùng chung.

Production cần HTTPS, NODE_ENV=production và CORS_ORIGINS chứa danh sách origin giao diện, ngăn cách bằng dấu phẩy. Không dùng HTTP để truyền mật khẩu trong bản phát hành. Bản hiện tại chạy trên localhost phục vụ phát triển.

Bảng users và tài khoản hiện có được giữ nguyên. Backend tự tạo bảng users nếu chưa có, rồi tạo bảng user_sessions khi khởi động; lược đồ cho môi trường mới ở ../database/auth_schema.sql. Giao dịch đăng ký ghi tài khoản và phiên cùng nhau, lỗi sẽ rollback.

Chạy: npm start. Kiểm thử: npm test. Kiểm tra MySQL thật: node scripts/smoke-auth.js (chỉ tạo và dọn tài khoản thử tự sinh với email @example.invalid).

Backend mặc định chỉ lắng nghe 127.0.0.1. Có thể cấu hình HOST khi cần phục vụ trên địa chỉ khác.

Mẫu đã lưu dùng cấu trúc hiện có: hand_images (id, user_id, image_path, created_at) lưu ảnh bàn tay; try_on_history (id, user_id, hand_image_id, set_id, result_path, created_at) liên kết ảnh bàn tay và ảnh kết quả. Các ảnh nằm trong backend/storage/try-on/<UUID>/; database lưu đường dẫn tương đối. Thông tin đầy đủ của mẫu được giữ trong set.json cùng thư mục. set_id chỉ có giá trị khi mẫu có ID tương ứng trong nail_sets; mẫu thư viện Flutter/mẫu tự tạo dùng NULL và khôi phục từ set.json. Backend không còn ghi vào saved_nail_designs; bảng đó đã được kiểm tra trống khi chuyển đổi và không bị xóa.

Ghi hai bảng trong cùng giao dịch; lỗi sẽ rollback và dọn các tệp vừa tạo. Xóa lịch sử chỉ xóa ảnh bàn tay nếu không còn bản ghi tham chiếu, đồng thời dọn tệp thuộc bản ghi. Sao lưu cần bao gồm cả database và backend/storage. Thư mục ảnh không được phục vụ công khai; API /api/auth/history kiểm tra phiên và chủ sở hữu trước khi đọc. POST lưu, GET phân trang 10 mẫu qua offset, DELETE /:id (ID số nguyên) xóa. Không nhận user_id từ client. Ảnh lịch sử nén JPEG tối đa 720 px, giới hạn 1 MB mỗi ảnh; metadata tối đa 2 MB, body tối đa 6 MB. Không tự xóa mẫu cũ theo số lượng. Lịch sử local cũ không tự nhập vào database. Yêu thích vẫn lưu trên thiết bị. Chưa triển khai xác minh email, quên mật khẩu hoặc đăng nhập mạng xã hội.
