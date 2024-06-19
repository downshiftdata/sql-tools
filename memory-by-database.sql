SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;
DECLARE @total_pages BIGINT;
SELECT @total_pages = [cntr_value]
    FROM sys.dm_os_performance_counters
    WHERE RIGHT(RTRIM([object_name]), 14) = 'Buffer Manager'
        AND [counter_name] = N'Database Pages'
    OPTION (RECOMPILE);
WITH cte AS (SELECT
        [database_id],
        COUNT_BIG(*) AS [page_count]
    FROM sys.dm_os_buffer_descriptors
    GROUP BY [database_id])
SELECT
        [database_id],
        CASE [database_id]
            WHEN 32767 THEN N'Resource'
            ELSE DB_NAME([database_id]) END AS [database_name],
        [page_count],
        [page_count] / 128 AS [size_in_mb],
        CAST([page_count] * 100.0 / @total_pages AS DECIMAL(5,2)) AS [pct_of_total]
    FROM cte
    ORDER BY [page_count] DESC
    OPTION (RECOMPILE);
