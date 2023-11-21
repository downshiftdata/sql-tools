SET NOCOUNT ON;

IF (OBJECT_ID(N'dbo.nums') IS NULL)
BEGIN
    CREATE TABLE [dbo].[nums] (
        [i] INT IDENTITY(1,1) NOT NULL,
        CONSTRAINT [pk_dbo_nums] PRIMARY KEY ([i]));
END;

DECLARE @n INT, @max INT = 1000;
SELECT @n = MAX([i]) FROM [dbo].[nums];
IF (ISNULL(@n, 0) < @max)
BEGIN
    WHILE (ISNULL(SCOPE_IDENTITY(), 0) < @max)
    BEGIN
        INSERT INTO [dbo].[nums] DEFAULT VALUES;
    END;
END;
