USE FilmLabCoursework;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF EXISTS(SELECT 1 FROM dbo.Users) THROW 51200,'Seed requires an empty schema.',1;
INSERT dbo.Roles VALUES
('CUSTOMER',N'Khách hàng'),('LAB_OWNER',N'Chủ lab'),('EXPERT',N'Chuyên gia'),
('COURIER',N'Đối tác giao nhận'),('ADMIN',N'Quản trị');
INSERT dbo.Users(FullName,Email,Phone) VALUES
(N'Khách mẫu An','an@example.test','0900000001'),
(N'Khách mẫu Bình','binh@example.test','0900000002'),
(N'Chủ lab Sài Gòn','labsg@example.test','0900000003'),
(N'Chủ lab Hà Nội','labhn@example.test','0900000004'),
(N'Chuyên gia mẫu','expert@example.test','0900000005'),
(N'Giao nhận mẫu','courier@example.test','0900000006'),
(N'Quản trị mẫu','admin@example.test','0900000007'),
(N'Nhân viên lab','staff@example.test','0900000008');
INSERT dbo.UserRoles VALUES (1,'CUSTOMER'),(2,'CUSTOMER'),(3,'LAB_OWNER'),
(4,'LAB_OWNER'),(5,'EXPERT'),(5,'CUSTOMER'),(6,'COURIER'),(7,'ADMIN');
INSERT dbo.Labs(OwnerId,LabName,City,Address,ApprovalStatus) VALUES
(3,N'Sài Gòn Film Lab (mẫu)',N'TP.HCM',N'Địa chỉ mô phỏng A','APPROVED'),
(4,N'Hà Nội Film Lab (mẫu)',N'Hà Nội',N'Địa chỉ mô phỏng B','APPROVED'),
(3,N'Lab chờ duyệt (mẫu)',N'TP.HCM',N'Địa chỉ mô phỏng C','PENDING');
INSERT dbo.LabMembers VALUES(1,8,'STAFF');
INSERT dbo.FilmStocks(StockName,FilmFormat,ProcessCode,ISO) VALUES
(N'Kodak Gold 200','35MM','C41',200),
(N'Ilford HP5 Plus','35MM','BW',400),
(N'Kodak Portra 400','120','C41',400),
(N'Fujifilm Velvia 50','35MM','E6',50);
INSERT dbo.Services(LabId,ServiceName,FilmFormat,ProcessCode,IncludesScan,ScanSpec,Price,TurnaroundHours) VALUES
(1,N'Tráng + scan màu 35mm','35MM','C41',1,N'JPEG 3000px',90000,48),
(1,N'Tráng đen trắng','35MM','BW',0,NULL,70000,72),
(1,N'Tráng + scan film 120','120','C41',1,N'TIFF 6000px',150000,72),
(2,N'Tráng + scan màu 35mm','35MM','C41',1,N'JPEG 3000px',85000,48),
(3,N'Gói của lab chưa duyệt','35MM','C41',1,N'JPEG',80000,48),
(1,N'Tráng + scan slide','35MM','E6',1,N'TIFF',180000,96);
GO
DECLARE @Items dbo.OrderInput,@Id int,@ItemId int;
INSERT @Items VALUES(N'AN-01',1,1,N'Canon AE-1',N'50mm f/1.8','2026-08-01');
EXEC dbo.usp_CreateOrder 1,1,'SELF',NULL,@Items,@Id OUTPUT;
EXEC dbo.usp_SetOrderStatus @Id,3,'CONFIRMED';
EXEC dbo.usp_SetOrderStatus @Id,3,'RECEIVED';
EXEC dbo.usp_SetOrderStatus @Id,8,'DEVELOPING';
EXEC dbo.usp_SetOrderStatus @Id,8,'SCANNING';
SELECT @ItemId=ItemId FROM dbo.OrderItems WHERE OrderId=@Id;
EXEC dbo.usp_AddScan @Id,@ItemId,8,1,1,'demo/order-1/frame-1.jpg','image/jpeg',2048000;
EXEC dbo.usp_AddScan @Id,@ItemId,8,2,1,'demo/order-1/frame-2.jpg','image/jpeg',2050000;
EXEC dbo.usp_SetOrderStatus @Id,3,'QUALITY_CHECK';
EXEC dbo.usp_SetOrderStatus @Id,3,'READY';
EXEC dbo.usp_RecordPayment @Id,'DEMO','PAY-DEMO-001',90000;
EXEC dbo.usp_SetOrderStatus @Id,3,'COMPLETED';
EXEC dbo.usp_AddReview @Id,1,5,N'Đánh giá mô phỏng: ảnh trả đúng hẹn.';
DELETE @Items;
INSERT @Items VALUES(N'BINH-01',1,1,N'Nikon FM2',N'50mm',NULL),
(N'BINH-02',3,3,N'Mamiya 645',N'80mm',NULL);
EXEC dbo.usp_CreateOrder 2,1,'COURIER',N'Địa chỉ nhận mô phỏng',@Items,@Id OUTPUT;
EXEC dbo.usp_SetOrderStatus @Id,3,'CONFIRMED';
EXEC dbo.usp_SetOrderStatus @Id,8,'RECEIVED';
GO

DECLARE @Items dbo.OrderInput,@Id int;
INSERT @Items VALUES(N'AN-BW-01',2,2,NULL,NULL,NULL);
EXEC dbo.usp_CreateOrder 1,1,'SELF',NULL,@Items,@Id OUTPUT;
EXEC dbo.usp_SetOrderStatus @Id,3,'CONFIRMED';
EXEC dbo.usp_SetOrderStatus @Id,3,'RECEIVED';
EXEC dbo.usp_SetOrderStatus @Id,3,'DEVELOPING';
EXEC dbo.usp_SetOrderStatus @Id,3,'QUALITY_CHECK';
EXEC dbo.usp_SetOrderStatus @Id,3,'READY';
EXEC dbo.usp_RecordPayment @Id,'DEMO','PAY-DEMO-003',70000;
EXEC dbo.usp_SetOrderStatus @Id,3,'COMPLETED';
EXEC dbo.usp_AddReview @Id,1,4,N'Dữ liệu minh họa, không phải đánh giá thật.';
DELETE @Items;
INSERT @Items VALUES(N'BINH-HN-01',1,4,NULL,NULL,NULL);
EXEC dbo.usp_CreateOrder 2,2,'SELF',NULL,@Items,@Id OUTPUT;
EXEC dbo.usp_SetOrderStatus @Id,2,'CANCELLED';
DELETE @Items;
INSERT @Items VALUES(N'AN-NEW-01',1,1,NULL,NULL,NULL);
EXEC dbo.usp_CreateOrder 1,1,'SELF',NULL,@Items,@Id OUTPUT;
GO
INSERT dbo.Albums(OwnerId,AlbumName) VALUES(1,N'Chuyến đi mẫu'),(2,N'Album của Bình');
INSERT dbo.AlbumScans VALUES(1,1),(1,2);
INSERT dbo.Shipments(OrderId,Direction,CourierId,Provider,TrackingCode,Status,AddressSnapshot)
VALUES(2,'TO_LAB',6,N'Giao nhận mô phỏng','SHIP-DEMO-001','DELIVERED',N'Địa chỉ nhận mô phỏng');
INSERT dbo.Payments(OrderId,Provider,ProviderRef,Amount,Status,PaidAt)
VALUES(2,'DEMO','PAY-DEMO-FAILED',240000,'FAILED',NULL);
INSERT dbo.Listings(SellerId,Title,Category,Description,AskingPrice,Status) VALUES
(1,N'Canon AE-1 mẫu','CAMERA',N'Tin đăng minh họa',3500000,'ACTIVE'),
(2,N'Ống kính 50mm mẫu','LENS',N'Tin đăng minh họa',1200000,'SOLD'),
(1,N'Film Gold 200 mẫu','FILM',N'Tin đăng minh họa',250000,'ACTIVE');
INSERT dbo.Articles(AuthorId,Title,Body,Status,PublishedAt) VALUES
(5,N'Quy trình tráng C41',N'Nội dung mẫu dùng để minh họa lưu trữ kiến thức; chưa phải kho RAG đã kiểm chứng.','PUBLISHED',SYSUTCDATETIME()),
(5,N'Bảo quản film',N'Bản nháp minh họa.','DRAFT',NULL);
INSERT dbo.ArticleComments(ArticleId,AuthorId,Content) VALUES(1,1,N'Cảm ơn bài chia sẻ mẫu.');
INSERT dbo.Events(OrganizerId,Title,EventType,Location,StartsAt,Capacity) VALUES
(5,N'Workshop nhập môn film','WORKSHOP',N'Địa điểm mô phỏng',DATEADD(day,30,SYSUTCDATETIME()),2),
(5,N'Photowalk mẫu','PHOTOWALK',N'Địa điểm mô phỏng',DATEADD(day,45,SYSUTCDATETIME()),10);
EXEC dbo.usp_RegisterEvent 1,1;
EXEC dbo.usp_RegisterEvent 1,2;
INSERT dbo.AIConversations(UserId) VALUES(1);
INSERT dbo.AIMessages(ConversationId,Speaker,Content,ModelName,SourceArticleId) VALUES
(1,'USER',N'Tráng C41 là gì?',NULL,NULL),
(1,'ASSISTANT',N'Câu trả lời giả lập để kiểm tra cấu trúc lưu hội thoại.','MOCK-NOT-A-REAL-MODEL',1);
INSERT dbo.ScanAssessments(ScanId,ModelVersion,QualityScore,Findings)
VALUES(1,'MOCK-V1',85.00,N'Điểm giả lập, chưa chạy mô hình thị giác máy tính.');
GO
