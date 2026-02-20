SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;
WITH ps AS (SELECT TOP (1000)
            ps.[database_id],
            ps.[object_id],
            ps.[plan_handle],
            ps.[cached_time],
            ps.[execution_count],
            ps.[total_worker_time],
            ps.[total_physical_reads],
            ps.[total_logical_writes],
            ps.[total_logical_reads],
            ps.[total_elapsed_time]
        FROM sys.dm_exec_procedure_stats AS ps
        WHERE DATEDIFF(mi, ps.[cached_time], GETDATE()) >= 2
        ORDER BY ps.[total_elapsed_time] / DATEDIFF(mi, ps.[cached_time], GETDATE()) DESC)
SELECT
        DB_NAME(ps.[database_id]) + N'.' + OBJECT_SCHEMA_NAME(ps.[object_id]) + N'.' + OBJECT_NAME(ps.[object_id]) AS [full_name],
        ps.[cached_time],
        cp.[size_in_bytes] / 1024 AS [cache_size_kb],
        ps.[execution_count] / DATEDIFF(mi, ps.[cached_time], GETDATE()) AS [exec_per_min],
        ps.[total_worker_time] / DATEDIFF(mi, ps.[cached_time], GETDATE()) AS [worker_time_per_min],
        ps.[total_physical_reads] / DATEDIFF(mi, ps.[cached_time], GETDATE()) AS [physical_reads_per_min],
        ps.[total_logical_writes] / DATEDIFF(mi, ps.[cached_time], GETDATE()) AS [logical_writes_per_min],
        ps.[total_logical_reads] / DATEDIFF(mi, ps.[cached_time], GETDATE()) AS [logical_reads_per_min],
        ps.[total_elapsed_time] / DATEDIFF(mi, ps.[cached_time], GETDATE()) AS [elapsed_time_per_min],
        qp.[query_plan]
    FROM ps
        INNER JOIN sys.dm_exec_cached_plans AS cp
            ON ps.[plan_handle] = cp.[plan_handle]
        CROSS APPLY sys.dm_exec_query_plan(ps.[plan_handle]) AS qp
    ORDER BY ps.[total_elapsed_time] / DATEDIFF(mi, ps.[cached_time], GETDATE()) DESC
    OPTION (RECOMPILE);
