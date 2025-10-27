DECLARE
    @appName NVARCHAR(128) = N'foobar',
    @sessionName NVARCHAR(128) = N'xe-app-monitor',
    @stmt NVARCHAR(4000);

SELECT @stmt = N'/* xe-app-monitor */
ALTER EVENT SESSION ' + QUOTENAME(@sessionName) + N'
    ON SERVER STATE STOP;';
PRINT @stmt;
SELECT @stmt = N'/* xe-app-monitor */
DROP EVENT SESSION ' + QUOTENAME(@sessionName) + N'
    ON SERVER;';
PRINT @stmt;

SELECT @stmt = N'/* xe-app-monitor */
CREATE EVENT SESSION ' + QUOTENAME(@sessionName) + N'
    ON SERVER
    ADD EVENT sqlserver.sql_batch_starting (
        WHERE (sqlserver.client_app_name = N' + QUOTENAME(@appName, '''') + N')
        ACTION (sqlserver.sql_text, sqlserver.client_hostname, sqlserver.username, sqlserver.database_name, sqlserver.session_id)),
    ADD EVENT sqlserver.sql_batch_completed (
        WHERE (sqlserver.client_app_name = N' + QUOTENAME(@appName, '''') + N')
        ACTION (sqlserver.sql_text, sqlserver.client_hostname, sqlserver.username, sqlserver.database_name, sqlserver.session_id)),
    ADD EVENT sqlserver.rpc_starting (
        WHERE (sqlserver.client_app_name = N' + QUOTENAME(@appName, '''') + N')
        ACTION (sqlserver.sql_text, sqlserver.client_hostname, sqlserver.username, sqlserver.database_name, sqlserver.session_id)),
    ADD EVENT sqlserver.rpc_completed (
        WHERE (sqlserver.client_app_name = N' + QUOTENAME(@appName, '''') + N')
        ACTION (sqlserver.sql_text, sqlserver.client_hostname, sqlserver.username, sqlserver.database_name, sqlserver.session_id)),
    ADD EVENT sqlserver.sql_statement_starting (
        WHERE (sqlserver.client_app_name = N' + QUOTENAME(@appName, '''') + N')
        ACTION (sqlserver.sql_text, sqlserver.client_hostname, sqlserver.username, sqlserver.database_name, sqlserver.session_id)),
    ADD EVENT sqlserver.sql_statement_completed (
        WHERE (sqlserver.client_app_name = N' + QUOTENAME(@appName, '''') + N')
        ACTION (sqlserver.sql_text, sqlserver.client_hostname, sqlserver.username, sqlserver.database_name, sqlserver.session_id))
    ADD TARGET package0.ring_buffer(SET max_memory = 4096)
    WITH (
        MAX_MEMORY = 4096 KB,
        EVENT_RENTENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
        MAX_DISPATCH_LATENCY = 5 SECONDS,
        TRACK_CAUSALITY = ON,
        STARTUP_STATE = OFF);';
PRINT @stmt;

SELECT @stmt = N'/* xe-app-monitor */
ALTER EVENT SESSION ' + QUOTENAME(@sessionName) + N'
    ON SERVER STATE = START;';
PRINT @stmt;

WITH rb AS (
    SELECT CAST(t.target_data AS XML) AS target_xml
        FROM sys.dm_xe_sessions s
            INNER JOIN sys.dm_xe_session_targets t
                ON s.address = t.event_session_address
                AND s.name = @SessionName
                AND t.target_name = 'ring_buffer')
SELECT
        Evt.value('@name','nvarchar(200)') AS event_name,
        Evt.value('@timestamp','bigint') AS timestamp_raw,
        Evt.query('.') AS event_xml
    FROM rb
        CROSS APPLY rb.target_xml.nodes('/RingBufferTarget/event') AS X(Evt)
    ORDER BY timestamp_raw;
