USE [msdb]
GO

/****** Objeto: Operator [Operador de backup] Fecha de script: 09/11/2026 6:50:16 pm ******/
EXEC msdb.dbo.sp_add_operator @name=N'Operador de backup', 
		@enabled=1, 
		@weekday_pager_start_time=90000, 
		@weekday_pager_end_time=180000, 
		@saturday_pager_start_time=90000, 
		@saturday_pager_end_time=180000, 
		@sunday_pager_start_time=90000, 
		@sunday_pager_end_time=180000, 
		@pager_days=0,
		--Aqui se puede cambiar por un correo de preferencia
		@email_address=N'operadorbackup@gmail.com', 
		@category_name=N'[Uncategorized]'
GO

