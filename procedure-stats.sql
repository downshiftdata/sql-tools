SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;
WITH cteStats AS (SELECT TOP 100 ps.[plan_handle]
	FROM sys.dm_exec_procedure_stats AS ps
	WHERE DATEDIFF(hh, ps.[cached_time], GETDATE()) >= 1
		AND EXISTS (SELECT 1
				FROM sys.dm_exec_cached_plans AS cp
				WHERE ps.[plan_handle] = cp.[plan_handle])
	ORDER BY ps.[total_elapsed_time] / DATEDIFF(hh, ps.[cached_time], GETDATE()) DESC)
SELECT
		DB_NAME(ps.[database_id]) + N'.' + OBJECT_SCHEMA_NAME(ps.[object_id]) + N'.' + OBJECT_NAME(ps.[object_id]) AS [full_name],
		ps.[cached_time],
		cp.[size_in_bytes] / 1024 AS [cache_size_kb],
		ps.[execution_count] / DATEDIFF(hh, ps.[cached_time], GETDATE()) AS [exec_per_hour],
		ps.[total_worker_time] / DATEDIFF(hh, ps.[cached_time], GETDATE()) AS [worker_time_per_hour],
		ps.[total_physical_reads] / DATEDIFF(hh, ps.[cached_time], GETDATE()) AS [physical_reads_per_hour],
		ps.[total_logical_writes] / DATEDIFF(hh, ps.[cached_time], GETDATE()) AS [logical_writes_per_hour],
		ps.[total_logical_reads] / DATEDIFF(hh, ps.[cached_time], GETDATE()) AS [logical_reads_per_hour],
		ps.[total_elapsed_time] / DATEDIFF(hh, ps.[cached_time], GETDATE()) AS [elapsed_time_per_hour],
		qp.[query_plan]
	FROM cteStats AS s
		INNER JOIN sys.dm_exec_cached_plans AS cp
			ON s.[plan_handle] = cp.[plan_handle]
		INNER JOIN sys.dm_exec_procedure_stats AS ps
			ON cp.[plan_handle] = ps.[plan_handle]
		CROSS APPLY sys.dm_exec_query_plan(s.[plan_handle]) AS qp
	ORDER BY ps.[total_elapsed_time] / DATEDIFF(hh, ps.[cached_time], GETDATE()) DESC
	OPTION (RECOMPILE);
