-- Creacion y configuracion de auditoria
-- Crear server de auditoria en master y configurar ruta donde guardar el archivo

Use master;
GO

CREATE SERVER AUDIT AuditoriaProyectoHotel
TO FILE (
    FILEPATH = '/var/opt/mssql/log/') -- Cambiar ruta si se usa Windows y aplicar permisos
WITH (ON_FAILURE = CONTINUE); --Cuando haya un error lo ignora y continua
GO

-- Encendemos auditoria

ALTER SERVER AUDIT AuditoriaProyectoHotel WITH (STATE = ON);
GO

-- Creamos especificaciones de auditoria de Hotel. (Vive dentro del .bak)

USE Hotel;
GO

CREATE DATABASE AUDIT SPECIFICATION EspecificacionAuditoriaHotel
FOR SERVER AUDIT AuditoriaProyectoHotel
ADD (SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo BY public)
WITH (STATE = ON); --Encendemos la auditoria
GO

-- Verificacion de funcionamiento de la auditoria
-- Hacemos un select que quedara registrado

USE Hotel;
GO

SELECT TOP 5 * FROM dbo.Empleado;
GO

--Verificamos que el select fue registrado exitosamente en la auditoria

USE master;
GO

SELECT 
    event_time AS [Fecha y Hora],
    server_principal_name AS [Usuario],
    transaction_id AS [ID transaccion],
    CASE action_id
        WHEN 'SL' THEN 'SELECT'
        WHEN 'UP' THEN 'UPDATE'
        WHEN 'IN' THEN 'INSERT'
        WHEN 'DL' THEN 'DELETE'
        ELSE action_id
    END AS [Accion],
    object_name AS [Tabla Afectada],
    statement AS [Comando Exacto]
FROM sys.fn_get_audit_file('/var/opt/mssql/log/*.sqlaudit', DEFAULT, DEFAULT)
WHERE database_name = 'Hotel'
ORDER BY event_time DESC, object_name ASC;
GO
