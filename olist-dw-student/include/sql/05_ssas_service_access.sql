/* TP 8 - give the SSAS service read access to marts (Student Lab Guide §11).
   Default SSAS instance service account: NT Service\MSSQLServerOLAPService
   Check yours in services.msc -> SQL Server Analysis Services -> Log On. */
USE master;
CREATE LOGIN [NT Service\MSSQLServerOLAPService] FROM WINDOWS;
GO
USE OlistDW;
CREATE USER [NT Service\MSSQLServerOLAPService] FOR LOGIN [NT Service\MSSQLServerOLAPService];
GRANT SELECT ON SCHEMA::marts TO [NT Service\MSSQLServerOLAPService];
