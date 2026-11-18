"""
load_raw_orders  (REFERENCE DAG - read it carefully, then write the 8 others)
================================================================================
Copies the orders file (JSONL) into raw.orders, AS IT IS.

    find -> create_table -> truncate_table -> load_to_raw -> check_rows

* find            : finds the file in include/data/olist and returns its path
* create_table    : runs include/sql/raw/orders.sql (CREATE TABLE ... only if it
                    does not exist yet) with SQLExecuteQueryOperator
* truncate_table  : empties raw.orders, so a rerun never duplicates rows
* load_to_raw     : reads the file with the reader that matches its FORMAT and
                    inserts the rows; returns the number of rows
* check_rows      : counts the rows now in raw.orders and fails if the numbers differ;
                    on success it updates the Asset "raw.orders" (outlets), which the
                    dbt DAG dbt_olist waits for

create_table and truncate_table are OPERATORS (ready-made tasks that run SQL).
load_to_raw and check_rows are Python tasks; they reach SQL Server through
MsSqlHook (see include/olist_raw/loader.py). All of them use the connection mssql_raw.
"""
from datetime import datetime

from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

try:  # Airflow 3
    from airflow.sdk import dag, task
except ImportError:  # Airflow 2
    from airflow.decorators import dag, task

from include.olist_raw.loader import CONN_ID, SQL_DIR, count_rows, raw_asset, find_file, read_json_records, write_raw

TABLE = "orders"                          # raw table: raw.orders
FILE_PATTERN = "*olist_orders_dataset.*"  # the file may have a prefix (e.g. 1793..._olist_orders...)


@dag(
    dag_id="load_raw_orders",
    start_date=datetime(2025, 1, 1),
    schedule=None,          # no automatic run: trigger it from the Airflow UI
    catchup=False,
    template_searchpath=[str(SQL_DIR)],   # where the .sql files are searched (the include folder)
    tags=["olist", "raw", "jsonl"],
)
def load_raw_orders():

    @task
    def find() -> str:
        return find_file(FILE_PATTERN)

    create_table = SQLExecuteQueryOperator(
        task_id="create_table",
        conn_id=CONN_ID,
        sql="sql/raw/orders.sql",   # a path ending in .sql = the operator reads the file
    )

    truncate_table = SQLExecuteQueryOperator(
        task_id="truncate_table",
        conn_id=CONN_ID,
        sql="TRUNCATE TABLE raw.orders;",
    )

    @task
    def load_to_raw(path: str) -> int:
        df = read_json_records(path)        # JSONL -> one row per order, column "record"
        return write_raw(df, TABLE, path)

    @task(outlets=[raw_asset(TABLE)])   # when this task succeeds, Airflow records that raw.orders
    def check_rows(rows_written: int) -> None:   # was refreshed; dbt_olist starts after all 9 tables
        rows_in_db = count_rows(TABLE)
        print(f"written: {rows_written:,} | in raw.{TABLE}: {rows_in_db:,}")
        if rows_in_db != rows_written:
            raise ValueError("Row counts differ")

    # dependencies: find -> create_table -> truncate_table -> load_to_raw -> check_rows
    path = find()
    rows = load_to_raw(path)
    path >> create_table >> truncate_table >> rows
    check_rows(rows)


load_raw_orders()
