SELECT TOP 100
        OBJECT_SCHEMA_NAME(i.[object_id]) + N'.' + OBJECT_NAME(i.[object_id]) + N'.' +  i.[name] AS [full_name],
        ddius.[user_updates] AS [writes],
        ddius.[user_seeks] + ddius.[user_scans] + ddius.[user_lookups] AS [reads],
        CAST((ddius.[user_seeks] + ddius.[user_scans] + ddius.[user_lookups]) * 100.0 / ddius.[user_updates] AS DECIMAL(18,4)) AS [ratio]
    FROM sys.dm_db_index_usage_stats AS ddius
        INNER JOIN sys.indexes AS i
            ON ddius.[object_id] = i.[object_id]
            AND ddius.[index_id] = i.[index_id]
            AND i.[type] = 2 -- Nonclustered
    WHERE OBJECTPROPERTY(ddius.[object_id], 'IsMsShipped') = 0
        AND ddius.[user_updates] > 0
    ORDER BY
        (ddius.[user_seeks] + ddius.[user_scans] + ddius.[user_lookups]) * 100.0 / ddius.[user_updates],
        ddius.[user_updates] DESC
    OPTION (RECOMPILE);
