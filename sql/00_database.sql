-- SQL Server 2019+. Run on a NEW coursework database; never drop existing data.
USE master;
GO
IF DB_ID(N'FilmLabCoursework') IS NULL
    EXEC(N'CREATE DATABASE FilmLabCoursework');
GO
USE FilmLabCoursework;
GO
SET NOCOUNT ON;
IF EXISTS (SELECT 1 FROM sys.tables WHERE is_ms_shipped = 0)
    THROW 51000, 'Database is not empty. Use a new database or skip installation.', 1;
GO
