"""
Step-by-step test of the connection Airflow (Docker) -> SQL Server Express (Windows).
Each check prints OK or FAILED with the most likely fix.

From a terminal:   astro dev bash   then   python include/olist_raw/diagnose.py
From Airflow:      trigger the DAG test_sql_connection
"""
from __future__ import annotations

import socket
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2]))   # project root, for CLI use

from include.olist_raw.loader import CONN_ID, DRIVER, get_connection, odbc_string  # noqa: E402


class CheckFailed(Exception):
    pass


def fail(msg: str, fixes: list[str]):
    text = f"FAILED: {msg}\nHow to fix:\n" + "\n".join(f"  - {f}" for f in fixes)
    print(text)
    raise CheckFailed(text)


def check_airflow_connection():
    try:
        c = get_connection()
    except Exception as e:  # noqa: BLE001
        fail(f"connection '{CONN_ID}' not found ({e})", [
            "Create it in the Airflow UI: Admin > Connections > Add Connection (TP2, Step 7).",
            "Connection Id must be exactly mssql_raw, Connection Type: Microsoft SQL Server.",
            "After astro dev kill the connection is deleted: create it again.",
        ])
    print(f"OK  connection {CONN_ID}: host={c.host} port={c.port} database={c.schema} login={c.login}")
    if not c.password:
        fail("the connection has no password", ["Admin > Connections > mssql_raw > edit: fill in Password, then Save."])
    if c.host in ("localhost", "127.0.0.1"):
        fail("host is localhost: inside Docker this is the container itself", [
            "Admin > Connections > mssql_raw > edit: Host = host.docker.internal."])
    return c


def check_odbc_driver():
    try:
        import pyodbc
    except ImportError as e:
        fail(f"the Python package pyodbc cannot be loaded ({e})", [
            "requirements.txt must contain pyodbc, and the Dockerfile must install unixodbc + msodbcsql18.",
            "Then rebuild the image: astro dev restart"])
    drivers = pyodbc.drivers()
    if DRIVER not in drivers:
        fail(f"{DRIVER} is not installed in the image (found: {drivers})", [
            "Check the ODBC block of the Dockerfile, then run: astro dev restart"])
    print(f"OK  {DRIVER} installed")


def check_dns(c):
    try:
        ip = socket.gethostbyname(c.host)
    except OSError:
        fail(f"cannot resolve {c.host}", [
            "On Docker Desktop for Windows, host.docker.internal always exists: check the spelling.",
            "On Linux, keep extra_hosts in docker-compose.override.yml and restart."])
    print(f"OK  {c.host} -> {ip}")


def check_tcp(c):
    port = int(c.port or 1433)
    try:
        socket.create_connection((c.host, port), timeout=5).close()
    except OSError as e:
        fail(f"port {port} on {c.host} is not reachable ({e})", [
            "SQL Server Configuration Manager: TCP/IP Enabled for SQLEXPRESS.",
            "TCP/IP > IP Addresses > IPAll: TCP Dynamic Ports EMPTY, TCP Port 1433.",
            "Restart the service SQL Server (SQLEXPRESS).",
            "Windows Firewall: inbound rule for TCP 1433.",
            "On Windows: Test-NetConnection localhost -Port 1433 must say True."])
    print(f"OK  TCP port {port} reachable")


def check_login(c):
    import pyodbc
    try:
        cn = pyodbc.connect(odbc_string(c), timeout=10)
    except pyodbc.Error as e:
        msg = str(e)
        fixes = ["Read the error above."]
        if "18456" in msg:
            fixes = ["Login failed: check Login and Password of the connection mssql_raw (Admin > Connections).",
                     "SSMS > Server Properties > Security: SQL Server and Windows Authentication mode, then restart the service.",
                     "SSMS > Security > Logins > olist_ingest_login > Status: Login Enabled."]
        elif "4060" in msg:
            fixes = [f"Cannot open database {c.schema}: the Schema field of the connection must be OlistDW.",
                     "The login needs a user in OlistDW: CREATE USER olist_ingest FOR LOGIN olist_ingest_login;"]
        elif "certificate" in msg.lower() or "ssl" in msg.lower():
            fixes = ["TLS problem: the connection string must contain TrustServerCertificate=yes."]
        elif "timeout" in msg.lower():
            fixes = ["Login timeout: TCP works but SQL Server does not answer; restart the SQLEXPRESS service."]
        fail(f"login refused: {msg}", fixes)
    row = cn.cursor().execute("SELECT SUSER_NAME(), DB_NAME(), @@SERVERNAME, "
                              "CAST(SERVERPROPERTY('Edition') AS nvarchar(100)), "
                              "CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(50))").fetchone()
    print(f"OK  logged in as {row[0]} on database {row[1]} | server {row[2]} | {row[3]} {row[4]}")
    return cn


def check_hook():
    """Same login, but through MsSqlHook (pymssql): the path used by SQLExecuteQueryOperator."""
    try:
        from include.olist_raw.loader import mssql_hook
        row = mssql_hook().get_first("SELECT SUSER_NAME(), DB_NAME()")
    except Exception as e:  # noqa: BLE001
        fail(f"MsSqlHook cannot connect ({e})", [
            "The ODBC test passed, so the network is fine: check that Connection Type is Microsoft SQL Server.",
            "The provider apache-airflow-providers-microsoft-mssql must be in requirements.txt (astro dev restart).",
            "If the error mentions encryption: SQL Server Configuration Manager > Protocols > Force Encryption = No."])
    print(f"OK  MsSqlHook connected as {row[0]} on {row[1]}")


def check_permissions(cn):
    cur = cn.cursor()
    try:
        cur.execute("DROP TABLE IF EXISTS raw._connection_test; "
                    "CREATE TABLE raw._connection_test (id INT); "
                    "INSERT INTO raw._connection_test VALUES (1); "
                    "DROP TABLE raw._connection_test;")
        cn.commit()
    except Exception as e:  # noqa: BLE001
        fail(f"the login cannot create tables in raw ({e})", [
            "Run in SSMS (as admin) on OlistDW:",
            "GRANT CREATE TABLE TO olist_ingest;",
            "GRANT SELECT, INSERT, UPDATE, DELETE, ALTER ON SCHEMA::raw TO olist_ingest;"])
    print("OK  can create, fill and drop a table in raw")


def run_all() -> bool:
    try:
        c = check_airflow_connection()
        check_odbc_driver()
        check_dns(c)
        check_tcp(c)
        cn = check_login(c)
        check_hook()
        check_permissions(cn)
    except CheckFailed:
        return False
    print("\nALL CHECKS PASSED: Airflow can load data into OlistDW.raw")
    return True


def load_ui_connection_for_cli() -> None:
    """In Airflow 3 a plain Python script cannot read connections created in the UI
    (only tasks can, through the API server). When run from a terminal, read mssql_raw
    from the Airflow database and expose it to this script as an environment variable."""
    import os
    if os.environ.get("AIRFLOW_CONN_MSSQL_RAW"):
        return
    try:
        from airflow.models.connection import Connection
        conn = Connection.get_connection_from_secrets(CONN_ID)
        os.environ["AIRFLOW_CONN_MSSQL_RAW"] = conn.as_json()
        print(f"(connection {CONN_ID} read from the Airflow database)")
    except Exception:  # noqa: BLE001  -> check_airflow_connection reports it
        pass


if __name__ == "__main__":
    load_ui_connection_for_cli()
    sys.exit(0 if run_all() else 1)
