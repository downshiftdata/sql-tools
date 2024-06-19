SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;

DECLARE
    @object_name NVARCHAR(128) = N'{object_name}',
    @schema_name NVARCHAR(128) = N'{schema_name}';

DECLARE
    @foreign_key_id INT,
    @full_name NVARCHAR(300),
    @object_id INT,
    @part_comments NVARCHAR(MAX),
    @part_foreign_keys NVARCHAR(MAX),
    @part_parent_columns NVARCHAR(MAX),
    @part_referenced_columns NVARCHAR(MAX),
    @result NVARCHAR(MAX) = N'';

SELECT @full_name = QUOTENAME(@schema_name) + N'.' + QUOTENAME(@object_name);

SELECT @object_id = OBJECT_ID(@full_name);

SELECT @foreign_key_id = MIN(fk.[object_id])
    FROM sys.foreign_keys AS fk
    WHERE fk.[parent_object_id] = @object_id;
WHILE (@foreign_key_id IS NOT NULL)
BEGIN
    SELECT @part_parent_columns = N'', @part_referenced_columns = N'';
    SELECT
            @part_parent_columns += QUOTENAME(cp.[name]) + N','
            @part_referenced_columns += QUOTENAME(cr.[name]) + N','
        FROM sys.foreign_key_columns AS fkc
            INNER JOIN sys.columns AS cp
                ON fkc.[constraint_object_id] = @foreign_key_id
                AND fkc.[parent_object_id] = cp.[object_id]
                AND fkc.[parent_column_id] = cp.[column_id]
            INNER JOIN sys.columns AS cr
                ON fkc.[referenced_object_id] = cr.[object_id]
                AND fkc.[referenced_column_id] = cr.[column_id]
        ORDER BY fkc.[constraint_column_id];
    SELECT
            @part_parent_columns = LEFT(@part_parent_columns, LEN(@part_parent_columns) - 1),
            @part_referenced_columns = LEFT(@part_referenced_columns, LEN(@part_referenced_columns) - 1);

    SELECT @part_foreign_keys += N'
IF NOT EXISTS (SELECT 1
        FROM sys.foreign_keys AS fk
        WHERE fk.[parent_object_id] = OBJECT_ID(N'''
                + @full_name
                + N''')
            AND fk.[name] = N'''
                + fk.[name] + N''')
BEGIN
    ALTER TABLE '
                + @full_name
                + N' WITH NOCHECK ADD
        CONSTRAINT '
                + QUOTENAME(fk.[name])
                + N'
        FOREIGN KEY ('
                + @part_parent_columns
                + N')
        REFERENCES '
                + QUOTENAME(OBJECT_SCHEMA_NAME(fk.[referenced_object_id]))
                + N'.'
                + QUOTENAME(OBJECT_NAME(fk.[referenced_object_id]))
                + N' ('
                + @part_referenced_columns
                + N');
END;
GO'
        FROM sys.foreign_keys AS fk
            INNER JOIN sys.tables AS t
                ON fk.[constraint_object_id] = @foreign_key_id
                AND fk.[referenced_object_id] = t.[object_id];

    SELECT @foreign_key_id = MIN(fk.[object_id])
        FROM sys.foreign_keys AS fk
        WHERE fk.[parent_object_id] = @object_id
            AND fk.[object_id] > @foreign_key_id;
END;

SELECT @result = @part_comments + @part_foreign_keys;

SELECT @result;