SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;

DECLARE
    @object_name NVARCHAR(128) = N'{object_name}',
    @schema_name NVARCHAR(128) = N'{schema_name}';

DECLARE
	@full_name NVARCHAR(300),
    @length_new INT = 0,
    @length_old INT = 1,
    @object_id INT,
    @result NVARCHAR(MAX);

SELECT @full_name = QUOTENAME(@schema_name) + N'.' + QUOTENAME(@object_name);

SELECT @object_id = OBJECT_ID(@full_name);

SELECT @result = OBJECT_DEFINITION(@object_id);

/* NOTE: Does OBJECT_DEFINITION always return those 3 spaces? */
SELECT @result = REPLACE(@result, N'CREATE   PROCEDURE', N'CREATE OR ALTER PROCEDURE');

SELECT @result = N'/* Auto-Generated at ' + CONVERT(NVARCHAR(24), GETUTCDATE(), 121) + N' */
' + @result;

/* Replace tabs with spaces. */
SELECT @result = REPLACE(@result, CHAR(9), N'    ');

/* TODO: Replace LF with CR/LF */

/* Remove trailing spaces */
WHILE (@length_new < @length_old)
BEGIN
    SELECT @length_old = LEN(@result);
    SELECT @result = REPLACE(@result, N' ' + CHAR(13) + CHAR(10), CHAR(13) + CHAR(10));
    SELECT @length_new = LEN(@result);
END;

print @result;
