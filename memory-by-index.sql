SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;
WITH cte AS (SELECT
        p.[object_id],
        s.[name] AS [schema_name],
        o.[name] AS [object_name],
        o.[type_desc] AS [object_type],
        p.[index_id],
        i.[name] AS [index_name],
        i.[type_desc] AS [index_type],
        au.[allocation_unit_id]
    FROM sys.partitions AS p
        INNER JOIN sys.allocation_units AS au
            ON p.[hobt_id] = au.[container_id]
            AND au.[type] BETWEEN 1 AND 3
        INNER JOIN sys.objects AS o
            ON p.[object_id] = o.[object_id]
            AND o.[is_ms_shipped] = 0
        INNER JOIN sys.schemas AS s
            ON o.[schema_id] = s.[schema_id]
        INNER JOIN sys.indexes AS i
            ON p.[object_id] = i.[object_id]
            AND p.[object_id] = i.[object_id])
SELECT
        cte.[object_id],
        cte.[schema_name],
        cte.[object_name],
        cte.[object_type],
        cte.[index_id],
        cte.[index_name],
        cte.[index_type],
        COUNT_BIG(dobd.[page_id]) AS [page_count],
        COUNT_BIG(dobd.[page_id]) / 128 AS [size_in_mb]
    FROM cte
        INNER JOIN sys.dm_os_buffer_descriptors AS dobd
            ON cte.[allocation_unit_id] = dobd.[allocation_unit_id]
            AND dobd.[database_id] = DB_ID()
    GROUP BY
        cte.[object_id],
        cte.[schema_name],
        cte.[object_name],
        cte.[object_type],
        cte.[index_id],
        cte.[index_name],
        cte.[index_type]
    ORDER BY [page_count] DESC
    OPTION (RECOMPILE);

