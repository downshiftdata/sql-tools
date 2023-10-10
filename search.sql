/*
    A rudimentary text search function. Replace the value on line 8.
*/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;
DECLARE @search NVARCHAR(4000);

SELECT @search = N'foobar';

SELECT
        o.[type],
        SCHEMA_NAME(o.[schema_id]) + N'.' + OBJECT_NAME(o.[object_id]) AS [name],
        m.[definition]
    FROM sys.objects AS o
        LEFT JOIN sys.sql_modules AS m
            ON o.[object_id] = m.[object_id]
    WHERE o.[name] LIKE N'%' + @search + N'%' ESCAPE N'`'
        OR m.[definition] LIKE N'%' + @search + N'%' ESCAPE N'`'
        OR EXISTS (SELECT 1
                FROM sys.columns AS c
                WHERE o.[object_id] = c.[object_id]
                    AND c.[name] LIKE N'%' + @search + N'%' ESCAPE N'`')
    ORDER BY
        o.[type],
        SCHEMA_NAME(o.[schema_id]) + N'.' + OBJECT_NAME(o.[object_id])
    OPTION (RECOMPILE);
GO
