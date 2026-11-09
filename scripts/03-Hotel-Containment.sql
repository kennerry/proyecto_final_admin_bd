EXEC sp_configure
    'contained database authentication', 1;
GO

RECONFIGURE;
GO

ALTER DATABASE Hotel
SET CONTAINMENT = PARTIAL;
GO