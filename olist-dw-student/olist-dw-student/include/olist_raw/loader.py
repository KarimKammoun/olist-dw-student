"""
Helpers for the load_raw_* DAGs
================================
You do not need to modify this file. Your DAGs call:

    find_file(pattern)          -> path of the file to load (as text)
    read_csv_as_is(path)        -> CSV:     one column per field, every value as text
    read_parquet_as_is(path)    -> Parquet: one column per field, every value as text
    read_json_records(path)     -> JSON or JSONL: one row per record, column "record"
                                   holding the whole record as a JSON document
    write_raw(df, table, path)  -> inserts the rows into raw.<table> with MsSqlHook (batches of
                                   1,000 rows), adds _source_file and _loaded_at, returns the row count
    count_rows(table)           -> number of rows currently in raw.<table>
    raw_asset(table)            -> the Airflow Asset "raw.<table>": declared as outlet by the
                                   loading DAG, it triggers the dbt DAG (dbt_olist)

The SQL statements (CREATE TABLE, TRUNCATE) are not here: the DAGs run them with
SQLExecuteQueryOperator, from the files in include/sql/raw/.

All database access goes through MsSqlHook, the Airflow hook for SQL Server (driver pymssql),
with the connection mssql_raw created in the Airflow UI (Connection Type Microsoft SQL Server,
Extra empty). The operators of the DAGs use the same hook and the same connection.
"""
from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from pathlib import Path

CONN_ID = "mssql_raw"
DRIVER = "ODBC Driver 18 for SQL Server"
AIRFLOW_HOME = Path(os.environ.get("AIRFLOW_HOME", "/usr/local/airflow"))
DATA_DIR = AIRFLOW_HOME / "include" / "data" / "olist"
# the include folder, found from this file: template_searchpath of the DAGs (sql="sql/raw/<table>.sql")
SQL_DIR = Path(__file__).resolve().parents[1]


def mssql_hook():
    """The Airflow hook for SQL Server, built from the connection mssql_raw."""
    from airflow.providers.microsoft.mssql.hooks.mssql import MsSqlHook

    return MsSqlHook(mssql_conn_id=CONN_ID)


def raw_asset(table: str):
    """Asset meaning 'raw.<table> has been refreshed'. dbt_olist is scheduled on the 9 of them."""
    try:
        from airflow.sdk import Asset
    except ImportError:  # Airflow 2
        from airflow.datasets import Dataset as Asset
    return Asset(f"olistdw://raw/{table}")


def find_file(pattern: str) -> str:
    """Return the path of the first file in include/data/olist matching the pattern."""
    matches = sorted(DATA_DIR.glob(pattern))
    if not matches:
        raise FileNotFoundError(f"No file matching {pattern} in {DATA_DIR}")
    print(f"Found {matches[0].name} ({matches[0].stat().st_size / 1e6:.1f} MB)")
    return str(matches[0])


def read_csv_as_is(path: str):
    """CSV: every value kept as text; an empty cell stays an empty string."""
    import pandas as pd

    return pd.read_csv(path, dtype=str, encoding="utf-8-sig", keep_default_na=False)


def read_parquet_as_is(path: str):
    """Parquet: real types (int, double, timestamp) written as text; missing values stay NULL."""
    import pandas as pd

    df = pd.read_parquet(path)
    return df.apply(lambda col: col.map(lambda v: None if pd.isna(v) else str(v)))


def read_json_records(path: str):
    """JSON (one array) or JSONL (one record per line): one row per record, kept as JSON."""
    import pandas as pd

    with open(path, encoding="utf-8") as f:
        if path.lower().endswith(".jsonl"):
            records = [json.loads(line) for line in f if line.strip()]
        else:
            records = json.load(f)
    return pd.DataFrame({"record": [json.dumps(r, ensure_ascii=False) for r in records]})


def write_raw(df, table: str, path: str, batch_size: int = 1000) -> int:
    """Insert the DataFrame into raw.<table> through MsSqlHook (pymssql).

    The rows are sent in batches: one INSERT ... VALUES (...), (...) per 1,000 rows
    (1,000 is the maximum SQL Server accepts in one VALUES list). Everything is committed
    once at the end: if a batch fails, nothing is kept and the task can simply be retried.
    The table must already exist (task create_table).
    """
    df = df.copy()
    df["_source_file"] = Path(path).name
    df["_loaded_at"] = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S")

    hook = mssql_hook()
    table_cols = {r[0].lower() for r in hook.get_records(
        "SELECT name FROM sys.columns WHERE object_id = OBJECT_ID(%s)", parameters=(f"raw.{table}",))}
    if not table_cols:
        raise RuntimeError(f"raw.{table} does not exist: the task create_table must run first.")
    missing = [c for c in df.columns if c.lower() not in table_cols]
    if missing:
        raise RuntimeError(
            f"These columns of the file are missing in raw.{table}: {missing}. "
            f"Fix include/sql/raw/{table}.sql, then DROP TABLE raw.{table} in SSMS "
            f"(CREATE TABLE IF NOT EXISTS does not change an existing table).")

    columns = ", ".join(f"[{c}]" for c in df.columns)
    one_row = "(" + ", ".join(["%s"] * len(df.columns)) + ")"          # %s = pymssql placeholder
    rows = list(df.astype(object).where(df.notna(), None).itertuples(index=False, name=None))

    conn = hook.get_conn()
    try:
        cursor = conn.cursor()
        for start in range(0, len(rows), batch_size):
            batch = rows[start:start + batch_size]
            sql = f"INSERT INTO raw.[{table}] ({columns}) VALUES " + ", ".join([one_row] * len(batch))
            cursor.execute(sql, tuple(value for row in batch for value in row))
            if (start // batch_size) % 100 == 0:
                print(f"raw.{table}: {start + len(batch):,} / {len(rows):,} rows sent")
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()

    print(f"raw.{table}: {len(rows):,} rows inserted")
    return len(rows)


def count_rows(table: str) -> int:
    """Number of rows currently in raw.<table>."""
    return mssql_hook().get_first(f"SELECT COUNT(*) FROM raw.[{table}]")[0]


# --- used by include/olist_raw/diagnose.py ---------------------------------------------
def get_connection():
    try:
        from airflow.sdk import BaseHook
    except ImportError:
        from airflow.hooks.base import BaseHook
    return BaseHook.get_connection(CONN_ID)


def odbc_string(conn) -> str:
    password = (conn.password or "").replace("}", "}}")
    return (
        f"DRIVER={{{DRIVER}}};"
        f"SERVER={conn.host},{conn.port or 1433};DATABASE={conn.schema};"
        f"UID={conn.login};PWD={{{password}}};"
        "Encrypt=yes;TrustServerCertificate=yes;Connection Timeout=10;"
    )
