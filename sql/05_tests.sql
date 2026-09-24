USE FilmLabCoursework;
GO
SET NOCOUNT ON;
-- Each test runs in its own transaction and rolls back. Identity gaps are expected.
DECLARE @Results TABLE(TestId varchar(5),Scenario nvarchar(200),Result varchar(4),ActualError int,Detail nvarchar(2000));

BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'IF (SELECT COUNT(*) FROM sys.tables WHERE is_ms_shipped=0)<>24 THROW 51900,''Expected 24 tables.'',1; IF (SELECT COUNT(*) FROM dbo.Orders)<>5 THROW 51900,''Expected 5 seed orders.'',1;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T01',N'Số lượng bảng và dữ liệu nền','PASS',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T01Error int=ERROR_NUMBER(), @T01Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T01',N'Số lượng bảng và dữ liệu nền',CASE WHEN @T01Error IN (0) THEN 'PASS' ELSE 'FAIL' END,@T01Error,@T01Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'IF (SELECT TotalAmount FROM dbo.v_OrderTotals WHERE OrderId=2)<>240000 THROW 51900,''Incorrect total.'',1;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T02',N'Tổng đơn nhiều cuộn không nhân bản','PASS',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T02Error int=ERROR_NUMBER(), @T02Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T02',N'Tổng đơn nhiều cuộn không nhân bản',CASE WHEN @T02Error IN (0) THEN 'PASS' ELSE 'FAIL' END,@T02Error,@T02Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'IF (SELECT SUM(GrossCollectedVND) FROM dbo.v_MonthlyRevenue)<>160000 THROW 51900,''Incorrect revenue.'',1;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T03',N'Tiền đã thu chỉ tính giao dịch thành công','PASS',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T03Error int=ERROR_NUMBER(), @T03Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T03',N'Tiền đã thu chỉ tính giao dịch thành công',CASE WHEN @T03Error IN (0) THEN 'PASS' ELSE 'FAIL' END,@T03Error,@T03Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'UPDATE dbo.Services SET Price=190000 WHERE ServiceId=1; IF (SELECT UnitPrice FROM dbo.OrderItems WHERE ItemId=1)<>90000 THROW 51900,''Historical price changed.'',1;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T04',N'Giá đơn giữ nguyên khi đổi giá danh mục','PASS',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T04Error int=ERROR_NUMBER(), @T04Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T04',N'Giá đơn giữ nguyên khi đổi giá danh mục',CASE WHEN @T04Error IN (0) THEN 'PASS' ELSE 'FAIL' END,@T04Error,@T04Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'EXEC dbo.usp_RecordPayment 1,''DEMO'',''PAY-DEMO-001'',90000; IF (SELECT COUNT(*) FROM dbo.Payments WHERE ProviderRef=''PAY-DEMO-001'')<>1 THROW 51900,''Duplicate callback.'',1;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T05',N'Callback thanh toán lặp được xử lý idempotent','PASS',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T05Error int=ERROR_NUMBER(), @T05Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T05',N'Callback thanh toán lặp được xử lý idempotent',CASE WHEN @T05Error IN (0) THEN 'PASS' ELSE 'FAIL' END,@T05Error,@T05Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'INSERT dbo.Users(FullName,Email) VALUES(N''Test'',''an@example.test'');';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T06',N'Chặn email trùng','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T06Error int=ERROR_NUMBER(), @T06Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T06',N'Chặn email trùng',CASE WHEN @T06Error IN (2601,2627) THEN 'PASS' ELSE 'FAIL' END,@T06Error,@T06Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'DECLARE @x dbo.OrderInput,@id int; INSERT @x VALUES(N''X'',1,4,NULL,NULL,NULL); EXEC dbo.usp_CreateOrder 1,1,''SELF'',NULL,@x,@id OUTPUT;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T07',N'Chặn dịch vụ thuộc lab khác','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T07Error int=ERROR_NUMBER(), @T07Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T07',N'Chặn dịch vụ thuộc lab khác',CASE WHEN @T07Error IN (51103) THEN 'PASS' ELSE 'FAIL' END,@T07Error,@T07Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'DECLARE @x dbo.OrderInput,@id int; INSERT @x VALUES(N''X'',2,1,NULL,NULL,NULL); EXEC dbo.usp_CreateOrder 1,1,''SELF'',NULL,@x,@id OUTPUT;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T08',N'Chặn quy trình tráng không phù hợp','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T08Error int=ERROR_NUMBER(), @T08Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T08',N'Chặn quy trình tráng không phù hợp',CASE WHEN @T08Error IN (51103) THEN 'PASS' ELSE 'FAIL' END,@T08Error,@T08Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'DECLARE @x dbo.OrderInput,@id int; EXEC dbo.usp_CreateOrder 1,1,''SELF'',NULL,@x,@id OUTPUT;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T09',N'Chặn đơn không có cuộn film','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T09Error int=ERROR_NUMBER(), @T09Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T09',N'Chặn đơn không có cuộn film',CASE WHEN @T09Error IN (51102) THEN 'PASS' ELSE 'FAIL' END,@T09Error,@T09Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'DECLARE @x dbo.OrderInput,@id int; INSERT @x VALUES(N''X'',1,5,NULL,NULL,NULL); EXEC dbo.usp_CreateOrder 1,3,''SELF'',NULL,@x,@id OUTPUT;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T10',N'Chặn lab chưa duyệt','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T10Error int=ERROR_NUMBER(), @T10Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T10',N'Chặn lab chưa duyệt',CASE WHEN @T10Error IN (51101) THEN 'PASS' ELSE 'FAIL' END,@T10Error,@T10Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'EXEC dbo.usp_SetOrderStatus 5,3,''COMPLETED'';';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T11',N'Chặn nhảy trạng thái','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T11Error int=ERROR_NUMBER(), @T11Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T11',N'Chặn nhảy trạng thái',CASE WHEN @T11Error IN (51005) THEN 'PASS' ELSE 'FAIL' END,@T11Error,@T11Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'EXEC dbo.usp_SetOrderStatus 2,4,''DEVELOPING'';';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T12',N'Chặn nhân sự của lab khác','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T12Error int=ERROR_NUMBER(), @T12Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T12',N'Chặn nhân sự của lab khác',CASE WHEN @T12Error IN (51106) THEN 'PASS' ELSE 'FAIL' END,@T12Error,@T12Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'UPDATE dbo.OrderItems SET UnitPrice=1 WHERE OrderId=2;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T13',N'Chặn thay đổi chi tiết đơn đã nhận','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T13Error int=ERROR_NUMBER(), @T13Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T13',N'Chặn thay đổi chi tiết đơn đã nhận',CASE WHEN @T13Error IN (51001) THEN 'PASS' ELSE 'FAIL' END,@T13Error,@T13Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'EXEC dbo.usp_RecordPayment 2,''DEMO'',''WRONG-AMOUNT'',1;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T14',N'Chặn tiền thanh toán sai tổng','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T14Error int=ERROR_NUMBER(), @T14Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T14',N'Chặn tiền thanh toán sai tổng',CASE WHEN @T14Error IN (51011) THEN 'PASS' ELSE 'FAIL' END,@T14Error,@T14Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'EXEC dbo.usp_RecordPayment 1,''DEMO'',''DUP-SUCCESS'',90000;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T15',N'Chặn thành công lần hai với mã khác','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T15Error int=ERROR_NUMBER(), @T15Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T15',N'Chặn thành công lần hai với mã khác',CASE WHEN @T15Error IN (2601,2627) THEN 'PASS' ELSE 'FAIL' END,@T15Error,@T15Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'EXEC dbo.usp_RecordPayment 2,''DEMO'',''PAY-DEMO-001'',90000;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T16',N'Chặn mã giao dịch dùng cho đơn khác','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T16Error int=ERROR_NUMBER(), @T16Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T16',N'Chặn mã giao dịch dùng cho đơn khác',CASE WHEN @T16Error IN (51108) THEN 'PASS' ELSE 'FAIL' END,@T16Error,@T16Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'EXEC dbo.usp_AddReview 2,2,4,N''Test'';';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T17',N'Chặn đánh giá đơn chưa hoàn tất','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T17Error int=ERROR_NUMBER(), @T17Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T17',N'Chặn đánh giá đơn chưa hoàn tất',CASE WHEN @T17Error IN (51012) THEN 'PASS' ELSE 'FAIL' END,@T17Error,@T17Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'DELETE dbo.Reviews WHERE OrderId=3; EXEC dbo.usp_AddReview 3,2,5,N''Test'';';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T18',N'Chặn đánh giá thay người khác','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T18Error int=ERROR_NUMBER(), @T18Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T18',N'Chặn đánh giá thay người khác',CASE WHEN @T18Error IN (547) THEN 'PASS' ELSE 'FAIL' END,@T18Error,@T18Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'UPDATE dbo.Reviews SET Rating=6 WHERE OrderId=1;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T19',N'Chặn số sao ngoài khoảng','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T19Error int=ERROR_NUMBER(), @T19Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T19',N'Chặn số sao ngoài khoảng',CASE WHEN @T19Error IN (547) THEN 'PASS' ELSE 'FAIL' END,@T19Error,@T19Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'INSERT dbo.AlbumScans VALUES(2,1);';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T20',N'Chặn đưa ảnh người khác vào album','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T20Error int=ERROR_NUMBER(), @T20Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T20',N'Chặn đưa ảnh người khác vào album',CASE WHEN @T20Error IN (51013) THEN 'PASS' ELSE 'FAIL' END,@T20Error,@T20Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'UPDATE dbo.Albums SET OwnerId=2 WHERE AlbumId=1;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T21',N'Chặn đổi chủ album để vượt kiểm tra','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T21Error int=ERROR_NUMBER(), @T21Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T21',N'Chặn đổi chủ album để vượt kiểm tra',CASE WHEN @T21Error IN (51014) THEN 'PASS' ELSE 'FAIL' END,@T21Error,@T21Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'EXEC dbo.usp_RegisterEvent 1,5;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T22',N'Chặn đăng ký sự kiện đầy chỗ','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T22Error int=ERROR_NUMBER(), @T22Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T22',N'Chặn đăng ký sự kiện đầy chỗ',CASE WHEN @T22Error IN (51114) THEN 'PASS' ELSE 'FAIL' END,@T22Error,@T22Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'EXEC dbo.usp_RegisterEvent 1,1;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T23',N'Chặn đăng ký sự kiện trùng','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T23Error int=ERROR_NUMBER(), @T23Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T23',N'Chặn đăng ký sự kiện trùng',CASE WHEN @T23Error IN (51113) THEN 'PASS' ELSE 'FAIL' END,@T23Error,@T23Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'INSERT dbo.OrderItems(OrderId,FilmStockId,ServiceId,RollLabel,UnitPrice,ScanRequired,ScanSpecSnapshot) VALUES(5,1,1,N''M1'',90000,1,N''JPEG''),(5,1,4,N''M2'',85000,1,N''JPEG'');';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T24',N'Kiểm tra trigger với nhiều dòng','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T24Error int=ERROR_NUMBER(), @T24Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T24',N'Kiểm tra trigger với nhiều dòng',CASE WHEN @T24Error IN (51002) THEN 'PASS' ELSE 'FAIL' END,@T24Error,@T24Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'UPDATE dbo.Services SET LabId=2 WHERE ServiceId=1;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T25',N'Chặn đổi lab của dịch vụ đã đặt','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T25Error int=ERROR_NUMBER(), @T25Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T25',N'Chặn đổi lab của dịch vụ đã đặt',CASE WHEN @T25Error IN (51017) THEN 'PASS' ELSE 'FAIL' END,@T25Error,@T25Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'EXEC dbo.usp_SetOrderStatus 2,3,''DEVELOPING''; EXEC dbo.usp_SetOrderStatus 2,3,''SCANNING''; EXEC dbo.usp_SetOrderStatus 2,3,''QUALITY_CHECK''; EXEC dbo.usp_SetOrderStatus 2,3,''READY'';';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T26',N'Chặn trả đơn thiếu file scan','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T26Error int=ERROR_NUMBER(), @T26Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T26',N'Chặn trả đơn thiếu file scan',CASE WHEN @T26Error IN (51007) THEN 'PASS' ELSE 'FAIL' END,@T26Error,@T26Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'DECLARE @x dbo.OrderInput,@id int; INSERT @x VALUES(N''TEST-BW'',2,2,NULL,NULL,NULL); EXEC dbo.usp_CreateOrder 1,1,''SELF'',NULL,@x,@id OUTPUT; EXEC dbo.usp_SetOrderStatus @id,3,''CONFIRMED''; EXEC dbo.usp_SetOrderStatus @id,3,''RECEIVED''; EXEC dbo.usp_SetOrderStatus @id,3,''DEVELOPING''; EXEC dbo.usp_SetOrderStatus @id,3,''QUALITY_CHECK''; EXEC dbo.usp_SetOrderStatus @id,3,''READY''; EXEC dbo.usp_SetOrderStatus @id,3,''COMPLETED'';';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T27',N'Chặn hoàn tất khi chưa trả tiền','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T27Error int=ERROR_NUMBER(), @T27Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T27',N'Chặn hoàn tất khi chưa trả tiền',CASE WHEN @T27Error IN (51008) THEN 'PASS' ELSE 'FAIL' END,@T27Error,@T27Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'DECLARE @x dbo.OrderInput,@id int; INSERT @x VALUES(N''TEST-BW'',2,2,NULL,NULL,NULL); EXEC dbo.usp_CreateOrder 1,1,''SELF'',NULL,@x,@id OUTPUT; EXEC dbo.usp_SetOrderStatus @id,3,''CONFIRMED''; EXEC dbo.usp_SetOrderStatus @id,3,''RECEIVED''; EXEC dbo.usp_SetOrderStatus @id,3,''DEVELOPING''; EXEC dbo.usp_SetOrderStatus @id,3,''QUALITY_CHECK''; EXEC dbo.usp_SetOrderStatus @id,3,''READY''; EXEC dbo.usp_RecordPayment @id,''DEMO'',''TEST-FULL-FLOW'',70000; EXEC dbo.usp_SetOrderStatus @id,3,''COMPLETED''; IF (SELECT COUNT(*) FROM dbo.OrderStatusHistory WHERE OrderId=@id)<>7 THROW 51900,''Missing history.'',1;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T28',N'Luồng tráng không scan hoàn chỉnh','PASS',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T28Error int=ERROR_NUMBER(), @T28Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T28',N'Luồng tráng không scan hoàn chỉnh',CASE WHEN @T28Error IN (0) THEN 'PASS' ELSE 'FAIL' END,@T28Error,@T28Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'CREATE USER CourseworkAppTest WITHOUT LOGIN; ALTER ROLE film_app ADD MEMBER CourseworkAppTest; DECLARE @Denied bit=0; EXECUTE AS USER = ''CourseworkAppTest''; BEGIN TRY UPDATE dbo.Orders SET Note=N''Unauthorized update'' WHERE OrderId=5; END TRY BEGIN CATCH IF ERROR_NUMBER()=229 SET @Denied=1; ELSE BEGIN REVERT; THROW; END; END CATCH; REVERT; IF @Denied=0 THROW 51900,''App role could update orders directly.'',1;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T29',N'Vai trò app không được ghi trực tiếp bảng','PASS',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T29Error int=ERROR_NUMBER(), @T29Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T29',N'Vai trò app không được ghi trực tiếp bảng',CASE WHEN @T29Error IN (0) THEN 'PASS' ELSE 'FAIL' END,@T29Error,@T29Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'DELETE dbo.Payments WHERE OrderId=1;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T30',N'Chặn xóa giao dịch thành công','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T30Error int=ERROR_NUMBER(), @T30Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T30',N'Chặn xóa giao dịch thành công',CASE WHEN @T30Error IN (51010) THEN 'PASS' ELSE 'FAIL' END,@T30Error,@T30Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'UPDATE dbo.FilmStocks SET ProcessCode=''BW'' WHERE FilmStockId=1;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T31',N'Chặn đổi quy trình film đã được đặt','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T31Error int=ERROR_NUMBER(), @T31Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T31',N'Chặn đổi quy trình film đã được đặt',CASE WHEN @T31Error IN (51018) THEN 'PASS' ELSE 'FAIL' END,@T31Error,@T31Message);
END CATCH;


BEGIN TRY
 BEGIN TRAN;
 EXEC sys.sp_executesql N'EXEC dbo.usp_RecordPayment 4,''DEMO'',''CANCELLED-PAY'',85000;';
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T32',N'Chặn thanh toán đơn đã hủy','FAIL',0,N'No error');
END TRY
BEGIN CATCH
 DECLARE @T32Error int=ERROR_NUMBER(), @T32Message nvarchar(2000)=ERROR_MESSAGE();
 IF @@TRANCOUNT>0 ROLLBACK;
 INSERT @Results VALUES('T32',N'Chặn thanh toán đơn đã hủy',CASE WHEN @T32Error IN (51011) THEN 'PASS' ELSE 'FAIL' END,@T32Error,@T32Message);
END CATCH;

SELECT * FROM @Results ORDER BY TestId;
IF EXISTS(SELECT 1 FROM @Results WHERE Result='FAIL') THROW 51999,'One or more integration tests failed.',1;
SELECT COUNT(*) AS PassedTests FROM @Results WHERE Result='PASS';
GO
