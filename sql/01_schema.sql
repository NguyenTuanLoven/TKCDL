USE FilmLabCoursework;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
CREATE TABLE dbo.Roles (
    RoleCode varchar(20) NOT NULL CONSTRAINT PK_Roles PRIMARY KEY,
    RoleName nvarchar(100) NOT NULL
);
CREATE TABLE dbo.Users (
    UserId int IDENTITY(1,1) CONSTRAINT PK_Users PRIMARY KEY,
    FullName nvarchar(120) NOT NULL,
    Email varchar(254) NOT NULL CONSTRAINT UQ_Users_Email UNIQUE,
    Phone varchar(20) NULL,
    IsActive bit NOT NULL CONSTRAINT DF_Users_Active DEFAULT 1,
    CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_Users_Created DEFAULT SYSUTCDATETIME()
);
-- Authentication is delegated to an external identity provider in this coursework.
CREATE TABLE dbo.UserRoles (
    UserId int NOT NULL CONSTRAINT FK_UserRoles_User REFERENCES dbo.Users(UserId),
    RoleCode varchar(20) NOT NULL CONSTRAINT FK_UserRoles_Role REFERENCES dbo.Roles(RoleCode),
    CONSTRAINT PK_UserRoles PRIMARY KEY(UserId, RoleCode)
);
CREATE TABLE dbo.Labs (
    LabId int IDENTITY(1,1) CONSTRAINT PK_Labs PRIMARY KEY,
    OwnerId int NOT NULL CONSTRAINT FK_Labs_Owner REFERENCES dbo.Users(UserId),
    LabName nvarchar(150) NOT NULL,
    City nvarchar(100) NOT NULL,
    Address nvarchar(300) NOT NULL,
    ApprovalStatus varchar(12) NOT NULL CONSTRAINT DF_Labs_Status DEFAULT 'PENDING',
    CONSTRAINT CK_Labs_Status CHECK(ApprovalStatus IN ('PENDING','APPROVED','SUSPENDED'))
);
CREATE TABLE dbo.LabMembers (
    LabId int NOT NULL CONSTRAINT FK_LabMembers_Lab REFERENCES dbo.Labs(LabId),
    UserId int NOT NULL CONSTRAINT FK_LabMembers_User REFERENCES dbo.Users(UserId),
    MemberRole varchar(10) NOT NULL,
    CONSTRAINT PK_LabMembers PRIMARY KEY(LabId,UserId),
    CONSTRAINT CK_LabMembers_Role CHECK(MemberRole IN ('MANAGER','STAFF'))
);
CREATE TABLE dbo.FilmStocks (
    FilmStockId int IDENTITY(1,1) CONSTRAINT PK_FilmStocks PRIMARY KEY,
    StockName nvarchar(120) NOT NULL,
    FilmFormat varchar(10) NOT NULL,
    ProcessCode varchar(10) NOT NULL,
    ISO smallint NOT NULL,
    CONSTRAINT UQ_FilmStocks UNIQUE(StockName,FilmFormat),
    CONSTRAINT CK_FilmStocks_Format CHECK(FilmFormat IN ('35MM','120','4X5')),
    CONSTRAINT CK_FilmStocks_Process CHECK(ProcessCode IN ('C41','BW','E6')),
    CONSTRAINT CK_FilmStocks_ISO CHECK(ISO BETWEEN 1 AND 25600)
);
CREATE TABLE dbo.Services (
    ServiceId int IDENTITY(1,1) CONSTRAINT PK_Services PRIMARY KEY,
    LabId int NOT NULL CONSTRAINT FK_Services_Lab REFERENCES dbo.Labs(LabId),
    ServiceName nvarchar(150) NOT NULL,
    FilmFormat varchar(10) NOT NULL,
    ProcessCode varchar(10) NOT NULL,
    IncludesScan bit NOT NULL,
    ScanSpec nvarchar(100) NULL,
    Price decimal(12,0) NOT NULL,
    TurnaroundHours smallint NOT NULL,
    IsActive bit NOT NULL CONSTRAINT DF_Services_Active DEFAULT 1,
    CONSTRAINT CK_Services_Price CHECK(Price > 0),
    CONSTRAINT CK_Services_Time CHECK(TurnaroundHours > 0),
    CONSTRAINT CK_Services_Format CHECK(FilmFormat IN ('35MM','120','4X5')),
    CONSTRAINT CK_Services_Process CHECK(ProcessCode IN ('C41','BW','E6')),
    CONSTRAINT CK_Services_Scan CHECK((IncludesScan=0 AND ScanSpec IS NULL) OR (IncludesScan=1 AND ScanSpec IS NOT NULL))
);
CREATE TABLE dbo.Orders (
    OrderId int IDENTITY(1,1) CONSTRAINT PK_Orders PRIMARY KEY,
    CustomerId int NOT NULL CONSTRAINT FK_Orders_Customer REFERENCES dbo.Users(UserId),
    LabId int NOT NULL CONSTRAINT FK_Orders_Lab REFERENCES dbo.Labs(LabId),
    Status varchar(15) NOT NULL CONSTRAINT DF_Orders_Status DEFAULT 'CREATED',
    DeliveryMethod varchar(10) NOT NULL,
    DeliveryAddress nvarchar(300) NULL,
    Note nvarchar(500) NULL,
    CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_Orders_Created DEFAULT SYSUTCDATETIME(),
    UpdatedAt datetime2(0) NOT NULL CONSTRAINT DF_Orders_Updated DEFAULT SYSUTCDATETIME(),
    Version rowversion NOT NULL,
    CONSTRAINT UQ_Orders_Customer UNIQUE(OrderId,CustomerId),
    CONSTRAINT CK_Orders_Status CHECK(Status IN ('CREATED','CONFIRMED','RECEIVED','DEVELOPING','SCANNING','QUALITY_CHECK','READY','COMPLETED','CANCELLED')),
    CONSTRAINT CK_Orders_Delivery CHECK((DeliveryMethod='SELF' AND DeliveryAddress IS NULL) OR (DeliveryMethod='COURIER' AND DeliveryAddress IS NOT NULL))
);
-- One row represents ONE physical film roll and its chosen package.
CREATE TABLE dbo.OrderItems (
    ItemId int IDENTITY(1,1) CONSTRAINT PK_OrderItems PRIMARY KEY,
    OrderId int NOT NULL CONSTRAINT FK_OrderItems_Order REFERENCES dbo.Orders(OrderId),
    FilmStockId int NOT NULL CONSTRAINT FK_OrderItems_Stock REFERENCES dbo.FilmStocks(FilmStockId),
    ServiceId int NOT NULL CONSTRAINT FK_OrderItems_Service REFERENCES dbo.Services(ServiceId),
    RollLabel nvarchar(60) NOT NULL,
    UnitPrice decimal(12,0) NOT NULL,
    ScanRequired bit NOT NULL,
    ScanSpecSnapshot nvarchar(100) NULL,
    CameraModel nvarchar(120) NULL,
    Lens nvarchar(120) NULL,
    ShotDate date NULL,
    CONSTRAINT UQ_OrderItems_Roll UNIQUE(OrderId,RollLabel),
    CONSTRAINT CK_OrderItems_Price CHECK(UnitPrice > 0),
    CONSTRAINT CK_OrderItems_Scan CHECK((ScanRequired=0 AND ScanSpecSnapshot IS NULL) OR (ScanRequired=1 AND ScanSpecSnapshot IS NOT NULL))
);
CREATE TABLE dbo.OrderStatusHistory (
    HistoryId bigint IDENTITY(1,1) CONSTRAINT PK_OrderStatusHistory PRIMARY KEY,
    OrderId int NOT NULL CONSTRAINT FK_History_Order REFERENCES dbo.Orders(OrderId),
    FromStatus varchar(15) NULL,
    ToStatus varchar(15) NOT NULL,
    ChangedBy int NOT NULL CONSTRAINT FK_History_User REFERENCES dbo.Users(UserId),
    ChangedAt datetime2(0) NOT NULL CONSTRAINT DF_History_At DEFAULT SYSUTCDATETIME(),
    Note nvarchar(300) NULL,
    CONSTRAINT CK_History_From CHECK(FromStatus IS NULL OR FromStatus IN ('CREATED','CONFIRMED','RECEIVED','DEVELOPING','SCANNING','QUALITY_CHECK','READY','COMPLETED','CANCELLED')),
    CONSTRAINT CK_History_To CHECK(ToStatus IN ('CREATED','CONFIRMED','RECEIVED','DEVELOPING','SCANNING','QUALITY_CHECK','READY','COMPLETED','CANCELLED'))
);
CREATE TABLE dbo.Scans (
    ScanId bigint IDENTITY(1,1) CONSTRAINT PK_Scans PRIMARY KEY,
    ItemId int NOT NULL CONSTRAINT FK_Scans_Item REFERENCES dbo.OrderItems(ItemId),
    FrameNo smallint NOT NULL,
    VersionNo smallint NOT NULL CONSTRAINT DF_Scans_Version DEFAULT 1,
    ObjectKey varchar(400) NOT NULL CONSTRAINT UQ_Scans_Object UNIQUE,
    MimeType varchar(30) NOT NULL,
    FileSizeBytes bigint NOT NULL,
    UploadedAt datetime2(0) NOT NULL CONSTRAINT DF_Scans_Upload DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Scans_Frame UNIQUE(ItemId,FrameNo,VersionNo),
    CONSTRAINT CK_Scans_Frame CHECK(FrameNo > 0 AND VersionNo > 0),
    CONSTRAINT CK_Scans_Size CHECK(FileSizeBytes > 0),
    CONSTRAINT CK_Scans_Mime CHECK(MimeType IN ('image/jpeg','image/tiff','image/png'))
);
CREATE TABLE dbo.Albums (
    AlbumId int IDENTITY(1,1) CONSTRAINT PK_Albums PRIMARY KEY,
    OwnerId int NOT NULL CONSTRAINT FK_Albums_Owner REFERENCES dbo.Users(UserId),
    AlbumName nvarchar(150) NOT NULL,
    CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_Albums_Created DEFAULT SYSUTCDATETIME()
);
CREATE TABLE dbo.AlbumScans (
    AlbumId int NOT NULL CONSTRAINT FK_AlbumScans_Album REFERENCES dbo.Albums(AlbumId),
    ScanId bigint NOT NULL CONSTRAINT FK_AlbumScans_Scan REFERENCES dbo.Scans(ScanId),
    CONSTRAINT PK_AlbumScans PRIMARY KEY(AlbumId,ScanId)
);
CREATE TABLE dbo.Payments (
    PaymentId bigint IDENTITY(1,1) CONSTRAINT PK_Payments PRIMARY KEY,
    OrderId int NOT NULL CONSTRAINT FK_Payments_Order REFERENCES dbo.Orders(OrderId),
    Provider varchar(30) NOT NULL,
    ProviderRef varchar(100) NOT NULL,
    Amount decimal(12,0) NOT NULL,
    Status varchar(10) NOT NULL,
    PaidAt datetime2(0) NULL,
    CONSTRAINT UQ_Payments_Ref UNIQUE(Provider,ProviderRef),
    CONSTRAINT CK_Payments_Amount CHECK(Amount > 0),
    CONSTRAINT CK_Payments_Status CHECK((Status='SUCCEEDED' AND PaidAt IS NOT NULL) OR (Status IN ('PENDING','FAILED') AND PaidAt IS NULL))
);
CREATE UNIQUE INDEX UX_Payments_OneSuccess ON dbo.Payments(OrderId) WHERE Status='SUCCEEDED';
CREATE TABLE dbo.Shipments (
    ShipmentId int IDENTITY(1,1) CONSTRAINT PK_Shipments PRIMARY KEY,
    OrderId int NOT NULL CONSTRAINT FK_Shipments_Order REFERENCES dbo.Orders(OrderId),
    Direction varchar(8) NOT NULL,
    CourierId int NULL CONSTRAINT FK_Shipments_Courier REFERENCES dbo.Users(UserId),
    Provider nvarchar(80) NOT NULL,
    TrackingCode varchar(100) NULL,
    Status varchar(12) NOT NULL,
    AddressSnapshot nvarchar(300) NOT NULL,
    UpdatedAt datetime2(0) NOT NULL CONSTRAINT DF_Shipments_At DEFAULT SYSUTCDATETIME(),
    CONSTRAINT UQ_Shipments_Direction UNIQUE(OrderId,Direction),
    CONSTRAINT CK_Shipments_Direction CHECK(Direction IN ('TO_LAB','RETURN')),
    CONSTRAINT CK_Shipments_Status CHECK(Status IN ('REQUESTED','PICKED_UP','DELIVERED','CANCELLED'))
);
CREATE TABLE dbo.Reviews (
    ReviewId int IDENTITY(1,1) CONSTRAINT PK_Reviews PRIMARY KEY,
    OrderId int NOT NULL CONSTRAINT UQ_Reviews_Order UNIQUE,
    CustomerId int NOT NULL,
    Rating tinyint NOT NULL,
    Content nvarchar(1000) NULL,
    CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_Reviews_At DEFAULT SYSUTCDATETIME(),
    CONSTRAINT FK_Reviews_OrderCustomer FOREIGN KEY(OrderId,CustomerId) REFERENCES dbo.Orders(OrderId,CustomerId),
    CONSTRAINT CK_Reviews_Rating CHECK(Rating BETWEEN 1 AND 5)
);
-- Extension modules: persisted data only; not a complete commerce/community/AI application.
CREATE TABLE dbo.Listings (
    ListingId int IDENTITY(1,1) CONSTRAINT PK_Listings PRIMARY KEY,
    SellerId int NOT NULL CONSTRAINT FK_Listings_Seller REFERENCES dbo.Users(UserId),
    Title nvarchar(200) NOT NULL,
    Category varchar(15) NOT NULL,
    Description nvarchar(max) NULL,
    AskingPrice decimal(12,0) NOT NULL,
    Status varchar(10) NOT NULL,
    CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_Listings_At DEFAULT SYSUTCDATETIME(),
    CONSTRAINT CK_Listings_Price CHECK(AskingPrice >= 0),
    CONSTRAINT CK_Listings_Category CHECK(Category IN ('CAMERA','LENS','FILM','ACCESSORY')),
    CONSTRAINT CK_Listings_Status CHECK(Status IN ('DRAFT','ACTIVE','SOLD','HIDDEN'))
);
CREATE TABLE dbo.Articles (
    ArticleId int IDENTITY(1,1) CONSTRAINT PK_Articles PRIMARY KEY,
    AuthorId int NOT NULL CONSTRAINT FK_Articles_Author REFERENCES dbo.Users(UserId),
    Title nvarchar(200) NOT NULL,
    Body nvarchar(max) NOT NULL,
    Status varchar(10) NOT NULL,
    PublishedAt datetime2(0) NULL,
    CONSTRAINT CK_Articles_Status CHECK((Status='PUBLISHED' AND PublishedAt IS NOT NULL) OR (Status IN ('DRAFT','HIDDEN') AND PublishedAt IS NULL))
);
CREATE TABLE dbo.ArticleComments (
    CommentId bigint IDENTITY(1,1) CONSTRAINT PK_ArticleComments PRIMARY KEY,
    ArticleId int NOT NULL CONSTRAINT FK_Comments_Article REFERENCES dbo.Articles(ArticleId),
    AuthorId int NOT NULL CONSTRAINT FK_Comments_Author REFERENCES dbo.Users(UserId),
    Content nvarchar(2000) NOT NULL,
    CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_Comments_At DEFAULT SYSUTCDATETIME()
);
CREATE TABLE dbo.Events (
    EventId int IDENTITY(1,1) CONSTRAINT PK_Events PRIMARY KEY,
    OrganizerId int NOT NULL CONSTRAINT FK_Events_Organizer REFERENCES dbo.Users(UserId),
    Title nvarchar(200) NOT NULL,
    EventType varchar(10) NOT NULL,
    Location nvarchar(250) NOT NULL,
    StartsAt datetime2(0) NOT NULL,
    Capacity int NOT NULL,
    CONSTRAINT CK_Events_Type CHECK(EventType IN ('WORKSHOP','PHOTOWALK')),
    CONSTRAINT CK_Events_Capacity CHECK(Capacity > 0)
);
CREATE TABLE dbo.EventRegistrations (
    EventId int NOT NULL CONSTRAINT FK_Registrations_Event REFERENCES dbo.Events(EventId),
    UserId int NOT NULL CONSTRAINT FK_Registrations_User REFERENCES dbo.Users(UserId),
    RegisteredAt datetime2(0) NOT NULL CONSTRAINT DF_Registrations_At DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_EventRegistrations PRIMARY KEY(EventId,UserId)
);
CREATE TABLE dbo.AIConversations (
    ConversationId int IDENTITY(1,1) CONSTRAINT PK_AIConversations PRIMARY KEY,
    UserId int NOT NULL CONSTRAINT FK_AIConversations_User REFERENCES dbo.Users(UserId),
    StartedAt datetime2(0) NOT NULL CONSTRAINT DF_AIConversations_At DEFAULT SYSUTCDATETIME()
);
CREATE TABLE dbo.AIMessages (
    MessageId bigint IDENTITY(1,1) CONSTRAINT PK_AIMessages PRIMARY KEY,
    ConversationId int NOT NULL CONSTRAINT FK_AIMessages_Conversation REFERENCES dbo.AIConversations(ConversationId),
    Speaker varchar(10) NOT NULL,
    Content nvarchar(max) NOT NULL,
    ModelName varchar(80) NULL,
    SourceArticleId int NULL CONSTRAINT FK_AIMessages_Article REFERENCES dbo.Articles(ArticleId),
    CreatedAt datetime2(0) NOT NULL CONSTRAINT DF_AIMessages_At DEFAULT SYSUTCDATETIME(),
    CONSTRAINT CK_AIMessages_Speaker CHECK(Speaker IN ('USER','ASSISTANT'))
);
CREATE TABLE dbo.ScanAssessments (
    AssessmentId bigint IDENTITY(1,1) CONSTRAINT PK_ScanAssessments PRIMARY KEY,
    ScanId bigint NOT NULL CONSTRAINT FK_Assessments_Scan REFERENCES dbo.Scans(ScanId),
    ModelVersion varchar(80) NOT NULL,
    QualityScore decimal(5,2) NOT NULL,
    Findings nvarchar(1000) NULL,
    AssessedAt datetime2(0) NOT NULL CONSTRAINT DF_Assessments_At DEFAULT SYSUTCDATETIME(),
    CONSTRAINT CK_Assessments_Score CHECK(QualityScore BETWEEN 0 AND 100)
);
GO
CREATE INDEX IX_Labs_Discovery ON dbo.Labs(City,ApprovalStatus) INCLUDE(LabName);
CREATE INDEX IX_Services_Filter ON dbo.Services(LabId,FilmFormat,ProcessCode,IsActive) INCLUDE(Price,TurnaroundHours);
CREATE INDEX IX_Orders_Customer ON dbo.Orders(CustomerId,CreatedAt DESC) INCLUDE(LabId,Status);
CREATE INDEX IX_Orders_LabStatus ON dbo.Orders(LabId,Status,CreatedAt) INCLUDE(CustomerId);
CREATE INDEX IX_Items_Order ON dbo.OrderItems(OrderId) INCLUDE(UnitPrice,ScanRequired,ServiceId);
CREATE INDEX IX_History_Order ON dbo.OrderStatusHistory(OrderId,ChangedAt,HistoryId);
CREATE INDEX IX_Payments_Order ON dbo.Payments(OrderId,Status) INCLUDE(Amount,PaidAt);
CREATE INDEX IX_Listings_Search ON dbo.Listings(Category,Status,AskingPrice);
CREATE INDEX IX_Messages_Conversation ON dbo.AIMessages(ConversationId,MessageId);
GO
