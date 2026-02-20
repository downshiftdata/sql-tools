SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;
WITH qs AS (SELECT TOP (1000)
            qs.[plan_handle],
            qs.[plan_generation_num],
            qs.[statement_start_offset],
            qs.[statement_end_offset],
            qs.[creation_time],
            qs.[execution_count],
            qs.[total_worker_time],
            qs.[total_physical_reads],
            qs.[total_logical_writes],
            qs.[total_logical_reads],
            qs.[total_elapsed_time]
        FROM sys.dm_exec_query_stats AS qs
        WHERE DATEDIFF(mi, qs.[creation_time], GETDATE()) >= 2
        ORDER BY qs.[total_elapsed_time] / DATEDIFF(mi, qs.[creation_time], GETDATE()) DESC)
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
        qs.[execution_count] / DATEDIFF(mi, qs.[creation_time], GETDATE()) AS [exec_per_min],
        qs.[total_worker_time] / DATEDIFF(mi, qs.[creation_time], GETDATE()) AS [worker_time_per_min],
        qs.[total_physical_reads] / DATEDIFF(mi, qs.[creation_time], GETDATE()) AS [physical_reads_per_min],
        qs.[total_logical_writes] / DATEDIFF(mi, qs.[creation_time], GETDATE()) AS [logical_writes_per_min],
        qs.[total_logical_reads] / DATEDIFF(mi, qs.[creation_time], GETDATE()) AS [logical_reads_per_min],
        qs.[total_elapsed_time] / DATEDIFF(mi, qs.[creation_time], GETDATE()) AS [elapsed_time_per_min],
        qp.[query_plan]
    FROM qs
        INNER JOIN sys.dm_exec_cached_plans AS cp
            ON qs.[plan_handle] = cp.[plan_handle]
        CROSS APPLY sys.dm_exec_query_plan(qs.[plan_handle]) AS qp
        CROSS APPLY sys.dm_exec_sql_text(qs.[plan_handle]) AS st
    ORDER BY qs.[total_elapsed_time] / DATEDIFF(mi, qs.[creation_time], GETDATE()) DESC
    OPTION (RECOMPILE);
