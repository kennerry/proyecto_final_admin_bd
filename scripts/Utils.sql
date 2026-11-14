-- Habilitar que se puedan autenticar usuarios en bases de datos contenidas en SQL Server a nivel de instancia
USE master;
GO

-- Habilitar la autenticación de bases de datos contenidas
EXEC sp_configure 'show advanced options', 1;
GO

RECONFIGURE;
GO

EXEC sp_configure 'contained database authentication', 1;
GO

RECONFIGURE;
GO
