
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

-- Tabla: Historial_Auditoria
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

-- Tabla: Logs_Transacciones

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

-- Tabla: Accesos_Usuarios

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
