CREATE OR ALTER FUNCTION GetTypeString(
    @objectId INT,
    @columnId INT)
    RETURNS NVARCHAR(256)
AS
BEGIN
    DECLARE @result NVARCHAR(256);
    SELECT @result = UPPER(t.[name]) + CASE t.[system_type_id]
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
                ELSE N'' END
        FROM sys.columns AS c
            INNER JOIN sys.types AS t
                ON c.[object_id] = @objectId
                AND c.[column_id] = @columnId
                AND c.[user_type_id] = t.[user_type_id];
    RETURN @result;
END;
GO

