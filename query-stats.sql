SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;
WITH cteStats AS (SELECT TOP 100 qs.[plan_handle]
	FROM sys.dm_exec_query_stats AS qs
	WHERE DATEDIFF(hh, qs.[creation_time], GETDATE()) >= 1
		AND EXISTS (SELECT 1
				FROM sys.dm_exec_cached_plans AS cp
				WHERE qs.[plan_handle] = cp.[plan_handle])
	ORDER BY qs.[total_elapsed_time] / DATEDIFF(hh, qs.[creation_time], GETDATE()) DESC)
SELECT
		SUBSTRING(st.[text],
			qs.[statement_start_offset] / 2 + 1,
			CASE qs.[statement_end_offset]
					WHEN -1 THEN DATALENGTH(st.[text])
					ELSE qs.[statement_end_offset]
				END - qs.[statement_start_offset] / 2 + 1) AS [query],
		cp.[objtype],
		qp.[query_plan].value(N'(//@StatementText)[1]', N'NVARCHAR(MAX)') AS [stmt1],
		qs.[creation_time],
		cp.[size_in_bytes] / 1024 AS [cache_size_kb],
		qs.[execution_count] / DATEDIFF(hh, qs.[creation_time], GETDATE()) AS [exec_per_hour],
		qs.[total_worker_time] / DATEDIFF(hh, qs.[creation_time], GETDATE()) AS [worker_time_per_hour],
		qs.[total_physical_reads] / DATEDIFF(hh, qs.[creation_time], GETDATE()) AS [physical_reads_per_hour],
		qs.[total_logical_writes] / DATEDIFF(hh, qs.[creation_time], GETDATE()) AS [logical_writes_per_hour],
		qs.[total_logical_reads] / DATEDIFF(hh, qs.[creation_time], GETDATE()) AS [logical_reads_per_hour],
		qs.[total_elapsed_time] / DATEDIFF(hh, qs.[creation_time], GETDATE()) AS [elapsed_time_per_hour],
		qp.[query_plan]
	FROM cteStats AS s
		INNER JOIN sys.dm_exec_cached_plans AS cp
			ON s.[plan_handle] = cp.[plan_handle]
		INNER JOIN sys.dm_exec_query_stats AS qs
			ON cp.[plan_handle] = qs.[plan_handle]
		CROSS APPLY sys.dm_exec_query_plan(s.[plan_handle]) AS qp
		CROSS APPLY sys.dm_exec_sql_text(s.[plan_handle]) AS st
	ORDER BY qs.[total_elapsed_time] / DATEDIFF(hh, qs.[creation_time], GETDATE()) DESC
	OPTION (RECOMPILE);
