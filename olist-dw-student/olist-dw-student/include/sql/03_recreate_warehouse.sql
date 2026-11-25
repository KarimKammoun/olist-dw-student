/* ============================================================================
   DISASTER RECOVERY - recreate the whole OlistDW database from scratch
   ============================================================================
   Use this when the database was dropped by mistake (DROP DATABASE OlistDW).

   What is lost / what is NOT lost:
     LOST     : the 9 raw tables, the staging/marts objects built by dbt, and the
                SCD2 snapshot table staging.snap_customers.
     NOT LOST : the 9 source files (include/data/olist), the DAGs, the dbt models,
                the Airflow connections (they live in Airflow, not in SQL Server).
     => everything is rebuilt by the pipeline; no file has to be restored.

   Run in SSMS, connected to the DATABASE ENGINE as ADMIN (sysadmin):
     Express 2025 : localhost\\SQLEXPRESS01
     Express 2022 : localhost\\SQLEXPRESS
   Then follow the 4 steps listed at the bottom of this file.

   The script is IDEMPOTENT: it can be run twice without error.
   ============================================================================ */

/* ---------------------------------------------------------------- 0. report */
PRINT '--- 0. what exists right now -------------------------------------------';
SELECT DB_ID('OlistDW') AS olistdw_db_id;   -- NULL = the database does not exist
GO

SELECT name, state_desc, user_access_desc FROM sys.databases WHERE name = 'OlistDW';
-- state_desc must be ONLINE. RECOVERY_PENDING / SUSPECT / RECOVERY means the files
-- are unreadable: the database must be dropped, not repaired (see 0b).
SELECT name, type_desc, physical_name, size * 8 / 1024 AS size_mb
FROM sys.master_files WHERE database_id = DB_ID('OlistDW');
GO

/* ------------------------------------------------------------------ 0b. broken db
   Symptom: Msg 945 "Database 'OlistDW' cannot be opened due to inaccessible files"
   and the database shows as (Recovery Pending) in SSMS. Cause: the .mdf / .ldf are
   unreadable (deleted or moved by hand, disk full, service account without rights).
   Nothing in the warehouse is worth a REPAIR_ALLOW_DATA_LOSS: it is fully rebuilt
   from the nine source files, so the fastest and safest fix is DROP + recreate.
   Run this block ONLY if the state_desc above is not ONLINE.

   If DROP fails with the same Msg 945, use the two variants below it, then delete the
   leftover files (path shown by the last query above) and run the script again.
   ---------------------------------------------------------------------------- */
-- USE master;
-- GO
-- ALTER DATABASE OlistDW SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
-- GO
-- DROP DATABASE OlistDW;
-- GO
-- variant 1: ALTER DATABASE OlistDW SET OFFLINE WITH ROLLBACK IMMEDIATE; then DROP DATABASE OlistDW;
-- variant 2: EXEC sp_detach_db N'OlistDW';   -- then delete the files and CREATE DATABASE

/* The failed run of this script left users in master (USE OlistDW failed, so the
   following statements ran in master). Clean them up if they are there: */
-- USE master;
-- GO
-- IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'olist_ingest') DROP USER olist_ingest;
-- IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'olist_dbt')    DROP USER olist_dbt;
-- GO

-- When the DROP is done, go back to section 1 below and run the script from the top.

/* --------------------------------------------------------- 1. database + schemas */
USE master;
GO
IF DB_ID('OlistDW') IS NULL
BEGIN
    PRINT 'Creating database OlistDW...';
    CREATE DATABASE OlistDW;
END
ELSE
    PRINT 'Database OlistDW already exists, nothing to create.';
GO

USE OlistDW;
GO
IF SCHEMA_ID('raw')     IS NULL EXEC('CREATE SCHEMA raw     AUTHORIZATION dbo');
IF SCHEMA_ID('staging') IS NULL EXEC('CREATE SCHEMA staging AUTHORIZATION dbo');
IF SCHEMA_ID('marts')   IS NULL EXEC('CREATE SCHEMA marts   AUTHORIZATION dbo');
GO

/* ------------------------------------------------------------- 2. database users
   The LOGINS (server level) normally still exist: dropping a database does not
   drop its logins, it only drops the USERS inside the database.
   If a login was deleted too, uncomment section 2b and put the passwords back.
   ---------------------------------------------------------------------------- */
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'olist_ingest')
    CREATE USER olist_ingest FOR LOGIN olist_ingest_login;
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'olist_dbt')
    CREATE USER olist_dbt FOR LOGIN olist_dbt_login;
GO

/* ---- 2b. ONLY if the server logins were deleted as well -------------------
USE master;
GO
-- CREATE LOGIN olist_ingest_login WITH PASSWORD = 'OlistIngest2026!', CHECK_POLICY = OFF;
-- CREATE LOGIN olist_dbt_login    WITH PASSWORD = 'OlistDbt2026!',    CHECK_POLICY = OFF;
GO
--------------------------------------------------------------------------- */

/* ---------------------------------------------------------------- 3. rights
   olist_ingest : writes raw (the 9 load_raw_* DAGs)
   olist_dbt    : reads raw, writes staging + marts (dbt / Cosmos)
   The three last GRANTs are the ones the adapter needs on SQL Server:
     CREATE TABLE / CREATE VIEW  database level  -> dbt creates its objects
     ALTER on schema             -> dbt replaces an existing object
     SELECT on sys.sql_expression_dependencies + VIEW DEFINITION
                                 -> dbt lists the views to drop before recreating
                                    them (without these, every second run fails with
                                    "The SELECT permission was denied on the object
                                     'sql_expression_dependencies'")
   ---------------------------------------------------------------------------- */
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

/* ------------------------------------------------------------------ 4. control */
PRINT '--- 4. report: everything the pipeline needs --------------------------';
SELECT DB_NAME() AS database_name, SCHEMA_NAME() AS current_schema;

SELECT name AS schema_name FROM sys.schemas WHERE name IN ('raw', 'staging', 'marts') ORDER BY name;

SELECT dp.name AS principal, dp.type_desc,
       ISNULL((SELECT STRING_AGG(p.permission_name, ', ')
               FROM sys.database_permissions p
               WHERE p.grantee_principal_id = dp.principal_id), '(aucun droit)') AS permissions
FROM sys.database_principals dp
WHERE dp.name IN ('olist_ingest', 'olist_dbt')
ORDER BY dp.name;
GO

/* ============================================================================
   NOW THE 4 STEPS (outside SSMS)
   ----------------------------------------------------------------------------
   STEP 1 - load the 9 raw tables               ~10-20 min (geolocation = 1M rows)
     Airflow UI (http://localhost:8080) -> Dags
     Select the 9 DAGs load_raw_* -> Actions -> Trigger (or play button on each).
     Wait for all 9 to be green. The test task at the end prints the row count:
       orders 99,441 | order_items 112,650 | payments 103,886 | reviews 99,224
       customers 99,441 | products 32,951 | sellers 3,095 | geolocation 1,000,163
       category_translation 71

   STEP 2 - rebuild staging + marts with dbt     ~3-5 min
     dbt_olist starts by itself as soon as the 9 raw assets are refreshed
     (it waits for the 9 of them). If it does not, trigger it by hand.
     Expected: 22 models + 69 tests green.

   STEP 3 - rebuild the SCD2 snapshot            ~40 s   (TP7)
     Cosmos never runs snapshots: use the throw-away copy recipe (README, TP7)
       astro dev bash
       rm -rf /tmp/dbtsnap && cp -r /usr/local/airflow/dags/dbt/olist /tmp/dbtsnap
       cd /tmp/dbtsnap
       /usr/local/airflow/dbt_venv/bin/dbt deps     --profiles-dir .
       /usr/local/airflow/dbt_venv/bin/dbt snapshot --profiles-dir . --target docker --select snap_customers
       cd / && rm -rf /tmp/dbtsnap
       exit

   STEP 4 - check the numbers
     Run include/sql/06_validate_warehouse_totals.sql in SSMS:
       Sales Amount 13,591,643.70 | Payment Value 16,008,872.12
       Late Rate 6.77 | dim_date 1,462 rows | snap_customers 99,441 rows

   Nothing else is needed: the cube (TP8) reads marts and will see the rebuilt
   tables as soon as it is processed again.
   ============================================================================ */
