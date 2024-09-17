/*
    Displays active sessions on the database.
*/
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;
SELECT
        r.[session_id] AS [spid],
        r.[start_time],
        DATEDIFF(mi, r.[start_time], GETDATE()) AS [age_in_min],
        s.[login_name],
        SUBSTRING(st.[text],
            r.[statement_start_offset] / 2 + 1,
            CASE r.[statement_end_offset] WHEN -1 THEN DATALENGTH(st.[text]) ELSE r.[statement_end_offset] END - r.[statement_start_offset] / 2 + 1) AS [stmt],
        r.[blocking_session_id] AS [blocking_spid],
        r.[wait_type],
        r.[last_wait_type],
        r.[wait_resource],
        r.[cpu_time],
        CASE s.[transaction_isolation_level]
                       WHEN 1 THEN 'NOLOCK'
                       WHEN 2 THEN 'READCOMMITTED'
                       WHEN 3 THEN 'REPEATABLEREAD'
                       WHEN 4 THEN 'SERIALIZABLE!'
                       WHEN 5 THEN 'SNAPSHOT'
                       ELSE 'WTF?'
                    END AS [lock_level],
        DB_NAME(r.[database_id]) AS [db_name],
        r.[total_elapsed_time],
        r.[reads],
        r.[writes],
        r.[logical_reads],
        r.[status],
        c.[client_net_address],
        qp.[query_plan].value(N'(//@StatementText)[1]', N'NVARCHAR(MAX)') AS [stmt1],
        qp.[query_plan]
    FROM sys.dm_exec_requests AS r
        INNER JOIN sys.dm_exec_sessions AS s
            ON r.[session_id] = s.[session_id]
        CROSS APPLY sys.dm_exec_sql_text(r.[sql_handle]) AS st
        LEFT JOIN sys.dm_exec_connections AS c
            ON r.[connection_id] = c.[connection_id]
        CROSS APPLY sys.dm_exec_query_plan(r.[plan_handle]) AS qp
    WHERE r.[session_id] != @@SPID
    ORDER BY r.[start_time]
    OPTION (RECOMPILE);
GO
