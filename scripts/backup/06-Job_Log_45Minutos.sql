USE [msdb]
GO

/****** Objeto: Job [Backup_Log_45Minutos] Fecha de script: 12/11/2026 12:12:08 pm ******/
BEGIN TRANSACTION
DECLARE @ReturnCode INT
SELECT @ReturnCode = 0
/****** Objeto: JobCategory [[Uncategorized (Local)]] Fecha de script: 12/11/2026 12:12:08 pm ******/
IF NOT EXISTS (SELECT name FROM msdb.dbo.syscategories WHERE name=N'[Uncategorized (Local)]' AND category_class=1)
BEGIN
EXEC @ReturnCode = msdb.dbo.sp_add_category @class=N'JOB', @type=N'LOCAL', @name=N'[Uncategorized (Local)]'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback

END

DECLARE @jobId BINARY(16)
EXEC @ReturnCode =  msdb.dbo.sp_add_job @job_name=N'Backup_Log_45Minutos', 
		@enabled=1, 
		@notify_level_eventlog=0, 
		@notify_level_email=2, 
		@notify_level_netsend=0, 
		@notify_level_page=0, 
		@delete_level=0, 
		@description=N'No description available.', 
		@category_name=N'[Uncategorized (Local)]', 
		@owner_login_name=N'sa', 
		@notify_email_operator_name=N'Operador de backup', @job_id = @jobId OUTPUT
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
/****** Objeto: Step [Ejecutar Backup Log] Fecha de script: 12/11/2026 12:12:08 pm ******/
EXEC @ReturnCode = msdb.dbo.sp_add_jobstep @job_id=@jobId, @step_name=N'Ejecutar Backup Log', 
		@step_id=1, 
		@cmdexec_success_code=0, 
		@on_success_action=1, 
		@on_success_step_id=0, 
		@on_fail_action=2, 
		@on_fail_step_id=0, 
		@retry_attempts=0, 
		@retry_interval=0, 
		@os_run_priority=0, @subsystem=N'TSQL', 
		@command=N'DECLARE @BackupPath NVARCHAR(500);
DECLARE @FileName NVARCHAR(500);
DECLARE @DatabaseName NVARCHAR(100) = N''Hotel'';
DECLARE @CutoffDate DATETIME;

SET @FileName = @DatabaseName + N''_Log_'' + REPLACE(REPLACE(REPLACE(CONVERT(VARCHAR(19), GETDATE(), 120), ''-'', ''''), '' '', ''_''), '':'', '''') + N''.trn'';
SET @BackupPath = N''/var/opt/mssql/backup/'' + @FileName;

BACKUP LOG @DatabaseName
TO DISK = @BackupPath
WITH INIT, COMPRESSION;

SET @CutoffDate = DATEADD(DAY, -3, GETDATE());
EXEC master.sys.xp_delete_file 0, N''/var/opt/mssql/backup/'', N''trn'', @CutoffDate, 1;', 
		@database_name=N'Hotel', 
		@flags=0
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_update_job @job_id = @jobId, @start_step_id = 1
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobschedule @job_id=@jobId, @name=N'Sched_Backup_Log_15Min', 
		@enabled=1, 
		@freq_type=4, 
		@freq_interval=1, 
		@freq_subday_type=4, 
		@freq_subday_interval=45, 
		@freq_relative_interval=0, 
		@freq_recurrence_factor=0, 
		@active_start_date=20261108, 
		@active_end_date=99991231, 
		@active_start_time=1500, 
		@active_end_time=234500, 
		@schedule_uid=N'812139c7-9666-4228-ba9c-382cc9b125fb'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
EXEC @ReturnCode = msdb.dbo.sp_add_jobserver @job_id = @jobId, @server_name = N'(local)'
IF (@@ERROR <> 0 OR @ReturnCode <> 0) GOTO QuitWithRollback
COMMIT TRANSACTION
GOTO EndSave
QuitWithRollback:
    IF (@@TRANCOUNT > 0) ROLLBACK TRANSACTION
EndSave:
GO

