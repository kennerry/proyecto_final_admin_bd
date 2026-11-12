
-- =======================================================================================================
-- 1. Auditoria a nivel de servidor
-- =======================================================================================================
-- Logins y eventos

USE master;
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
    FILEPATH = '/var/opt/mssql/log/'
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

-- Creamos nuevas especificaciones apuntando a los esquemas

CREATE DATABASE AUDIT SPECIFICATION EspecificacionAuditoriaHotel
FOR SERVER AUDIT AuditoriaProyectoHotel
ADD (SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Operaciones BY public),
ADD (SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Finanzas BY public)
WITH (STATE = ON);
GO

-- =======================================================================================================
-- 3. Tablas de auditoria
-- =======================================================================================================
-- Esquema 'Auditoria'

-- Asegurarnos que el esquema Auditoria existe
IF SCHEMA_ID('Auditoria') IS NULL
    EXEC('CREATE SCHEMA AUDITORIA;');
GO

-- Tabla: Historial_Auditoria (Volcar datos del archivo fisico a la BD)
IF OBJECT_ID('Auditoria.Historial_Auditoria', 'U') IS NOT NULL
    DROP TABLE Auditoria.Historial_Auditoria;
GO

-- Creamos la tabla
CREATE TABLE Auditoria.Historial_Auditoria (
    ID_Log INT IDENTITY (1,1) PRIMARY KEY,
    Fecha_Hora DATETIME2 NOT NULL,
    Usuario NVARCHAR(128) NOT NULL,
    ID_Transaccion BIGINT NOT NULL,
    Accion NVARCHAR(50) NOT NULL,
    Tabla_Afectada NVARCHAR(128) NOT NULL,
    Comando_Exacto NVARCHAR(MAX) NOT NULL
);
GO

-- Tabla: Logs_Transacciones (Para auditoria granular de columnas sensibles)
IF OBJECT_ID('Auditoria.Logs_Transacciones', 'U') IS NOT NULL
    DROP TABLE Auditoria.Logs_Transacciones;
GO

-- Creamos la tabla
CREATE TABLE Auditoria.Logs_Transacciones (
    ID_Log_Transaccion INT IDENTITY(1,1) PRIMARY KEY,
    Fecha_Hora DATETIME2 DEFAULT SYSDATETIME(),
    Usuario NVARCHAR(128) DEFAULT SUSER_SNAME(),
    Tabla_Afectada NVARCHAR(128) NOT NULL,
    Columna_Afectada NVARCHAR(128) NOT NULL,
    ID_Registro_Afectado INT NOT NULL,
    Valor_Anterior NVARCHAR(MAX),
    Valor_Nuevo NVARCHAR(MAX),
    Tipo_Operacion NVARCHAR(50) NOT NULL
);
GO

-- Tabla: Accesos_Usuarios (Para registrar intentos de login)
IF OBJECT_ID('Auditoria.Accesos_Usuarios', 'U') IS NOT NULL
    DROP TABLE Auditoria.Accesos_Usuarios;
GO

-- Creamos la tabla
CREATE TABLE Auditoria.Accesos_Usuarios (
    ID_Acceso INT IDENTITY(1,1) PRIMARY KEY,
    Fecha_Hora DATETIME2 DEFAULT SYSDATETIME(),
    Usuario NVARCHAR(128) NOT NULL,
    IP_Origen NVARCHAR(50),
    Estado_Login NVARCHAR(50) -- Ej: 'Exitoso', 'Fallido'
);
GO

-- =======================================================================================================
-- 4. Triggers para auditoria granular
-- =======================================================================================================
-- Columnas de dinero

-- Trigger para Finanzas.Factura  (Auditar cambios en Precio_total)
IF OBJECT_ID('Finanzas.trg_Audit_Factura_Precio', 'TR') IS NOT NULL
    DROP TRIGGER Finanzas.trg_Audit_Factura_Precio;
GO

CREATE TRIGGER trg_Audit_Factura_Precio
ON Finanzas.Factura
AFTER UPDATE 
AS
BEGIN

    SET NOCOUNT ON;

    IF UPDATE(Precio_total)
    BEGIN
        INSERT INTO Auditoria.Logs_Transacciones (Tabla_Afectada, Columna_Afectada, ID_Registro_Afectado, Valor_Anterior, Valor_Nuevo, Tipo_Operacion)
        SELECT
            'Finanzas.Factura',
            'Precio_total',
            i.ID_Factura,
            CAST(d.Precio_total AS NVARCHAR(50)),
            CAST(i.Precio_total AS NVARCHAR(50)),
            'UPDATE SENSITIVO'
        FROM inserted i
        JOIN deleted d ON i.ID_Factura = d.ID_Factura
        WHERE i.Precio_total <> d.Precio_total;  -- Evitar falsos positivos si el update no cambio el valor
    END
END;
GO

-- Trigger para Finanzas.PagoNomina (Auditar cambios en Monto)
IF OBJECT_ID('Finanzas.trg_Audit_PagoNomina_Monto', 'TR') IS NOT NULL
    DROP TRIGGER Finanzas.trg_Audit_PagoNomina_Monto;
GO

CREATE TRIGGER trg_Audit_PagoNomina_Monto
ON Finanzas.PagoNomina
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF UPDATE(Monto)
    BEGIN
        INSERT INTO Auditoria.Logs_Transacciones (Tabla_Afectada, Columna_Afectada, ID_Registro_Afectado, Valor_Anterior, Valor_Nuevo, Tipo_Operacion)
        SELECT 
            'Finanzas.PagoNomina', 
            'Monto', 
            i.ID_Salario, 
            CAST(d.Monto AS NVARCHAR(50)), 
            CAST(i.Monto AS NVARCHAR(50)), 
            'UPDATE SENSITIVO'
        FROM inserted i
        INNER JOIN deleted d ON i.ID_Salario = d.ID_Salario AND i.ID_Empleado = d.ID_Empleado
        WHERE i.Monto <> d.Monto;
    END
END;
GO

-- =======================================================================================================
-- 5. Procedimiento para volcar logs fisicos a la tabla del esquema auditoria
-- =======================================================================================================

IF OBJECT_ID('Auditoria.sp_Cargar_Historial_Auditoria', 'P') IS NOT NULL
    DROP PROCEDURE Auditoria.sp_Cargar_Historial_Auditoria;
GO

-- Creamos el procedimiento

CREATE PROCEDURE Auditoria.sp_Cargar_Historial_Auditoria
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Insertar registros que no existan aún (basado en la fecha/hora y usuario para evitar duplicados masivos)
    INSERT INTO Auditoria.Historial_Auditoria (Fecha_Hora, Usuario, ID_Transaccion, Accion, Tabla_Afectada, Comando_Exacto)
    SELECT 
        event_time,
        server_principal_name,
        transaction_id,
        CASE action_id
            WHEN 'SL' THEN 'SELECT'
            WHEN 'UP' THEN 'UPDATE'
            WHEN 'IN' THEN 'INSERT'
            WHEN 'DL' THEN 'DELETE'
            WHEN 'LGIS' THEN 'LOGIN SUCCESS'
            WHEN 'LGIF' THEN 'LOGIN FAILED'
            ELSE action_id
        END,
        ISNULL(object_name, 'N/A'),
        statement
    FROM sys.fn_get_audit_file('/var/opt/mssql/log/*.sqlaudit', DEFAULT, DEFAULT)
    WHERE database_name = 'Hotel' OR database_name IS NULL -- Incluir logins que pueden no tener BD asignada al fallar
    -- Lógica para evitar insertar TODO de nuevo cada vez 
    AND NOT EXISTS (
        SELECT 1 FROM Auditoria.Historial_Auditoria h 
        WHERE h.Fecha_Hora = event_time AND h.Usuario = server_principal_name
    );
END;
GO

-- =======================================================================================================
-- 6. Prueba de funcionamiento
-- =======================================================================================================

EXEC Auditoria.sp_Cargar_Historial_Auditoria;
SELECT TOP 10 * FROM Auditoria.Historial_Auditoria ORDER BY Fecha_Hora DESC;
GO

