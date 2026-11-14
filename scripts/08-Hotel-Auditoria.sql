USE Hotel;
GO

IF EXISTS (SELECT * FROM sys.database_audit_specifications WHERE name = 'EspecificacionAuditoriaHotel')
BEGIN
    ALTER DATABASE AUDIT SPECIFICATION EspecificacionAuditoriaHotel WITH (STATE = OFF);
    DROP DATABASE AUDIT SPECIFICATION EspecificacionAuditoriaHotel;
END
GO

-- =======================================================================================================
-- 1. Auditoria a nivel de servidor
-- =======================================================================================================
-- Logins y eventos

USE master;
GO

-- [CORRECCION] La Server Audit Specification tambien depende de la auditoria: se borra primero
IF EXISTS (SELECT * FROM sys.server_audit_specifications WHERE name = 'ServerAuditLoginHotel')
BEGIN
    ALTER SERVER AUDIT SPECIFICATION ServerAuditLoginHotel WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION ServerAuditLoginHotel;
END
GO

-- Apagar y borrar auditorias viejas
IF EXISTS (SELECT * FROM sys.server_audits WHERE name = 'AuditoriaProyectoHotel')
BEGIN
    ALTER SERVER AUDIT AuditoriaProyectoHotel WITH (STATE = OFF);
    DROP SERVER AUDIT AuditoriaProyectoHotel;
END
GO

-- Creamos auditoria fisica
CREATE SERVER AUDIT AuditoriaProyectoHotel
TO FILE ( 
    FILEPATH = '/var/opt/mssql/log/',
    MAXSIZE = 100 MB,
    MAX_ROLLOVER_FILES = 50
)
WITH (ON_FAILURE = CONTINUE);
GO

-- Encendemos auditoria
ALTER SERVER AUDIT AuditoriaProyectoHotel WITH (STATE = ON);
GO

-- Crear y encender Server Audit Specifications para monitoreo de Logins (Exitosos y fallidos)
IF EXISTS (SELECT * FROM sys.server_audit_specifications WHERE name = 'ServerAuditLoginHotel') 
BEGIN
    ALTER SERVER AUDIT SPECIFICATION ServerAuditLoginHotel WITH (STATE = OFF);
    DROP SERVER AUDIT SPECIFICATION ServerAuditLoginHotel;
END
GO

CREATE SERVER AUDIT SPECIFICATION ServerAuditLoginHotel
FOR SERVER AUDIT AuditoriaProyectoHotel
ADD (SUCCESSFUL_LOGIN_GROUP),
ADD (FAILED_LOGIN_GROUP)
WITH (STATE = ON);
GO


-- =======================================================================================================
-- 2. Auditoria a nivel de base de datos
-- =======================================================================================================
-- Esquemas operaciones y finanzas

USE Hotel;
GO

IF EXISTS (SELECT * FROM sys.database_audit_specifications WHERE name = 'EspecificacionAuditoriaHotel')
BEGIN
    ALTER DATABASE AUDIT SPECIFICATION EspecificacionAuditoriaHotel WITH (STATE = OFF);
    DROP DATABASE AUDIT SPECIFICATION EspecificacionAuditoriaHotel;
END
GO

-- El esquema Auditoria debe existir antes de la especificacion (ahora tambien se audita)
IF SCHEMA_ID('Auditoria') IS NULL
    EXEC('CREATE SCHEMA Auditoria;');
GO

-- Creamos nuevas especificaciones apuntando a los esquemas
CREATE DATABASE AUDIT SPECIFICATION EspecificacionAuditoriaHotel
FOR SERVER AUDIT AuditoriaProyectoHotel
ADD (SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Operaciones BY public),
ADD (SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Finanzas BY public),
-- [CORRECCION] Auditar tambien el esquema Auditoria: si alguien edita o borra evidencia, queda registrado
ADD (UPDATE, DELETE ON SCHEMA::Auditoria BY public)
WITH (STATE = ON);
GO

-- =======================================================================================================
-- 3. Tablas de auditoria
-- =======================================================================================================
-- Esquema 'Auditoria'

IF SCHEMA_ID('Auditoria') IS NULL
    EXEC('CREATE SCHEMA Auditoria;');
GO

-- Creamos la tabla
IF OBJECT_ID('Auditoria.Historial_Auditoria', 'U') IS NULL
BEGIN
    CREATE TABLE Auditoria.Historial_Auditoria (
        ID_Log INT IDENTITY (1,1) PRIMARY KEY,
        Fecha_Hora DATETIME2 NOT NULL,                
        Usuario NVARCHAR(128) NOT NULL,
        ID_Transaccion BIGINT NOT NULL,
        Accion NVARCHAR(50) NOT NULL,
        Tabla_Afectada NVARCHAR(128) NOT NULL,
        Comando_Exacto NVARCHAR(MAX) NULL,           
        Archivo_Origen NVARCHAR(260) NOT NULL,
        Offset_Archivo BIGINT NOT NULL,
        Numero_Secuencia INT NOT NULL
    );

    CREATE UNIQUE INDEX UX_Historial_Auditoria_Origen
        ON Auditoria.Historial_Auditoria (Archivo_Origen, Offset_Archivo, Numero_Secuencia);

    CREATE INDEX IX_Historial_Auditoria_Fecha
        ON Auditoria.Historial_Auditoria (Fecha_Hora);
END
GO

-- Creamos la tabla
IF OBJECT_ID('Auditoria.Logs_Transacciones', 'U') IS NULL
BEGIN
    CREATE TABLE Auditoria.Logs_Transacciones (
        ID_Log_Transaccion INT IDENTITY(1,1) PRIMARY KEY,
        Fecha_Hora DATETIME2 DEFAULT SYSDATETIME(),
        Usuario NVARCHAR(128) DEFAULT SUSER_SNAME(),
        Tabla_Afectada NVARCHAR(128) NOT NULL,
        Columna_Afectada NVARCHAR(128) NOT NULL,
        ID_Registro_Afectado INT NOT NULL,
        Clave_Compuesta NVARCHAR(200) NULL,           
        Valor_Anterior NVARCHAR(MAX),
        Valor_Nuevo NVARCHAR(MAX),
        Tipo_Operacion NVARCHAR(50) NOT NULL
    );
END
GO

-- Creamos la tabla
IF OBJECT_ID('Auditoria.Accesos_Usuarios', 'U') IS NULL
BEGIN
    CREATE TABLE Auditoria.Accesos_Usuarios (
        ID_Acceso INT IDENTITY(1,1) PRIMARY KEY,
        Fecha_Hora DATETIME2 DEFAULT SYSDATETIME(),   
        Usuario NVARCHAR(128) NOT NULL,
        IP_Origen NVARCHAR(50),
        Estado_Login NVARCHAR(50) -- Ej: 'Exitoso', 'Fallido'
    );
END
GO

-- =======================================================================================================
-- 4. Triggers para auditoria granular
-- =======================================================================================================
-- Columnas de dinero

-- Trigger para Finanzas.Factura  (Auditar cambios en Precio_total)
IF OBJECT_ID('Finanzas.trg_Audit_Factura_Precio', 'TR') IS NOT NULL
    DROP TRIGGER Finanzas.trg_Audit_Factura_Precio;
GO

CREATE TRIGGER Finanzas.trg_Audit_Factura_Precio
ON Finanzas.Factura
AFTER INSERT, UPDATE, DELETE
AS
BEGIN

    SET NOCOUNT ON;

    -- La comparacion se hace en el WHERE del SELECT.
    INSERT INTO Auditoria.Logs_Transacciones (Tabla_Afectada, Columna_Afectada, ID_Registro_Afectado, Valor_Anterior, Valor_Nuevo, Tipo_Operacion)
    SELECT
        'Finanzas.Factura',
        'Precio_total',
        COALESCE(i.ID_Factura, d.ID_Factura),
        CAST(d.Precio_total AS NVARCHAR(50)),
        CAST(i.Precio_total AS NVARCHAR(50)),
        CASE
            WHEN d.ID_Factura IS NULL THEN 'INSERT SENSIBLE'     
            WHEN i.ID_Factura IS NULL THEN 'DELETE SENSIBLE'
            ELSE 'UPDATE SENSIBLE'
        END
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.ID_Factura = d.ID_Factura
    WHERE d.ID_Factura IS NULL                                    -- INSERT
       OR i.ID_Factura IS NULL                                    -- DELETE
       -- Evitar falsos positivos si el update no cambio el valor
       OR EXISTS (SELECT i.Precio_total EXCEPT SELECT d.Precio_total);
END;
GO

-- Trigger para Finanzas.PagoNomina (Auditar cambios en Monto)
IF OBJECT_ID('Finanzas.trg_Audit_PagoNomina_Monto', 'TR') IS NOT NULL
    DROP TRIGGER Finanzas.trg_Audit_PagoNomina_Monto;
GO

CREATE TRIGGER Finanzas.trg_Audit_PagoNomina_Monto
ON Finanzas.PagoNomina
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    INSERT INTO Auditoria.Logs_Transacciones (Tabla_Afectada, Columna_Afectada, ID_Registro_Afectado, Clave_Compuesta, Valor_Anterior, Valor_Nuevo, Tipo_Operacion)
    SELECT 
        'Finanzas.PagoNomina', 
        'Monto', 
        COALESCE(i.ID_Salario, d.ID_Salario), 
        CONCAT('ID_Salario=', COALESCE(i.ID_Salario, d.ID_Salario),
               ';ID_Empleado=', COALESCE(i.ID_Empleado, d.ID_Empleado)),
        CAST(d.Monto AS NVARCHAR(50)), 
        CAST(i.Monto AS NVARCHAR(50)), 
        CASE
            WHEN d.ID_Salario IS NULL THEN 'INSERT SENSIBLE'
            WHEN i.ID_Salario IS NULL THEN 'DELETE SENSIBLE'
            ELSE 'UPDATE SENSIBLE'
        END
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.ID_Salario = d.ID_Salario AND i.ID_Empleado = d.ID_Empleado
    WHERE d.ID_Salario IS NULL
       OR i.ID_Salario IS NULL
       OR EXISTS (SELECT i.Monto EXCEPT SELECT d.Monto);
END;
GO

-- =======================================================================================================
-- 5. Procedimiento para volcar logs fisicos a la tabla del esquema auditoria
-- =======================================================================================================

IF OBJECT_ID('Auditoria.sp_Cargar_Historial_Auditoria', 'P') IS NOT NULL
    DROP PROCEDURE Auditoria.sp_Cargar_Historial_Auditoria;
GO

-- Creamos el procedimiento

CREATE OR ALTER PROCEDURE Auditoria.sp_Cargar_Historial_Auditoria
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;   -- Si algo falla se revierte

    DECLARE @Desde DATETIME2 =
        DATEADD(MINUTE, -10, ISNULL((SELECT MAX(Fecha_Hora) FROM Auditoria.Historial_Auditoria), '19000101'));

    BEGIN TRANSACTION;

    SELECT
        event_time,
        server_principal_name,
        transaction_id,
        action_id,
        object_name,
        statement,
        file_name,
        audit_file_offset,
        sequence_number,
        client_ip,        -- Depende de la version: CAST(NULL AS NVARCHAR(50)) AS client_ip
        succeeded
    INTO #Nuevos
    FROM
    (
        SELECT
            event_time,
            server_principal_name,
            transaction_id,
            action_id,
            object_name,
            statement,
            file_name,
            audit_file_offset,
            sequence_number,
            client_ip,
            succeeded,

            ROW_NUMBER() OVER (
                PARTITION BY file_name, audit_file_offset, sequence_number
                ORDER BY event_time DESC
            ) AS rn

        FROM sys.fn_get_audit_file('/var/opt/mssql/log/*.sqlaudit', DEFAULT, DEFAULT)

        WHERE (database_name = 'Hotel' OR database_name IS NULL OR action_id IN ('LGIS', 'LGIF'))
        AND event_time >= @Desde
    ) AS Eventos

    WHERE rn = 1

    AND NOT EXISTS (
        SELECT 1
        FROM Auditoria.Historial_Auditoria h WITH (UPDLOCK, HOLDLOCK)
        WHERE h.Archivo_Origen = Eventos.file_name
          AND h.Offset_Archivo = Eventos.audit_file_offset
          AND h.Numero_Secuencia = Eventos.sequence_number
    );


    -- Insertar registros que no existan aún (basado en el archivo, offset y secuencia)
    INSERT INTO Auditoria.Historial_Auditoria
    (
        Fecha_Hora,
        Usuario,
        ID_Transaccion,
        Accion,
        Tabla_Afectada,
        Comando_Exacto,
        Archivo_Origen,
        Offset_Archivo,
        Numero_Secuencia
    )
    SELECT
        event_time,
        ISNULL(server_principal_name, 'N/A'),
        ISNULL(transaction_id, 0),
        CASE action_id
            WHEN 'SL' THEN 'SELECT'
            WHEN 'UP' THEN 'UPDATE'
            WHEN 'IN' THEN 'INSERT'
            WHEN 'DL' THEN 'DELETE'
            WHEN 'LGIS' THEN 'LOGIN SUCCESS'
            WHEN 'LGIF' THEN 'LOGIN FAILED'
            ELSE action_id
        END,
        ISNULL(NULLIF(object_name, ''), 'N/A'),
        statement,
        file_name,
        audit_file_offset,
        sequence_number
    FROM #Nuevos;


    INSERT INTO Auditoria.Accesos_Usuarios
    (
        Fecha_Hora,
        Usuario,
        IP_Origen,
        Estado_Login
    )
    SELECT
        event_time,
        ISNULL(server_principal_name, 'N/A'),
        client_ip,
        CASE action_id WHEN 'LGIS' THEN 'Exitoso' ELSE 'Fallido' END
    FROM #Nuevos
    WHERE action_id IN ('LGIS', 'LGIF');


    COMMIT TRANSACTION;

    DROP TABLE #Nuevos;
END;
GO


-- =======================================================================================================
-- 6. Prueba de funcionamiento
-- =======================================================================================================

EXEC Auditoria.sp_Cargar_Historial_Auditoria;
EXEC Auditoria.sp_Cargar_Historial_Auditoria;
SELECT TOP 10 * FROM Auditoria.Historial_Auditoria ORDER BY Fecha_Hora DESC;
SELECT TOP 10 * FROM Auditoria.Accesos_Usuarios ORDER BY Fecha_Hora DESC;
SELECT TOP 10 * FROM Auditoria.Logs_Transacciones ORDER BY ID_Log_Transaccion DESC;
GO