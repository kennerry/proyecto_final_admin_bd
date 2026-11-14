USE [master];
GO

-- 1. Habilitar Database Mail XPs en la instancia
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'Database Mail XPs', 1;
RECONFIGURE;
GO

USE [msdb];
GO

-- 2. Crear la cuenta SMTP para Mailpit
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysmail_account WHERE name = N'DB Admin prueba')
BEGIN
    EXEC msdb.dbo.sysmail_add_account_sp
        @account_name = N'DB Admin prueba',
        @description = N'Cuenta SMTP conectada al servicio local Mailpit',
        @email_address = N'sqlserver@laboratorio.local',
        @display_name = N'SQL Server Agent',
        @replyto_address = N'administrador@laboratorio.local',
        @mailserver_name = N'mailpit',
        @port = 1025,
        @enable_ssl = 0;
END
ELSE
BEGIN
    EXEC msdb.dbo.sysmail_update_account_sp
        @account_name = N'DB Admin prueba',
        @mailserver_name = N'mailpit',
        @port = 1025,
        @enable_ssl = 0;
END
GO

-- 3. Crear el Perfil de Database Mail
IF NOT EXISTS (SELECT 1 FROM msdb.dbo.sysmail_profile WHERE name = N'DB Admin prueba')
BEGIN
    EXEC msdb.dbo.sysmail_add_profile_sp
        @profile_name = N'DB Admin prueba',
        @description = N'Perfil publico para alertas de SQL Server Agent';
END
GO

-- 4. Asociar Cuenta al Perfil
IF NOT EXISTS (
    SELECT 1 
    FROM msdb.dbo.sysmail_profileaccount pa
    JOIN msdb.dbo.sysmail_profile p ON pa.profile_id = p.profile_id
    JOIN msdb.dbo.sysmail_account a ON pa.account_id = a.account_id
    WHERE p.name = N'DB Admin prueba' AND a.name = N'DB Admin prueba'
)
BEGIN
    EXEC msdb.dbo.sysmail_add_profileaccount_sp
        @profile_name = N'DB Admin prueba',
        @account_name = N'DB Admin prueba',
        @sequence_number = 1;
END
GO

-- 5. Configurar Perfil Público por Defecto
EXEC msdb.dbo.sysmail_add_principalprofile_sp
    @profile_name = N'DB Admin prueba',
    @principal_name = N'public',
    @is_default = 1;
GO

-- 6. Configurar el Agente para utilizar este perfil
--En el Object Explorer de SSMS, ve a SQL Server Agent.

--Haz clic derecho sobre SQL Server Agent y selecciona Properties (Propiedades).

--Selecciona la página Alert System (Sistema de alertas) a la izquierda.

--En la sección Mail session:

--Marca la casilla Enable mail profile (Habilitar perfil de correo).

--Mail system: Database Mail

--Mail profile: Selecciona en la lista desplegable tu perfil DB Admin prueba (o DB Admin).

--Haz clic en OK.

--Haz clic derecho sobre SQL Server Agent y selecciona Restart para recargar los cambios.