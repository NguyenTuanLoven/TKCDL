USE FilmLabCoursework;
GO
-- Q01: Search approved labs within a VND budget. SQL baseline only.
SELECT * FROM dbo.fn_FindLabs(N'TP.HCM','35MM','C41',120000)
ORDER BY BaselineScore DESC,Price,ServiceId;
-- Q02: Customer order history, including total amount.
SELECT t.*,l.LabName FROM dbo.v_OrderTotals t JOIN dbo.Labs l ON l.LabId=t.LabId
WHERE t.CustomerId=1 ORDER BY t.CreatedAt DESC,t.OrderId DESC;
-- Q03: Lab processing queue.
SELECT OrderId,CustomerId,Status,CreatedAt FROM dbo.Orders
WHERE LabId=1 AND Status NOT IN ('COMPLETED','CANCELLED') ORDER BY CreatedAt,OrderId;
-- Q04: Detailed items/rolls, price snapshot versus current catalog price.
SELECT i.ItemId,i.RollLabel,f.StockName,s.ServiceName,i.UnitPrice AS BookedPrice,s.Price AS CurrentPrice
FROM dbo.OrderItems i JOIN dbo.FilmStocks f ON f.FilmStockId=i.FilmStockId
JOIN dbo.Services s ON s.ServiceId=i.ServiceId WHERE i.OrderId=2;
-- Q05: Ordered status audit trail.
SELECT h.FromStatus,h.ToStatus,u.FullName,h.ChangedAt,h.Note
FROM dbo.OrderStatusHistory h JOIN dbo.Users u ON u.UserId=h.ChangedBy
WHERE h.OrderId=1 ORDER BY h.ChangedAt,h.HistoryId;
-- Q06: A customer's latest scan versions (window function).
WITH Versions AS (
 SELECT s.*,o.CustomerId,ROW_NUMBER() OVER(PARTITION BY s.ItemId,s.FrameNo ORDER BY s.VersionNo DESC) AS rn
 FROM dbo.Scans s JOIN dbo.OrderItems i ON i.ItemId=s.ItemId JOIN dbo.Orders o ON o.OrderId=i.OrderId
 WHERE o.CustomerId=1
) SELECT ScanId,ItemId,FrameNo,ObjectKey,UploadedAt FROM Versions WHERE rn=1;
-- Q07: Cash collected by month. Not net profit; no joins to items that multiply payments.
SELECT r.*,l.LabName FROM dbo.v_MonthlyRevenue r JOIN dbo.Labs l ON l.LabId=r.LabId;
-- Q08: Completed orders whose customers have not reviewed them.
SELECT o.OrderId,o.CustomerId FROM dbo.Orders o
WHERE o.Status='COMPLETED' AND NOT EXISTS(SELECT 1 FROM dbo.Reviews r WHERE r.OrderId=o.OrderId);
-- Q09: Average ratings (NULL means no reviews, not zero stars).
SELECT * FROM dbo.v_LabRatings ORDER BY AverageRating DESC,LabId;
-- Q10: Count rolls by film stock, including film stocks with no orders.
SELECT f.StockName,f.FilmFormat,COUNT(i.ItemId) AS RollCount
FROM dbo.FilmStocks f LEFT JOIN dbo.OrderItems i ON i.FilmStockId=f.FilmStockId
GROUP BY f.StockName,f.FilmFormat ORDER BY RollCount DESC;
-- Q11: Orders without successful payment.
SELECT t.OrderId,t.Status,t.TotalAmount FROM dbo.v_OrderTotals t
WHERE t.Status<>'CANCELLED' AND NOT EXISTS(
 SELECT 1 FROM dbo.Payments p WHERE p.OrderId=t.OrderId AND p.Status='SUCCEEDED');
-- Q12: Marketplace filter.
SELECT ListingId,Title,AskingPrice FROM dbo.Listings
WHERE Status='ACTIVE' AND Category='CAMERA' AND AskingPrice<=5000000;
-- Q13: Published knowledge and comment counts.
SELECT a.ArticleId,a.Title,COUNT(c.CommentId) AS CommentCount FROM dbo.Articles a
LEFT JOIN dbo.ArticleComments c ON c.ArticleId=a.ArticleId
WHERE a.Status='PUBLISHED' GROUP BY a.ArticleId,a.Title;
-- Q14: Event occupancy.
SELECT e.EventId,e.Title,e.Capacity,COUNT(r.UserId) AS Registered,e.Capacity-COUNT(r.UserId) AS Remaining
FROM dbo.Events e LEFT JOIN dbo.EventRegistrations r ON r.EventId=e.EventId
GROUP BY e.EventId,e.Title,e.Capacity;
-- Q15: AI conversation with optional reference.
SELECT m.MessageId,m.Speaker,m.Content,m.ModelName,a.Title AS SourceTitle
FROM dbo.AIMessages m LEFT JOIN dbo.Articles a ON a.ArticleId=m.SourceArticleId
WHERE m.ConversationId=1 ORDER BY m.MessageId;
-- Q16: Most recent quality assessment per scan.
WITH Ranked AS (
 SELECT *,ROW_NUMBER() OVER(PARTITION BY ScanId ORDER BY AssessedAt DESC,AssessmentId DESC) AS rn
 FROM dbo.ScanAssessments
) SELECT ScanId,ModelVersion,QualityScore,Findings FROM Ranked WHERE rn=1 AND QualityScore<90;
-- Q17: Lab ranking by collected revenue, including zero-revenue labs.
WITH Revenue AS (
 SELECT o.LabId,SUM(p.Amount) AS Collected FROM dbo.Payments p
 JOIN dbo.Orders o ON o.OrderId=p.OrderId WHERE p.Status='SUCCEEDED' GROUP BY o.LabId
) SELECT l.LabName,COALESCE(r.Collected,0) AS Collected,
 DENSE_RANK() OVER(ORDER BY COALESCE(r.Collected,0) DESC) AS RevenueRank
FROM dbo.Labs l LEFT JOIN Revenue r ON r.LabId=l.LabId;
-- Q18: Relational division: customers who have ordered ALL active services of Lab 1.
SELECT u.UserId,u.FullName FROM dbo.Users u
WHERE EXISTS(SELECT 1 FROM dbo.Services WHERE LabId=1 AND IsActive=1)
AND NOT EXISTS(
 SELECT 1 FROM dbo.Services s WHERE s.LabId=1 AND s.IsActive=1
 AND NOT EXISTS(SELECT 1 FROM dbo.OrderItems i JOIN dbo.Orders o ON o.OrderId=i.OrderId
                WHERE o.CustomerId=u.UserId AND i.ServiceId=s.ServiceId AND o.Status='COMPLETED'));
GO
