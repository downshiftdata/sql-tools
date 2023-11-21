/* Replace schema_name with the desired schema name and execute. */
DECLARE @schema_name NVARCHAR(128) = N'schema_name';

DECLARE
    @column_list NVARCHAR(MAX),
    @max_object_id INT,
    @object_id INT = 0,
    @parameter_list NVARCHAR(MAX),
    @return NVARCHAR(MAX),
    @schema_id INT,
    @stmt NVARCHAR(MAX),
    @table_name NVARCHAR(128),
    @template NVARCHAR(MAX),
    @value_list NVARCHAR(MAX);

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

SELECT @template = N'/* https://github.com/downshiftdata/sql-tools gen_insert */
CREATE OR ALTER PROCEDURE [{schema_name}].[{table_name}_Insert]{parameter_list}
AS
BEGIN
    SET NOCOUNT ON;
    INSERT INTO [{schema_name}].[{table_name}] ({column_list})
        SELECT{value_list};
    {return}
END;
GO';

WHILE (@object_id < @max_object_id)
BEGIN
    SELECT
        @column_list = N'',
        @parameter_list = N'',
        @stmt = @template,
        @value_list = N'';

    SELECT @object_id = MIN([object_id])
        FROM sys.tables
        WHERE [schema_id] = @schema_id
            AND [object_id] > @object_id;

    SELECT @table_name = OBJECT_NAME(@object_id);

    IF EXISTS (SELECT 1
            FROM sys.columns
            WHERE [object_id] = @object_id
                AND [is_identity] = 1)
    BEGIN
        SELECT @return = N'SELECT @' + [name] + N' = SCOPE_IDENTITY();
    IF (@' + [name] + N' IS NULL) RETURN 0 ELSE RETURN 1;'
            FROM sys.columns
            WHERE [object_id] = @object_id
                AND [is_identity] = 1;
    END;
    ELSE
    BEGIN
        SELECT @return = N'RETURN @@ROWCOUNT;';
    END;

    SELECT
            @column_list += CASE WHEN c.[is_identity] = 1 THEN N'' ELSE N'
            ' + QUOTENAME(c.[name]) + N',' END,
            @parameter_list += N'
    @' + c.[name] + N' ' + UPPER(t.[name]) + CASE t.[system_type_id]
                WHEN 106 THEN N'(' + CAST(c.[precision] AS NVARCHAR(20)) + N',' + CAST(c.[scale] AS NVARCHAR(20)) + N')' /* decimal */
                WHEN 108 THEN N'(' + CAST(c.[precision] AS NVARCHAR(20)) + N',' + CAST(c.[scale] AS NVARCHAR(20)) + N')' /* numeric */
                WHEN 165 THEN CASE
                    WHEN c.[max_length] = -1 THEN N'(MAX)'
                    ELSE N'(' + CAST(c.[max_length] AS NVARCHAR(20)) + N')' END /* varbinary */
                WHEN 167 THEN CASE
                    WHEN c.[max_length] = -1 THEN N'(MAX)'
                    ELSE N'(' + CAST(c.[max_length] AS NVARCHAR(20)) + N')' END /* varchar */
                WHEN 173 THEN N'(' + CAST(c.[max_length] AS NVARCHAR(20)) + N')' /* binary */
                WHEN 175 THEN N'(' + CAST(c.[max_length] AS NVARCHAR(20)) + N')' /* char */
                WHEN 231 THEN CASE
                    WHEN c.[max_length] = -1 THEN N'(MAX)'
                    ELSE N'(' + CAST(c.[max_length] / 2 AS NVARCHAR(20)) + N')' END /* nvarchar */
                WHEN 239 THEN N'(' + CAST(c.[max_length] / 2 AS NVARCHAR(20)) + N')' /* nchar */
                ELSE N'' END + CASE WHEN c.[is_identity] = 1 THEN N' OUT' ELSE N'' END + N',',
            @value_list += CASE WHEN c.[is_identity] = 1 THEN N'' ELSE N'
            @' + c.[name] + N',' END
        FROM sys.columns AS c
            INNER JOIN sys.types AS t
                ON c.[object_id] = @object_id
                AND c.[user_type_id] = t.[user_type_id]
        ORDER BY c.[column_id];

    SELECT @column_list = LEFT(@column_list, LEN(@column_list) - 1);
    SELECT @parameter_list = LEFT(@parameter_list, LEN(@parameter_list) - 1);
    SELECT @value_list = LEFT(@value_list, LEN(@value_list) - 1);

    SELECT @stmt = REPLACE(@stmt, N'{column_list}', @column_list);
    SELECT @stmt = REPLACE(@stmt, N'{parameter_list}', @parameter_list);
    SELECT @stmt = REPLACE(@stmt, N'{value_list}', @value_list);

    SELECT @stmt = REPLACE(@stmt, N'{return}', @return);
    SELECT @stmt = REPLACE(@stmt, N'{schema_name}', @schema_name);
    SELECT @stmt = REPLACE(@stmt, N'{table_name}', @table_name);

    INSERT INTO #result ([object_id], [table_name], [stmt])
        SELECT @object_id, @table_name, @stmt;
END;

SELECT [object_id], [table_name], [stmt]
    FROM #result
    ORDER BY [table_name];
