/* TP 8 - give the SSAS service account read access to the marts schema.
   Run in SSMS on the DATABASE ENGINE (localhost\SQLEXPRESS) as an administrator.

   Why: the cube reads the tables of schema `marts` with the credentials of the
   Analysis Services service (impersonation = "Use the service account"), and that
   account is not a SQL Server login by default.

   The service account name depends on the instance name:
     default instance  -> NT Service\MSSQLServerOLAPService
     named instance X  -> NT Service\MSSQLServerOLAPService$X
   Check yours (PowerShell, run as administrator):
     Get-CimInstance Win32_Service -Filter "Name like '%OLAP%'" | Select-Object Name, StartName
*/
USE master;
GO

-- 1. the login (skipped when it already exists, so the script can be re-run)
IF NOT EXISTS (SELECT 1 FROM sys.server_principals WHERE name = N'NT Service\MSSQLServerOLAPService')
    CREATE LOGIN [NT Service\MSSQLServerOLAPService] FROM WINDOWS;
GO

USE OlistDW;
GO

-- 2. the database user (the name must match your service account, see above)
IF NOT EXISTS (SELECT 1 FROM sys.database_principals WHERE name = N'NT Service\MSSQLServerOLAPService')
    CREATE USER [NT Service\MSSQLServerOLAPService] FOR LOGIN [NT Service\MSSQLServerOLAPService];
GO

-- 3. read-only access to the star schema (staging is NOT needed by the cube)
GRANT SELECT ON SCHEMA::marts TO [NT Service\MSSQLServerOLAPService];
GO

-- 4. check: the user exists and can read marts
SELECT dp.name AS principal, dp.type_desc,
       STRING_AGG(p.permission_name, ', ') AS permissions
FROM sys.database_principals dp
LEFT JOIN sys.database_permissions p ON p.grantee_principal_id = dp.principal_id
WHERE dp.name = N'NT Service\MSSQLServerOLAPService'
GROUP BY dp.name, dp.type_desc;
GO

/* ---------------------------------------------------------------------------------------
   FALLBACK - if you cannot use the service account (named instance, or the WINDOWS login
   refuses to be created), use the SQL login instead. Two things to do:

   a) here, in SSMS: nothing (olist_dbt already has SELECT on marts).
   b) in Visual Studio, Data Source -> Impersonation Information:
        "Use a specific user name and password"
        User name: olist_dbt_login
        Password : <the same password as in .env>
   --------------------------------------------------------------------------------------- */
