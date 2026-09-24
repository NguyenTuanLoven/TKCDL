USE FilmLabCoursework;
GO
CREATE OR ALTER VIEW dbo.v_OrderTotals
AS
SELECT o.OrderId,o.CustomerId,o.LabId,o.Status,o.CreatedAt,
       COUNT(i.ItemId) AS RollCount,
       COALESCE(SUM(i.UnitPrice),CONVERT(decimal(12,0),0)) AS TotalAmount
FROM dbo.Orders o LEFT JOIN dbo.OrderItems i ON i.OrderId=o.OrderId
GROUP BY o.OrderId,o.CustomerId,o.LabId,o.Status,o.CreatedAt;
GO
CREATE OR ALTER VIEW dbo.v_LabRatings
AS
SELECT l.LabId,l.LabName,COUNT(r.ReviewId) AS ReviewCount,
       CAST(AVG(CAST(r.Rating AS decimal(4,2))) AS decimal(4,2)) AS AverageRating
FROM dbo.Labs l LEFT JOIN dbo.Orders o ON o.LabId=l.LabId
LEFT JOIN dbo.Reviews r ON r.OrderId=o.OrderId
GROUP BY l.LabId,l.LabName;
GO
CREATE OR ALTER VIEW dbo.v_MonthlyRevenue
AS
SELECT o.LabId,DATEFROMPARTS(YEAR(p.PaidAt),MONTH(p.PaidAt),1) AS RevenueMonth,
       COUNT_BIG(*) AS PaidOrders,SUM(p.Amount) AS GrossCollectedVND
FROM dbo.Payments p JOIN dbo.Orders o ON o.OrderId=p.OrderId
WHERE p.Status='SUCCEEDED'
GROUP BY o.LabId,DATEFROMPARTS(YEAR(p.PaidAt),MONTH(p.PaidAt),1);
GO
-- This is a deterministic SQL baseline, NOT a trained AI model.
CREATE OR ALTER FUNCTION dbo.fn_FindLabs
(@City nvarchar(100),@FilmFormat varchar(10),@ProcessCode varchar(10),@Budget decimal(12,0))
RETURNS TABLE AS RETURN (
    SELECT l.LabId,l.LabName,s.ServiceId,s.ServiceName,s.Price,s.TurnaroundHours,
           r.AverageRating,r.ReviewCount,
           CAST(0.7*COALESCE(r.AverageRating,3.0)/5.0
              +0.3*(1.0-CAST(s.Price AS decimal(18,6))/NULLIF(@Budget,0))
              AS decimal(8,4)) AS BaselineScore
    FROM dbo.Labs l JOIN dbo.Services s ON s.LabId=l.LabId
    JOIN dbo.v_LabRatings r ON r.LabId=l.LabId
    WHERE l.ApprovalStatus='APPROVED' AND l.City=@City
      AND s.IsActive=1 AND s.FilmFormat=@FilmFormat AND s.ProcessCode=@ProcessCode
      AND s.Price<=@Budget AND @Budget>0
);
GO
CREATE OR ALTER TRIGGER dbo.tr_OrderItems_Validate ON dbo.OrderItems
AFTER INSERT,UPDATE,DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (
      SELECT 1 FROM (SELECT OrderId FROM inserted UNION SELECT OrderId FROM deleted) x
      JOIN dbo.Orders o WITH(UPDLOCK,HOLDLOCK) ON o.OrderId=x.OrderId
      WHERE o.Status<>'CREATED'
    ) THROW 51001,'Order items are immutable after confirmation.',1;
    IF EXISTS (
      SELECT 1 FROM inserted i JOIN dbo.Orders o ON o.OrderId=i.OrderId
      JOIN dbo.Services s ON s.ServiceId=i.ServiceId
      JOIN dbo.FilmStocks f ON f.FilmStockId=i.FilmStockId
      WHERE s.LabId<>o.LabId OR s.FilmFormat<>f.FilmFormat
         OR s.ProcessCode<>f.ProcessCode OR s.IsActive=0
    ) THROW 51002,'Service must belong to the order lab and support the film.',1;
END;
GO
CREATE OR ALTER TRIGGER dbo.tr_Orders_Transition ON dbo.Orders
AFTER INSERT,UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(SELECT 1 FROM inserted i LEFT JOIN deleted d ON d.OrderId=i.OrderId
              WHERE d.OrderId IS NULL AND i.Status<>'CREATED')
      THROW 51003,'New orders must start in CREATED.',1;
    IF EXISTS(SELECT 1 FROM inserted i JOIN deleted d ON i.OrderId=d.OrderId
              WHERE i.CustomerId<>d.CustomerId OR i.LabId<>d.LabId)
      THROW 51004,'The customer and lab of an order cannot change.',1;
    IF EXISTS (
      SELECT 1 FROM inserted i JOIN deleted d ON i.OrderId=d.OrderId
      WHERE i.Status<>d.Status AND NOT (
        (d.Status='CREATED' AND i.Status IN ('CONFIRMED','CANCELLED')) OR
        (d.Status='CONFIRMED' AND i.Status IN ('RECEIVED','CANCELLED')) OR
        (d.Status='RECEIVED' AND i.Status='DEVELOPING') OR
        (d.Status='DEVELOPING' AND i.Status='SCANNING'
          AND EXISTS(SELECT 1 FROM dbo.OrderItems x WHERE x.OrderId=i.OrderId AND x.ScanRequired=1)) OR
        (d.Status='DEVELOPING' AND i.Status='QUALITY_CHECK'
          AND NOT EXISTS(SELECT 1 FROM dbo.OrderItems x WHERE x.OrderId=i.OrderId AND x.ScanRequired=1)) OR
        (d.Status='SCANNING' AND i.Status='QUALITY_CHECK') OR
        (d.Status='QUALITY_CHECK' AND i.Status='READY') OR
        (d.Status='READY' AND i.Status='COMPLETED')
      )
    ) THROW 51005,'Illegal order status transition.',1;
    IF EXISTS(SELECT 1 FROM inserted i WHERE i.Status='CONFIRMED'
              AND NOT EXISTS(SELECT 1 FROM dbo.OrderItems x WHERE x.OrderId=i.OrderId))
      THROW 51006,'An order must contain at least one film roll.',1;
    IF EXISTS(SELECT 1 FROM inserted i WHERE i.Status IN ('READY','COMPLETED')
      AND EXISTS(SELECT 1 FROM dbo.OrderItems x WHERE x.OrderId=i.OrderId AND x.ScanRequired=1
         AND NOT EXISTS(SELECT 1 FROM dbo.Scans s WHERE s.ItemId=x.ItemId)))
      THROW 51007,'Each scan-required roll must have at least one scan.',1;
    IF EXISTS(SELECT 1 FROM inserted i WHERE i.Status='COMPLETED'
      AND NOT EXISTS(SELECT 1 FROM dbo.Payments p WHERE p.OrderId=i.OrderId AND p.Status='SUCCEEDED'))
      THROW 51008,'Payment is required before completion.',1;
    IF EXISTS(SELECT 1 FROM inserted i WHERE i.Status='CANCELLED'
      AND EXISTS(SELECT 1 FROM dbo.Payments p WHERE p.OrderId=i.OrderId AND p.Status='SUCCEEDED'))
      THROW 51009,'Paid orders require a refund flow; cancellation is blocked in this scope.',1;
END;
GO
CREATE OR ALTER TRIGGER dbo.tr_Payments_Validate ON dbo.Payments
AFTER INSERT,UPDATE,DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(SELECT 1 FROM deleted WHERE Status='SUCCEEDED')
      THROW 51010,'Successful payments are immutable; use a future refund ledger.',1;
    IF EXISTS(
      SELECT 1 FROM inserted p JOIN dbo.Orders o WITH(UPDLOCK,HOLDLOCK) ON o.OrderId=p.OrderId
      JOIN dbo.v_OrderTotals t ON t.OrderId=o.OrderId
      WHERE p.Status='SUCCEEDED' AND
      (o.Status IN ('CREATED','CANCELLED') OR p.Amount<>t.TotalAmount OR t.RollCount=0)
    ) THROW 51011,'A successful payment must equal the total of a confirmed, non-cancelled order.',1;
END;
GO
CREATE OR ALTER TRIGGER dbo.tr_Reviews_Completed ON dbo.Reviews
AFTER INSERT,UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(SELECT 1 FROM inserted r JOIN dbo.Orders o ON o.OrderId=r.OrderId WHERE o.Status<>'COMPLETED')
      THROW 51012,'Only completed orders can be reviewed.',1;
END;
GO
CREATE OR ALTER TRIGGER dbo.tr_AlbumScans_Owner ON dbo.AlbumScans
AFTER INSERT,UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(SELECT 1 FROM inserted x
      JOIN dbo.Albums a ON a.AlbumId=x.AlbumId
      JOIN dbo.Scans s ON s.ScanId=x.ScanId
      JOIN dbo.OrderItems i ON i.ItemId=s.ItemId
      JOIN dbo.Orders o ON o.OrderId=i.OrderId WHERE a.OwnerId<>o.CustomerId)
      THROW 51013,'An album may only contain scans owned by its owner.',1;
END;
GO
CREATE OR ALTER TRIGGER dbo.tr_Albums_OwnerImmutable ON dbo.Albums
AFTER UPDATE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(SELECT 1 FROM inserted i JOIN deleted d ON d.AlbumId=i.AlbumId WHERE i.OwnerId<>d.OwnerId)
      THROW 51014,'Album ownership cannot change.',1;
END;
GO
CREATE OR ALTER TRIGGER dbo.tr_Scans_ImmutableLink ON dbo.Scans
AFTER UPDATE,DELETE AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS(SELECT 1 FROM inserted i JOIN deleted d ON d.ScanId=i.ScanId WHERE i.ItemId<>d.ItemId)
      THROW 51015,'A scan cannot be reassigned to another roll.',1;
    IF EXISTS(SELECT 1 FROM deleted d
      JOIN dbo.OrderItems i ON i.ItemId=d.ItemId JOIN dbo.Orders o ON o.OrderId=i.OrderId
      WHERE o.Status IN ('READY','COMPLETED')
        AND NOT EXISTS(SELECT 1 FROM inserted n WHERE n.ScanId=d.ScanId))
      THROW 51016,'Delivered scans cannot be deleted in this coursework.',1;
END;
GO
CREATE TYPE dbo.OrderInput AS TABLE (
    RollLabel nvarchar(60) NOT NULL PRIMARY KEY,
    FilmStockId int NOT NULL,
    ServiceId int NOT NULL,
    CameraModel nvarchar(120) NULL,
    Lens nvarchar(120) NULL,
    ShotDate date NULL
);
GO
-- Caller identity parameters must be supplied by a trusted backend, never directly trusted from clients.
CREATE OR ALTER PROCEDURE dbo.usp_CreateOrder
    @CustomerId int,@LabId int,@DeliveryMethod varchar(10),
    @DeliveryAddress nvarchar(300),@Items dbo.OrderInput READONLY,@OrderId int OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
      BEGIN TRAN;
      IF NOT EXISTS(SELECT 1 FROM dbo.Users u JOIN dbo.UserRoles r ON r.UserId=u.UserId
         WHERE u.UserId=@CustomerId AND u.IsActive=1 AND r.RoleCode='CUSTOMER')
        THROW 51100,'Active customer role is required.',1;
      IF NOT EXISTS(SELECT 1 FROM dbo.Labs WITH(HOLDLOCK) WHERE LabId=@LabId AND ApprovalStatus='APPROVED')
        THROW 51101,'Lab must be approved.',1;
      IF NOT EXISTS(SELECT 1 FROM @Items) THROW 51102,'At least one roll is required.',1;
      IF EXISTS(SELECT 1 FROM @Items x LEFT JOIN dbo.Services s WITH(HOLDLOCK) ON s.ServiceId=x.ServiceId
         LEFT JOIN dbo.FilmStocks f ON f.FilmStockId=x.FilmStockId
         WHERE s.ServiceId IS NULL OR f.FilmStockId IS NULL OR s.LabId<>@LabId
            OR s.IsActive=0 OR s.FilmFormat<>f.FilmFormat OR s.ProcessCode<>f.ProcessCode)
        THROW 51103,'An item has an invalid lab, service or film type.',1;
      INSERT dbo.Orders(CustomerId,LabId,DeliveryMethod,DeliveryAddress)
      VALUES(@CustomerId,@LabId,@DeliveryMethod,@DeliveryAddress);
      SET @OrderId=CONVERT(int,SCOPE_IDENTITY());
      INSERT dbo.OrderItems(OrderId,FilmStockId,ServiceId,RollLabel,UnitPrice,ScanRequired,ScanSpecSnapshot,CameraModel,Lens,ShotDate)
      SELECT @OrderId,x.FilmStockId,x.ServiceId,x.RollLabel,s.Price,s.IncludesScan,s.ScanSpec,x.CameraModel,x.Lens,x.ShotDate
      FROM @Items x JOIN dbo.Services s ON s.ServiceId=x.ServiceId;
      INSERT dbo.OrderStatusHistory(OrderId,FromStatus,ToStatus,ChangedBy,Note)
      VALUES(@OrderId,NULL,'CREATED',@CustomerId,N'Tạo đơn');
      COMMIT;
    END TRY
    BEGIN CATCH
      IF XACT_STATE()<>0 ROLLBACK;
      THROW;
    END CATCH
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_SetOrderStatus
    @OrderId int,@ActorId int,@NewStatus varchar(15),@Note nvarchar(300)=NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
      BEGIN TRAN;
      DECLARE @Old varchar(15),@LabId int,@CustomerId int;
      SELECT @Old=Status,@LabId=LabId,@CustomerId=CustomerId
      FROM dbo.Orders WITH(UPDLOCK,HOLDLOCK) WHERE OrderId=@OrderId;
      IF @Old IS NULL THROW 51104,'Order not found.',1;
      IF NOT EXISTS(SELECT 1 FROM dbo.Users WHERE UserId=@ActorId AND IsActive=1)
        THROW 51105,'Actor must be active.',1;
      IF NOT (
        EXISTS(SELECT 1 FROM dbo.UserRoles WHERE UserId=@ActorId AND RoleCode='ADMIN') OR
        EXISTS(SELECT 1 FROM dbo.Labs WHERE LabId=@LabId AND OwnerId=@ActorId) OR
        EXISTS(SELECT 1 FROM dbo.LabMembers WHERE LabId=@LabId AND UserId=@ActorId) OR
        (@ActorId=@CustomerId AND @NewStatus='CANCELLED' AND @Old IN ('CREATED','CONFIRMED'))
      ) THROW 51106,'Actor has no permission for this lab/order.',1;
      IF @Old=@NewStatus THROW 51107,'Order already has this status.',1;
      UPDATE dbo.Orders SET Status=@NewStatus,UpdatedAt=SYSUTCDATETIME() WHERE OrderId=@OrderId;
      INSERT dbo.OrderStatusHistory(OrderId,FromStatus,ToStatus,ChangedBy,Note)
      VALUES(@OrderId,@Old,@NewStatus,@ActorId,@Note);
      COMMIT;
    END TRY
    BEGIN CATCH
      IF XACT_STATE()<>0 ROLLBACK;
      THROW;
    END CATCH
END;
GO
-- Only the payment-service DB role may execute this. Verify webhook signature upstream.
CREATE OR ALTER PROCEDURE dbo.usp_RecordPayment
    @OrderId int,@Provider varchar(30),@ProviderRef varchar(100),@Amount decimal(12,0)
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
      BEGIN TRAN;
      DECLARE @ExistingId bigint,@LockedOrder int;
      SELECT @LockedOrder=OrderId FROM dbo.Orders WITH(UPDLOCK,HOLDLOCK) WHERE OrderId=@OrderId;
      IF @LockedOrder IS NULL THROW 51104,'Order not found.',1;
      SELECT @ExistingId=PaymentId FROM dbo.Payments WITH(UPDLOCK,HOLDLOCK)
      WHERE Provider=@Provider AND ProviderRef=@ProviderRef;
      IF @ExistingId IS NOT NULL
      BEGIN
        IF NOT EXISTS(SELECT 1 FROM dbo.Payments WHERE PaymentId=@ExistingId AND OrderId=@OrderId
                       AND Amount=@Amount AND Status='SUCCEEDED')
          THROW 51108,'Payment reference conflicts with an existing transaction.',1;
        COMMIT;
        RETURN;
      END;
      INSERT dbo.Payments(OrderId,Provider,ProviderRef,Amount,Status,PaidAt)
      VALUES(@OrderId,@Provider,@ProviderRef,@Amount,'SUCCEEDED',SYSUTCDATETIME());
      COMMIT;
    END TRY
    BEGIN CATCH
      IF XACT_STATE()<>0 ROLLBACK;
      THROW;
    END CATCH
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_AddScan
    @OrderId int,@ItemId int,@ActorId int,@FrameNo smallint,@VersionNo smallint,
    @ObjectKey varchar(400),@MimeType varchar(30),@FileSizeBytes bigint
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
      BEGIN TRAN;
      DECLARE @LabId int,@Status varchar(15);
      SELECT @LabId=LabId,@Status=Status FROM dbo.Orders WITH(UPDLOCK,HOLDLOCK) WHERE OrderId=@OrderId;
      IF @Status IS NULL OR @Status NOT IN ('SCANNING','QUALITY_CHECK')
        THROW 51109,'Scans may be uploaded during scanning or quality check.',1;
      IF NOT EXISTS(SELECT 1 FROM dbo.Users WHERE UserId=@ActorId AND IsActive=1)
        THROW 51105,'Actor must be active.',1;
      IF NOT(EXISTS(SELECT 1 FROM dbo.Labs WHERE LabId=@LabId AND OwnerId=@ActorId) OR
             EXISTS(SELECT 1 FROM dbo.LabMembers WHERE LabId=@LabId AND UserId=@ActorId) OR
             EXISTS(SELECT 1 FROM dbo.UserRoles WHERE UserId=@ActorId AND RoleCode='ADMIN'))
        THROW 51106,'Actor has no permission for this lab/order.',1;
      IF NOT EXISTS(SELECT 1 FROM dbo.OrderItems WHERE ItemId=@ItemId AND OrderId=@OrderId AND ScanRequired=1)
        THROW 51110,'The roll must belong to the order and require scans.',1;
      INSERT dbo.Scans(ItemId,FrameNo,VersionNo,ObjectKey,MimeType,FileSizeBytes)
      VALUES(@ItemId,@FrameNo,@VersionNo,@ObjectKey,@MimeType,@FileSizeBytes);
      COMMIT;
    END TRY
    BEGIN CATCH
      IF XACT_STATE()<>0 ROLLBACK;
      THROW;
    END CATCH
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_AddReview
    @OrderId int,@CustomerId int,@Rating tinyint,@Content nvarchar(1000)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    INSERT dbo.Reviews(OrderId,CustomerId,Rating,Content) VALUES(@OrderId,@CustomerId,@Rating,@Content);
END;
GO
CREATE OR ALTER PROCEDURE dbo.usp_RegisterEvent @EventId int,@UserId int
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    BEGIN TRY
      BEGIN TRAN;
      DECLARE @Capacity int,@StartsAt datetime2(0);
      SELECT @Capacity=Capacity,@StartsAt=StartsAt FROM dbo.Events WITH(UPDLOCK,HOLDLOCK) WHERE EventId=@EventId;
      IF @Capacity IS NULL THROW 51111,'Event not found.',1;
      IF @StartsAt<=SYSUTCDATETIME() THROW 51112,'Registration is closed.',1;
      IF NOT EXISTS(SELECT 1 FROM dbo.Users WHERE UserId=@UserId AND IsActive=1)
        THROW 51105,'User must be active.',1;
      IF EXISTS(SELECT 1 FROM dbo.EventRegistrations WHERE EventId=@EventId AND UserId=@UserId)
        THROW 51113,'User has already registered.',1;
      IF (SELECT COUNT(*) FROM dbo.EventRegistrations WHERE EventId=@EventId)>=@Capacity
        THROW 51114,'The event is full.',1;
      INSERT dbo.EventRegistrations(EventId,UserId) VALUES(@EventId,@UserId);
      COMMIT;
    END TRY
    BEGIN CATCH
      IF XACT_STATE()<>0 ROLLBACK;
      THROW;
    END CATCH
END;
GO
CREATE ROLE film_app AUTHORIZATION dbo;
CREATE ROLE film_payment_service AUTHORIZATION dbo;
GRANT EXECUTE ON dbo.usp_CreateOrder TO film_app;
GRANT EXECUTE ON dbo.usp_SetOrderStatus TO film_app;
GRANT EXECUTE ON dbo.usp_AddScan TO film_app;
GRANT EXECUTE ON dbo.usp_AddReview TO film_app;
GRANT EXECUTE ON dbo.usp_RegisterEvent TO film_app;
GRANT EXECUTE ON TYPE::dbo.OrderInput TO film_app;
GRANT REFERENCES ON TYPE::dbo.OrderInput TO film_app;
GRANT EXECUTE ON dbo.usp_RecordPayment TO film_payment_service;
-- No direct table DML/blanket SELECT grants to app roles.
-- Owner-scoped read APIs and JWT/OAuth are future backend work.
GO
USE FilmLabCoursework;
GO
-- Catalog changes must not break the meaning of already booked rolls.
CREATE OR ALTER TRIGGER dbo.tr_Services_IdentityImmutable ON dbo.Services
AFTER UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN deleted d ON d.ServiceId=i.ServiceId
   WHERE (i.LabId<>d.LabId OR i.FilmFormat<>d.FilmFormat OR i.ProcessCode<>d.ProcessCode)
   AND EXISTS(SELECT 1 FROM dbo.OrderItems x WHERE x.ServiceId=i.ServiceId))
   THROW 51017,'Create a new service instead of reassigning a booked service.',1;
END;
GO
CREATE OR ALTER TRIGGER dbo.tr_FilmStocks_IdentityImmutable ON dbo.FilmStocks
AFTER UPDATE AS
BEGIN
 SET NOCOUNT ON;
 IF EXISTS(SELECT 1 FROM inserted i JOIN deleted d ON d.FilmStockId=i.FilmStockId
   WHERE (i.FilmFormat<>d.FilmFormat OR i.ProcessCode<>d.ProcessCode)
   AND EXISTS(SELECT 1 FROM dbo.OrderItems x WHERE x.FilmStockId=i.FilmStockId))
   THROW 51018,'The format/process of a referenced film stock cannot change.',1;
END;
GO
