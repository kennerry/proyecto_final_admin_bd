--Configurar Modelo de Recuperación Completo

USE [master];
GO
ALTER DATABASE Hotel SET RECOVERY FULL WITH NO_WAIT;
GO

--Creacion de los tipos de backup
--Full
BACKUP DATABASE Hotel
TO DISK = N'/var/opt/mssql/backup/Hotel_Full.bak'
WITH FORMAT, INIT, COMPRESSION,
NAME = N'Hotel-Full Database Backup';
GO
--Diferencial
BACKUP DATABASE Hotel
TO DISK = N'/var/opt/mssql/backup/Hotel_Diff.bak'
WITH DIFFERENTIAL, COMPRESSION,
NAME = N'Hotel-Differential Backup';
GO
--Log
BACKUP LOG Hotel
TO DISK = N'/var/opt/mssql/backup/Hotel_Log.trn'
WITH INIT, COMPRESSION,
NAME = N'Hotel-Differential Backup';
GO


