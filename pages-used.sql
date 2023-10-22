SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;
SELECT TOP 100
        OBJECT_SCHEMA_NAME(p.[object_id]) AS [schema_name],
        OBJECT_NAME(p.[object_id]) AS [object_name],
        p.[index_id] AS [index_id],
        p.[data_compression_desc] AS [compression_type],
        COUNT(DISTINCT p.[partition_id]) AS [partition_count],
        SUM(ddps.[row_count]) AS [row_count],
        SUM(ddps.[used_page_count]) AS [used_page_count],
        CASE SUM(ddps.[used_page_count]) WHEN 0 THEN 0 ELSE SUM(ddps.[in_row_used_page_count]) * 100 / SUM(ddps.[used_page_count]) END AS [in_row_page_rate],
        CASE SUM(ddps.[used_page_count]) WHEN 0 THEN 0 ELSE SUM(ddps.[lob_used_page_count]) * 100 / SUM(ddps.[used_page_count]) END AS [lob_page_rate],
        CASE SUM(ddps.[used_page_count]) WHEN 0 THEN 0 ELSE SUM(ddps.[row_overflow_used_page_count]) * 100 / SUM(ddps.[used_page_count]) END AS [overflow_page_rate]
    FROM sys.partitions AS p
        INNER JOIN sys.dm_db_partition_stats AS ddps
            ON p.[object_id] = ddps.[object_id]
            AND p.[partition_id] = ddps.[partition_id]
    GROUP BY
        p.[object_id],
        P.[index_id],
        p.[data_compression_desc]
    ORDER BY SUM(ddps.[used_page_count]) DESC
    OPTION (RECOMPILE);
