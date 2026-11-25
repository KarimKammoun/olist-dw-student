/* ============================================================================
   Fix the two SQL logins used by Airflow  (run in SSMS, USE master, as admin)
   ============================================================================
   Symptom: the connection mssql_dbt fails in Airflow ("Login failed for user
   'olist_dbt_login'") while mssql_raw works.

   Two independent things must be true, and they are checked here:
     1. the LOGIN exists at server level, is ENABLED, and the password is known
        (mssql_ingest works, so its login is fine - mssql_dbt has no reason to
        work if the login was dropped with the database or if its password
        was changed when the .env was updated);
     2. the USER exists inside OlistDW, because the connection points at the
        Schema/Database OlistDW: without the user, a correct login still gives
        "Cannot open database OlistDW requested by the login" (error 4060).

   The two logins are recreated if missing, their password is set to a known
   value, and the users + grants are restored. Re-runnable without error.
   ============================================================================ */

USE master;
GO

/* ---------------------------------------------------------- 1. report */
PRINT '--- 1. before ---------------------------------------------------------';
SELECT name, type_desc, is_disabled,
       LOGINPROPERTY(name, 'IsLocked')     AS is_locked,
       LOGINPROPERTY(name, 'IsMustChange') AS must_change
FROM sys.server_principals
WHERE name IN ('olist_ingest_login', 'olist_dbt_login');
GO

/* ---------------------------------------------------------- 2. create if missing */
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'olist_ingest_login')
    CREATE LOGIN olist_ingest_login WITH PASSWORD = 'OlistIngest2026!', CHECK_POLICY = OFF;
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'olist_dbt_login')
    CREATE LOGIN olist_dbt_login WITH PASSWORD = 'OlistDbt2026!', CHECK_POLICY = OFF;
GO

/* ---------------------------------------------------------- 3. known password + unlocked
   CHECK_POLICY = OFF avoids "the password must be changed" (error 18487/18488).
   Change the two passwords below if you want your own, and keep .env + Airflow
   connections in sync. */
ALTER LOGIN olist_ingest_login WITH PASSWORD = 'OlistIngest2026!', CHECK_POLICY = OFF;
ALTER LOGIN olist_dbt_login    WITH PASSWORD = 'OlistDbt2026!',    CHECK_POLICY = OFF;
GO
ALTER LOGIN olist_ingest_login ENABLE;
ALTER LOGIN olist_dbt_login    ENABLE;
GO
ALTER LOGIN olist_ingest_login WITH PASSWORD = 'OlistIngest2026!' UNLOCK;
ALTER LOGIN olist_dbt_login    WITH PASSWORD = 'OlistDbt2026!' UNLOCK;
GO

/* ---------------------------------------------------------- 4. users + grants in OlistDW */
USE OlistDW;
GO
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'olist_ingest')
    CREATE USER olist_ingest FOR LOGIN olist_ingest_login;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'olist_dbt')
    CREATE USER olist_dbt FOR LOGIN olist_dbt_login;
GO

GRANT CONNECT TO olist_ingest;
GRANT CONNECT TO olist_dbt;
GRANT CREATE TABLE TO olist_ingest;
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::raw TO olist_ingest;
GRANT ALTER ON SCHEMA::raw TO olist_ingest;
GRANT SELECT ON SCHEMA::raw TO olist_dbt;
GRANT CREATE TABLE, CREATE VIEW TO olist_dbt;
GRANT ALTER, SELECT, INSERT, UPDATE, DELETE ON SCHEMA::staging TO olist_dbt;
GRANT ALTER, SELECT, INSERT, UPDATE, DELETE ON SCHEMA::marts   TO olist_dbt;
GRANT SELECT ON sys.sql_expression_dependencies TO olist_dbt;
GRANT VIEW DEFINITION ON DATABASE::OlistDW TO olist_dbt;
GO

/* ---------------------------------------------------------- 5. proof: become olist_dbt
   If this block fails, the message says exactly what is wrong:
     18456 -> the password of the login is not OlistDbt2026!
     4060  -> the user olist_dbt is missing in OlistDW
     229   -> the grants are missing */
EXECUTE AS USER = 'olist_dbt';
    SELECT SUSER_SNAME() AS login_effectif, USER_NAME() AS user_effectif, DB_NAME() AS base_effective;
    SELECT COUNT(*) AS objets_visibles_dans_raw FROM sys.objects WHERE SCHEMA_NAME(schema_id) = 'raw';
REVERT;
GO

EXECUTE AS USER = 'olist_ingest';
    SELECT SUSER_SNAME() AS login_effectif, USER_NAME() AS user_effectif, DB_NAME() AS base_effective;
REVERT;
GO

PRINT '--- 6. after ---------------------------------------------------------';
SELECT name, is_disabled FROM sys.server_principals
WHERE name IN ('olist_ingest_login', 'olist_dbt_login');
GO
