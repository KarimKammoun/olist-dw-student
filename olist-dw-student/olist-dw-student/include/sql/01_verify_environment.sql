/* Run in SSMS as admin. Checks edition, TCP port, auth mode, schemas, users, grants. */
SELECT @@SERVERNAME AS server_name,
       SERVERPROPERTY('Edition') AS edition,              -- Express Edition (64-bit)
       SERVERPROPERTY('ProductVersion') AS product_version,
       CASE SERVERPROPERTY('IsIntegratedSecurityOnly')
            WHEN 1 THEN 'Windows only - enable Mixed Mode!' ELSE 'Mixed Mode OK' END AS auth_mode;

-- Port SQL Server is actually listening on (Express named instances default to dynamic ports)
SELECT DISTINCT local_tcp_port FROM sys.dm_exec_connections WHERE local_tcp_port IS NOT NULL;

USE OlistDW;
SELECT name FROM sys.schemas WHERE name IN ('raw','staging','marts');
SELECT name, type_desc FROM sys.database_principals WHERE name IN ('olist_ingest','olist_dbt');
SELECT pr.name AS grantee, pe.permission_name, pe.class_desc,
       COALESCE(SCHEMA_NAME(pe.major_id), '') AS on_schema
FROM sys.database_permissions pe
JOIN sys.database_principals pr ON pr.principal_id = pe.grantee_principal_id
WHERE pr.name IN ('olist_ingest','olist_dbt')
ORDER BY grantee, on_schema, permission_name;
