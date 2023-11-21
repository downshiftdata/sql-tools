/* Replace schema_name with the desired schema name and execute. */
DECLARE @schema_name NVARCHAR(128) = N'schema_name';

DECLARE
    @column_list NVARCHAR(MAX),
    @key_list NVARCHAR(MAX),
    @max_object_id INT,
    @object_id INT = 0,
    @schema_id INT,
    @stmt NVARCHAR(MAX),
    @table_alias NVARCHAR(128),
    @table_name NVARCHAR(128),
    @template NVARCHAR(MAX);

DROP TABLE IF EXISTS #result;

CREATE TABLE #result (
    [object_id] INT PRIMARY KEY,
    [table_name] NVARCHAR(128),
    [stmt] NVARCHAR(MAX));

SELECT
        @schema_id = [schema_id],
        @schema_name = [name]
    FROM sys.schemas
    WHERE [name] = @schema_name;

IF (@schema_id IS NULL) THROW 50000, N'Invalid Schema', 0;

SELECT @max_object_id = MAX([object_id])
    FROM sys.tables
    WHERE [schema_id] = @schema_id;

IF (@max_object_id IS NULL) THROW 50000, N'No Tables', 1;

SELECT @template = N'/* https://github.com/downshiftdata/sql-tools gen_select */
CREATE OR ALTER PROCEDURE [{schema_name}].[{table_name}_Select]
AS
BEGIN
    SET NOCOUNT ON;
    SELECT{column_list}
        FROM [{schema_name}].[{table_name}] AS {table_alias}
        ORDER BY{key_list};
    RETURN @@ROWCOUNT;
END;
GO';

WHILE (@object_id < @max_object_id)
BEGIN
    SELECT
        @column_list = N'',
        @key_list = N'',
        @stmt = @template;

    SELECT @object_id = MIN([object_id])
        FROM sys.tables
        WHERE [schema_id] = @schema_id
            AND [object_id] > @object_id;

    SELECT @table_name = OBJECT_NAME(@object_id);

    SELECT @table_alias = LOWER(LEFT(@table_name, 1)) + N'1';

    SELECT @column_list += N'
            {table_alias}.' + QUOTENAME([name]) + N','
        FROM sys.columns
        WHERE [object_id] = @object_id
        ORDER BY [column_id];

    SELECT @key_list += N'
            {table_alias}.' + QUOTENAME(c.[name]) + N','
        FROM sys.index_columns AS ic
            INNER JOIN sys.columns AS c
                ON ic.[object_id] = @object_id
                AND ic.[index_id] = 1
                AND c.[object_id] = @object_id
                AND ic.[column_id] = c.[column_id]
                AND ic.[key_ordinal] > 0
        ORDER BY ic.[key_ordinal];

    IF (LEN(@column_list) > 0) SELECT @column_list = LEFT(@column_list, LEN(@column_list) - 1);
    IF (LEN(@key_list) > 0) SELECT @key_list = LEFT(@key_list, LEN(@key_list) - 1);

    SELECT @stmt = REPLACE(@stmt, N'{column_list}', @column_list);
    SELECT @stmt = REPLACE(@stmt, N'{key_list}', @key_list);

    SELECT @stmt = REPLACE(@stmt, N'{schema_name}', @schema_name);
    SELECT @stmt = REPLACE(@stmt, N'{table_alias}', @table_alias);
    SELECT @stmt = REPLACE(@stmt, N'{table_name}', @table_name);

    INSERT INTO #result ([object_id], [table_name], [stmt])
        SELECT @object_id, @table_name, @stmt;
END;

SELECT [object_id], [table_name], [stmt]
    FROM #result
    ORDER BY [table_name];
