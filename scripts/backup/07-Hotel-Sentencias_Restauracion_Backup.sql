use master;
go
drop database Hotel;
--Ejecutar este comando para ver la ruta del backup full mas reciente, en las columnas "Tipo" buscar Full y en "Archivo" copiar la ruta que aparece
SELECT 
    bs.backup_set_id,
    CASE bs.type 
        WHEN 'D' THEN 'Full'
        WHEN 'I' THEN 'Diferencial'
        WHEN 'L' THEN 'Transaction Log'
    END AS Tipo,
    bmf.physical_device_name AS 'Archivo',
    bs.first_lsn,
    bs.last_lsn,
    bs.checkpoint_lsn,
    bs.database_backup_lsn,
    bs.backup_finish_date
FROM msdb.dbo.backupset bs
JOIN msdb.dbo.backupmediafamily bmf ON bs.media_set_id = bmf.media_set_id
WHERE bs.database_name = 'Hotel'
ORDER BY bs.backup_set_id ASC;

-- Paso A: Restaurar Backup FULL mas reciente (dejando la BD en estado Restoring)
RESTORE DATABASE Hotel
--En esta sentencia (from disk) se pone la ruta que se copio del full backup
FROM DISK = N'Insertar ruta'
WITH 
    MOVE N'Hotel' TO N'/var/opt/mssql/data/Hotel.mdf',
    MOVE N'Hotel_log' TO N'/var/opt/mssql/data/Hotel_log.ldf',
    NORECOVERY,
    REPLACE;
GO

-- Paso B: Restaurar el Backup DIFERENCIAL más reciente, para obtener la ruta se puede ver con la sentencia anterior
--NOTA: Si no se han hecho cambios en la base de datos (INSERTS, UPDATES, etc) esta sentencia fallara
RESTORE DATABASE Hotel
FROM DISK = N'Insertar ruta'
WITH 
    NORECOVERY;
GO

--Restaurar el log con la siguiente sentencia si y solo si existe UNO, para obtener la ruta se puede ver con la sentencia anterior, si existe mas de uno se ejecutan las sentencias que se muestran mas abajo
RESTORE LOG Hotel
FROM DISK = N'Insertar ruta'
WITH RECOVERY;
GO

--====================================================================================
--====================================================================================
--====================================================================================

-- Si existe mas de un log, se ejecutan estos comandos, se toman los logs generados a partir del ULTIMO backup DIFERENCIAL generado
--A partir del log mas antiguo, se va ejecutando "N" veces la siguiente sentencia por cada log, poniendo su respectiva ruta, excepto el ultimo log
RESTORE LOG Hotel
FROM DISK = N'/var/opt/mssql/backup/Ejemplo_Hotel_Log_#1.trn'
WITH NORECOVERY;
GO

RESTORE LOG Hotel
FROM DISK = N'/var/opt/mssql/backup/Ejemplo_Hotel_Log_#2.trn'
WITH NORECOVERY;
GO

--Sentencia del penultimo log

RESTORE LOG Hotel
FROM DISK = N'/var/opt/mssql/backup/Ejemplo_Hotel_Log_#(N-1).trn'
WITH NORECOVERY;
GO

-- Por ultimo, se restaura el último Log y se deja la base en línea
RESTORE LOG Hotel
FROM DISK = N'/var/opt/mssql/backup/Ejemplo_Hotel_Log_#N.trn'
WITH RECOVERY;
GO