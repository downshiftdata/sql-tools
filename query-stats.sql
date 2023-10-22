SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;
DROP TABLE IF EXISTS #qs;
CREATE TABLE #qs (
    [plan_handle] VARBINARY(64) NOT NULL,
    [plan_generation_num] BIGINT NOT NULL,
    [i] INT IDENTITY(1,1) NOT NULL,
    [statement_start_offset] INT NOT NULL,
    [statement_end_offset] INT NOT NULL,
    [creation_time] DATETIME NOT NULL,
    [execution_count] BIGINT NOT NULL,
    [total_worker_time] BIGINT NOT NULL,
    [total_physical_reads] BIGINT NOT NULL,
    [total_logical_writes] BIGINT NOT NULL,
    [total_logical_reads] BIGINT NOT NULL,
    [total_elapsed_time] BIGINT NOT NULL,
    PRIMARY KEY ([plan_handle], [plan_generation_num], [i]));
INSERT INTO #qs (
        [plan_handle],
        [plan_generation_num],
        [statement_start_offset],
        [statement_end_offset],
        [creation_time],
        [execution_count],
        [total_worker_time],
        [total_physical_reads],
        [total_logical_writes],
        [total_logical_reads],
        [total_elapsed_time])
    SELECT TOP (1000)
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
        WHERE DATEDIFF(mi, qs.[creation_time], GETDATE()) >= 1
        ORDER BY qs.[total_elapsed_time] / DATEDIFF(mi, qs.[creation_time], GETDATE()) DESC;
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
    FROM #qs AS qs
        INNER JOIN sys.dm_exec_cached_plans AS cp
            ON qs.[plan_handle] = cp.[plan_handle]
        CROSS APPLY sys.dm_exec_query_plan(qs.[plan_handle]) AS qp
        CROSS APPLY sys.dm_exec_sql_text(qs.[plan_handle]) AS st
    ORDER BY qs.[total_elapsed_time] / DATEDIFF(mi, qs.[creation_time], GETDATE()) DESC
    OPTION (RECOMPILE);
