/* =====================================================================
   REFERENCE ONLY - already done by the administrator (Student Lab Guide §5-6).
   Run in SSMS on SQL Server Express (localhost\SQLEXPRESS) as an admin.
   ===================================================================== */
USE master;
GO
IF DB_ID('OlistDW') IS NULL CREATE DATABASE OlistDW;
GO
USE OlistDW;
GO
IF SCHEMA_ID('raw')     IS NULL EXEC('CREATE SCHEMA raw AUTHORIZATION dbo');
IF SCHEMA_ID('staging') IS NULL EXEC('CREATE SCHEMA staging AUTHORIZATION dbo');
IF SCHEMA_ID('marts')   IS NULL EXEC('CREATE SCHEMA marts AUTHORIZATION dbo');
GO
/* Logins (replace passwords!)
CREATE LOGIN olist_ingest_login WITH PASSWORD = 'Replace-With-Unique-Strong-Password-1!';
CREATE LOGIN olist_dbt_login    WITH PASSWORD = 'Replace-With-Unique-Strong-Password-2!';
CREATE USER olist_ingest FOR LOGIN olist_ingest_login;
CREATE USER olist_dbt    FOR LOGIN olist_dbt_login;
GRANT CONNECT TO olist_ingest;  GRANT CONNECT TO olist_dbt;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::raw TO olist_ingest;
GRANT CREATE TABLE TO olist_ingest;
GRANT ALTER ON SCHEMA::raw TO olist_ingest;
GRANT SELECT ON SCHEMA::raw TO olist_dbt;
GRANT CREATE TABLE, CREATE VIEW TO olist_dbt;
GRANT ALTER, SELECT, INSERT, UPDATE, DELETE ON SCHEMA::staging TO olist_dbt;
GRANT ALTER, SELECT, INSERT, UPDATE, DELETE ON SCHEMA::marts   TO olist_dbt;
*/
