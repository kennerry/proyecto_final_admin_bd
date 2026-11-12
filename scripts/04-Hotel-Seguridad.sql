USE Hotel;
GO

--Creacion de esquemas
CREATE SCHEMA Operaciones;
GO
CREATE SCHEMA Finanzas;
GO
CREATE SCHEMA Auditoria;
GO
CREATE SCHEMA BI;
GO

--Mover las tablas de dbo a sus nuevos esquemas
ALTER SCHEMA Operaciones TRANSFER dbo.Hotel;
ALTER SCHEMA Operaciones TRANSFER dbo.Habitacion;
ALTER SCHEMA Operaciones TRANSFER dbo.Huesped;
ALTER SCHEMA Operaciones TRANSFER dbo.Reservacion;
ALTER SCHEMA Operaciones TRANSFER dbo.Estadia;
ALTER SCHEMA Operaciones TRANSFER dbo.Servicio;
ALTER SCHEMA Operaciones TRANSFER dbo.HistorialServicios;
ALTER SCHEMA Operaciones TRANSFER dbo.RegistroHabitaciones;

ALTER SCHEMA Finanzas TRANSFER dbo.Empleado;
ALTER SCHEMA Finanzas TRANSFER dbo.PagoNomina;
ALTER SCHEMA Finanzas TRANSFER dbo.Factura;
ALTER SCHEMA Finanzas TRANSFER dbo.Detalle;
GO

--Creación de Roles, Permisos y Usuarios
CREATE ROLE Rol_Recepcionista;
CREATE ROLE Rol_Contador;
CREATE ROLE Rol_AdministradorHotel;
CREATE ROLE Rol_AnalistaBI;
GO

GRANT SELECT, INSERT, UPDATE ON SCHEMA::Operaciones TO Rol_Recepcionista;
GRANT SELECT ON Finanzas.Factura TO Rol_Recepcionista;
GRANT SELECT ON Finanzas.Detalle TO Rol_Recepcionista;
DENY DELETE ON SCHEMA::Operaciones TO Rol_Recepcionista;

GRANT SELECT, INSERT, UPDATE ON SCHEMA::Finanzas TO Rol_Contador;
GRANT SELECT ON SCHEMA::Operaciones TO Rol_Contador;

GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Operaciones TO Rol_AdministradorHotel;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::Finanzas TO Rol_AdministradorHotel;

GRANT SELECT ON SCHEMA::BI TO Rol_AnalistaBI;
GO

CREATE LOGIN usr_recepcion WITH PASSWORD = 'PasswordSeguro123!';
CREATE USER usr_recepcion FOR LOGIN usr_recepcion;
ALTER ROLE Rol_Recepcionista ADD MEMBER usr_recepcion;

CREATE LOGIN usr_contabilidad WITH PASSWORD = 'PasswordSeguro123!';
CREATE USER usr_contabilidad FOR LOGIN usr_contabilidad;
ALTER ROLE Rol_Contador ADD MEMBER usr_contabilidad;

CREATE LOGIN usr_gerente WITH PASSWORD = 'PasswordSeguro123!';
CREATE USER usr_gerente FOR LOGIN usr_gerente;
ALTER ROLE Rol_AdministradorHotel ADD MEMBER usr_gerente;

CREATE LOGIN usr_analistaBI WITH PASSWORD = 'PasswordSeguro123!';
CREATE USER usr_analistaBI FOR LOGIN usr_analistaBI;
ALTER ROLE Rol_AnalistaBI ADD MEMBER usr_analistaBI;
GO