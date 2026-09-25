# FilmLab Connect - Bài tập nhóm Thiết kế cơ sở dữ liệu

**Nhóm:** Nguyễn Anh Duy — **Giảng viên:** Nguyễn Văn Chiến.

Bộ bài tập phân tích và thiết kế dữ liệu cho nền tảng kết nối người chụp film với Film Lab. Sử dụng **Microsoft SQL Server (T-SQL)** và **LaTeX/XeLaTeX**. Đây là bài tập cơ sở dữ liệu, chưa phải ứng dụng mobile/web hoặc hệ thống AI vận hành đầy đủ.

## Mở gì trước?

1. Đọc [Báo cáo PDF](report/main.pdf): báo cáo chính, thông tin nhóm, phân tích, ERD, chuẩn hóa, thiết kế, kiểm thử, phân công đề xuất và vấn đáp.
2. Đọc [Hướng dẫn học và demo](docs/huong-dan-hoc-va-demo.md): thứ tự học và kịch bản bảo vệ.
3. Mở **sql/** để chạy các file theo thứ tự dưới đây.
4. Đọc [Hướng dẫn GitHub](docs/github-guide.md) nếu chưa quen GitHub.

## Thành viên

|STT|Họ tên|MSSV do nhóm cung cấp|
|---|---|---|
|1|Nguyễn Anh Duy|087206007232|
|2|Mai Nguyễn Khánh Ngân|089306015518|
|3|Nguyễn Hữu Anh Tuấn|075207011357|
|4|Phan Nguyễn Trọng Hải|087206004062|
|5|Châu Thanh Hậu|091206018593|

Chưa có thông tin trường, khoa/lớp, học kỳ và hạn nộp. Không tự điền các thông tin này. Có thể bổ sung trong report/team-info.tex.

## Thành phần

- 24 bảng; 143 cột; 32 khóa ngoại.
- 3 view; 1 hàm bảng; 6 stored procedure; 9 trigger; 1 kiểu bảng dùng làm tham số.
- 18 truy vấn minh họa và 32 ca kiểm thử có assertion.
- Dữ liệu mẫu cho toàn bộ 24 bảng; tất cả người dùng, lab, giao dịch và điểm AI là mô phỏng.
- ERD đầy đủ: docs/erd.md và docs/erd.mmd.
- Từ điển dữ liệu: docs/data-dictionary.md (sinh từ DDL).
- GitHub Actions: chạy schema, seed, tests và demo queries trên SQL Server 2022 trong container tạm.

## Yêu cầu môi trường

- SQL Server 2019 trở lên, hoặc SQL Server Express/Developer/LocalDB tương thích.
- SSMS (SQL Server Management Studio) hoặc PowerShell trên Windows có System.Data.SqlClient.
- Database dành riêng cho bài: **FilmLabCoursework**. Script không xóa database cũ.
- Quyền tạo database/schema cho lần cài đặt; chạy tests bằng chủ sở hữu database.
- XeLaTeX hoặc Tectonic để biên dịch báo cáo; Overleaf hỗ trợ XeLaTeX.

**SSMS chỉ là công cụ kết nối. Cài SSMS chưa có nghĩa SQL Server Database Engine đã cài và đang chạy.**

## Cách chạy bằng SSMS

1. Kết nối instance SQL Server đang hoạt động. Ví dụ: localhost\SQLEXPRESS hoặc (localdb)\MSSQLLocalDB; tên thực tế tùy máy.
2. Mở và Execute từng file, dừng ngay nếu có lỗi:
   - sql/00_database.sql
   - sql/01_schema.sql
   - sql/02_programmability.sql
   - sql/03_seed.sql
   - sql/05_tests.sql
   - sql/04_queries.sql
3. Kết quả mong đợi của tests: 32 dòng PASS và PassedTests = 32. Đây là điều kiện nghiệm thu, không phải tuyên bố đã chạy đạt.
4. Chạy queries để quan sát đơn 2 tổng 240.000 VND, tiền đã thu toàn hệ thống 160.000 VND từ hai giao dịch mẫu.
5. Không chạy lại schema/seed trên database đã có dữ liệu. Chỉ chạy lại tests/queries; hoặc dùng một database mới và thay tên USE thống nhất.

## Cách chạy bằng PowerShell

Tại thư mục gốc của bộ bài tập:

~~~powershell
.\scripts\run-sql.ps1 -Server '.\SQLEXPRESS' -Install -Test -DemoQueries -OutputFile '.\evidence\sqlserver-local.txt'
~~~

Nếu đã cài schema và seed:

~~~powershell
.\scripts\run-sql.ps1 -Server '.\SQLEXPRESS' -Test -OutputFile '.\evidence\sqlserver-local.txt'
~~~

Script dừng ngay khi lỗi và tách GO thành các batch. GO là dấu phân cách của công cụ, không phải câu lệnh T-SQL gửi tới engine.

## Báo cáo LaTeX

- Nguồn chính: report/main.tex.
- Thông tin bìa: report/team-info.tex.
- Biên dịch: scripts/build-report.ps1 hoặc chạy xelatex main.tex hai lần trong report/.
- Overleaf: tải lên các file trong report/, chọn Main document = main.tex, Compiler = XeLaTeX.
- Nếu dùng Tectonic lần đầu, công cụ cần mạng để tải gói TeX.
- Khi sửa schema: chạy scripts/generate-design.py để cập nhật từ điển/ERD, rồi biên dịch lại.
- Khi sửa ca kiểm thử: sửa scripts/generate-tests.py rồi chạy Python để sinh lại sql/05_tests.sql.

## Trạng thái kiểm chứng

Xem [Trạng thái kiểm chứng](evidence/verification.md) trước khi nộp. Kiểm tra cú pháp bằng Microsoft ScriptDom không thay thế thực thi trên SQL Server. Không có ảnh chụp SSMS hoặc kết quả PASS giả lập. LocalDB trên máy soạn bài hiện gặp lỗi khởi động; workflow GitHub được cung cấp để nhóm chạy trên môi trường SQL Server riêng.

## Giới hạn nghiệp vụ đã chọn

Một đơn thuộc một lab; mỗi cuộn chọn một gói dịch vụ; VND; một giao dịch thành công đủ tổng đơn; chưa có hoàn tiền, chia thanh toán, phí vận chuyển, VAT hoặc chiết khấu. Giao nhận mới có bảng dữ liệu. Marketplace mới có tin đăng; chưa có thanh toán/đơn mua bán thiết bị. AI có dữ liệu lưu và công thức SQL cơ sở, chưa có mô hình thật.

Luồng tráng: CREATED → CONFIRMED → RECEIVED → DEVELOPING → SCANNING (nếu cần) → QUALITY_CHECK → READY → COMPLETED. Rửa/sấy nằm trong DEVELOPING. Hủy chỉ trước RECEIVED và chưa trả tiền. Khi trả ảnh, bài mẫu kiểm tra tối thiểu một scan/cuộn cần scan; kiểm tra đủ khung hình thuộc bước kiểm định của nhân viên.

## Bảo mật

Vai trò SQL film_app chỉ được gọi các thủ tục chỉ định; film_payment_service mới được ghi nhận thanh toán thành công. CallerId/CustomerId phải lấy từ danh tính đã xác thực ở backend. SQL demo không tự triển khai JWT/OAuth, tenant-aware read API, webhook signature hoặc URL ảnh có hạn. Không cấp role app cho người dùng cuối; không đưa tài khoản sa, mật khẩu, API key hoặc file .mdf/.ldf lên GitHub.


