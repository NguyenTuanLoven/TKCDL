# FilmLab Connect — Bài tập nhóm Thiết kế cơ sở dữ liệu

**Nhóm:** Nguyễn Hữu Anh Tuấn
**Giảng viên:** Nguyễn Văn Chiến

Thiết kế cơ sở dữ liệu cho nền tảng kết nối người chụp film với Film Lab. Phần code sử dụng **Microsoft SQL Server (T-SQL)**, hỗ trợ quản lý người dùng, dịch vụ, đơn hàng, cuộn film, ảnh scan, thanh toán và các dữ liệu cộng đồng.

## Thành viên

| STT | Họ tên | MSSV |
|---|---|---|
| 1 | Nguyễn Anh Duy | 087206007232 |
| 2 | Mai Nguyễn Khánh Ngân | 089306015518 |
| 3 | Nguyễn Hữu Anh Tuấn | 075207011357 |
| 4 | Phan Nguyễn Trọng Hải | 087206004062 |
| 5 | Châu Thanh Hậu | 091206018593 |

## Tài liệu và code hiện có

- Thư mục `sql/`: sáu file tạo cơ sở dữ liệu, bảng, các đối tượng xử lý nghiệp vụ, dữ liệu mẫu, kiểm thử và truy vấn minh họa.
- `BÁO CÁO KẾT THÚC TKCSDL.docx`: báo cáo tổng hợp hiện có.
- Các tài liệu Word về mô hình khái niệm, mô hình quan hệ, chuẩn hóa và thiết kế vật lý.
- `EDR.drawio.html`: sơ đồ hiện có của nhóm.

**Trạng thái đồng bộ:** báo cáo và mô hình hiện có còn mô tả PostgreSQL với 14 bảng, trong khi code SQL Server triển khai 24 bảng. Nhóm cần thống nhất báo cáo, ERD và từ điển dữ liệu với code trước khi nộp. Mã nguồn LaTeX và báo cáo PDF chưa có trong bản repository được kiểm tra ngày 25/09/2026.

## Nội dung phần SQL

- 24 bảng.
- 3 view, 1 hàm bảng, 6 stored procedure, 9 trigger và 1 kiểu bảng dùng làm tham số.
- Dữ liệu mẫu, 18 truy vấn minh họa và 32 ca kiểm thử.
- Database sử dụng: `FilmLabCoursework`.

Dữ liệu mẫu là dữ liệu mô phỏng phục vụ học tập.

## Môi trường chạy

- SQL Server Database Engine và SQL Server Management Studio (SSMS).
- Nhóm đã chạy kiểm thử trên SQL Server 2025 Express qua SSMS 22.
- Tài khoản có quyền tạo cơ sở dữ liệu khi cài đặt; chạy kiểm thử bằng tài khoản có quyền chủ sở hữu cơ sở dữ liệu.

## Cách chạy bằng SSMS

1. Kết nối SQL Server. Trên máy đã thực hành, tên server là `.\SQLEXPRESS`, sử dụng Windows Authentication. Máy khác có thể dùng tên instance khác.
2. Mở từng file bằng **File → Open → File** hoặc **Ctrl + O**, rồi bấm **Execute** theo thứ tự:

| Thứ tự | File | Chức năng |
|---|---|---|
| 1 | [00_database.sql](sql/00_database.sql) | Tạo cơ sở dữ liệu |
| 2 | [01_schema.sql](sql/01_schema.sql) | Tạo bảng, khóa và ràng buộc |
| 3 | [02_programmability.sql](sql/02_programmability.sql) | Tạo view, function, procedure, trigger và cấu hình quyền |
| 4 | [03_seed.sql](sql/03_seed.sql) | Thêm dữ liệu mẫu |
| 5 | [05_tests.sql](sql/05_tests.sql) | Chạy kiểm thử |
| 6 | [04_queries.sql](sql/04_queries.sql) | Chạy truy vấn minh họa |

3. Dừng và xử lý nếu có lỗi trước khi chạy file tiếp theo.
4. Kết quả kiểm thử mong đợi: `PassedTests = 32` và các dòng kiểm thử đều `PASS`.

Chỉ chạy các bước tạo bảng và nạp dữ liệu mẫu khi cài lần đầu vào cơ sở dữ liệu mới. Nếu đã cài thành công, chỉ chạy lại kiểm thử và truy vấn minh họa; không chạy lại `01_schema.sql` hoặc `03_seed.sql` trên dữ liệu đã có.

## Kết quả kiểm thử

Ảnh kết quả chạy trên máy thành viên ngày 24/09/2026 ghi nhận **32/32 kiểm thử PASS**. Ảnh hoặc nhật ký thực thi chưa được đưa vào bản repository được kiểm tra ngày 25/09/2026.

Một số kiểm thử chủ động tạo dữ liệu không hợp lệ để kiểm tra cơ chế từ chối. Vì vậy, cột `ActualError` có thể chứa mã lỗi nhưng kết quả vẫn là `PASS` nếu đúng lỗi dự kiến. Kết quả này xác nhận các tình huống đã kiểm tra, không thay thế việc rà soát toàn bộ thiết kế.

## Phạm vi và giới hạn

- Một đơn thuộc một Film Lab; mỗi dòng chi tiết đại diện một cuộn film và gói dịch vụ đã chọn.
- Tiền tệ sử dụng VND; chưa triển khai chia thanh toán, hoàn tiền, VAT, phí giao nhận hoặc chiết khấu.
- Giao nhận và marketplace mới hỗ trợ dữ liệu trong phạm vi bài tập.
- Phần AI lưu dữ liệu mô phỏng và có công thức gợi ý cơ sở, chưa triển khai mô hình AI thực tế.
- Đây là bài tập cơ sở dữ liệu, chưa phải ứng dụng web/mobile hoàn chỉnh.

Không đưa mật khẩu, API key hoặc file dữ liệu SQL Server `.mdf`/`.ldf` lên repository.
