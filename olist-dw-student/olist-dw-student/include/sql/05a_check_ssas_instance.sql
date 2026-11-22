/* ============================================================================
   TP 8 - step 0: everything to check about the SSAS instance, in one script.
   Run in SSMS connected to the DATABASE ENGINE (localhost\SQLEXPRESS), as admin.
   It does not change anything: it only reports.
   ============================================================================ */

PRINT '--- 1. is an SSAS instance installed on this machine? -------------------';
-- The registry lists one key per installed Analysis Services instance.
EXEC master.dbo.xp_instance_regread
     N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\OLAP';

PRINT '--- 2. is the SSAS service running? ------------------------------------';
-- sys.dm_server_services only lists the services of THIS instance (the Express
-- database engine), so the SSAS service is asked to Windows instead: xp_cmdshell is
-- usually disabled, hence the PowerShell block below the query.
SELECT servicename, status_desc, start_type_desc
FROM sys.dm_server_services;
GO

/*  This only lists the Express engine. For the SSAS service, use PowerShell
    (administrator), which is the authoritative check:
      Get-Service MSSQLServerOLAPService
      Get-CimInstance Win32_Service -Filter "Name like '%OLAP%'" | Select-Object Name, State, StartName
*/
