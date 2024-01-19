SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;

DECLARE
    @object_name NVARCHAR(128) = N'{object_name}',
    @schema_name NVARCHAR(128) = N'{schema_name}';

DECLARE
    @data_compression TINYINT,
    @full_name NVARCHAR(300),
    @index_id INT,
    @index_name NVARCHAR(128),
    @is_primary_key BIT,
    @is_unique BIT,
    @is_unique_constraint BIT,
    @object_id INT,
    @part_columns NVARCHAR(MAX) = N'',
    @part_comments NVARCHAR(MAX),
    @part_index NVARCHAR(MAX),
    @part_index_columns NVARCHAR(MAX) = N'',
    @part_with NVARCHAR(MAX),
    @result NVARCHAR(MAX) = N'';

SELECT @full_name = QUOTENAME(@schema_name) + N'.' + QUOTENAME(@object_name);

SELECT @object_id = OBJECT_ID(@full_name);

SELECT
        @index_id = i.[index_id],
        @index_name = i.[name],
        @is_primary_key = i.[is_primary_key],
        @is_unique = i.[is_unique],
        @is_unique_constraint = i.[is_unique_constraint],
        @data_compression = p.[data_compression]
    FROM sys.indexes AS i
        INNER JOIN sys.partitions AS p
            ON i.[object_id] = @object_id
            AND i.[index_id] BETWEEN 0 AND 1
            AND i.[object_id] = p.[object_id]
            AND i.[index_id] = p.[index_id];

IF EXISTS (SELECT 1
        FROM sys.partitions
        WHERE [object_id] = @object_id
            AND [partition_number] > 1)
    THROW 60000, N'Partitioned Tables Not Supported', 0;
IF (@data_compression > 2)
    THROW 60000, N'Columnstore Not Supported', 0;

SELECT @part_comments = N'/* Auto-Generated at ' + CONVERT(NVARCHAR(24), GETUTCDATE(), 121) + N' */'

SELECT @part_columns += N'
        ' + QUOTENAME(c.[name])
            + N' ' + UPPER(t.[name])
            + CASE c.[user_type_id]
                WHEN 106 THEN N'(' + CAST(c.[precision] AS NVARCHAR(20)) + N',' + CAST(c.[scale] AS NVARCHAR(20)) + N')'
                WHEN 108 THEN N'(' + CAST(c.[precision] AS NVARCHAR(20)) + N',' + CAST(c.[scale] AS NVARCHAR(20)) + N')'
                WHEN 165 THEN CASE c.[max_length] WHEN -1 THEN N'(MAX)' ELSE N'(' + CAST(c.[max_length] AS NVARCHAR(20)) + N')' END
                WHEN 167 THEN CASE c.[max_length] WHEN -1 THEN N'(MAX)' ELSE N'(' + CAST(c.[max_length] AS NVARCHAR(20)) + N')' END
                WHEN 173 THEN N'(' + CAST(c.[max_length] AS NVARCHAR(20)) + N')'
                WHEN 175 THEN N'(' + CAST(c.[max_length] AS NVARCHAR(20)) + N')'
                WHEN 231 THEN CASE c.[max_length] WHEN -1 THEN N'(MAX)' ELSE N'(' + CAST(c.[max_length] / 2 AS NVARCHAR(20)) + N')' END
                WHEN 239 THEN N'(' + CAST(c.[max_length] / 2 AS NVARCHAR(20)) + N')'
                ELSE N'' END
            + CASE WHEN c.[is_nullable] = 1 THEN N' NULL' ELSE N' NOT NULL' END
            + CASE WHEN c.[is_identity] = 1 THEN N' IDENTITY(1,1)' ELSE N'' END
            + N','
    FROM sys.columns AS c
        INNER JOIN sys.types AS t
            ON c.[user_type_id] = t.[user_type_id]
    WHERE c.[object_id] = @object_id
    ORDER BY c.[column_id];

IF (@index_id = 0)
BEGIN
    SELECT @part_columns = LEFT(@part_columns, LEN(@part_columns) - 1);
    SELECT @part_comments += N'
/* WARNING: Heap */';
END;
ELSE
BEGIN
    SELECT @part_index_columns += QUOTENAME(c.[name]) + CASE ic.[is_descending_key] WHEN 1 THEN N' DESC' ELSE N'' END + N','
        FROM sys.index_columns AS ic
            INNER JOIN sys.columns AS c
                ON ic.[object_id] = @object_id
                AND ic.[index_id] = @index_id
                AND ic.[object_id] = c.[object_id]
                AND ic.[column_id] = c.[column_id]
        ORDER BY ic.[index_column_id];
    SELECT @part_index_columns = LEFT(@part_index_columns, LEN(@part_index_columns) - 1);
    SELECT @part_index = N'
        ' + CASE
            WHEN @is_primary_key = 1 OR @is_unique_constraint = 1 THEN N'CONSTRAINT'
            ELSE N'INDEX' END
        + N' ' + QUOTENAME(@index_name)
        + CASE
            WHEN @is_primary_key = 1 THEN N' PRIMARY KEY'
            WHEN @is_unique_constraint = 1 THEN N' UNIQUE'
            ELSE N' ' END
        + N'(' + @part_index_columns + N')';
END;

SELECT @part_with = N'
        WITH (DATA_COMPRESSION = ' + CASE @data_compression WHEN 0 THEN N'NONE' WHEN 1 THEN N'ROW' WHEN 2 THEN N'PAGE' END + N')';

SELECT @result = @part_comments + N'
IF (SELECT OBJECT_ID(N''' + @full_name + N''') IS NULL)
BEGIN
    CREATE TABLE ' + @full_name + N' (' + @part_columns + @part_index + N')' + @part_with + N';
END;';

print @result;
