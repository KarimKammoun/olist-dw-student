"""
load_raw_reviews  (same pattern as load_raw_orders)
====================================================
Copies the reviews file into raw.reviews, AS IT IS.

    find -> create_table -> truncate_table -> load_to_raw -> check_rows

source file: JSON (one array). One row = one customer review.

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

TABLE = "reviews"                 # raw table: raw.reviews
FILE_PATTERN = "*olist_order_reviews_dataset.*"  # the file may have a prefix (e.g. 1793..._reviews...)


@dag(
    dag_id="load_raw_reviews",
    start_date=datetime(2025, 1, 1),
    schedule=None,          # no automatic run: trigger it from the Airflow UI
    catchup=False,
    template_searchpath=[str(SQL_DIR)],   # where the .sql files are searched (the include folder)
    tags=['olist', 'raw', 'json'],
)
def load_raw_reviews():

    @task
    def find() -> str:
        return find_file(FILE_PATTERN)

    create_table = SQLExecuteQueryOperator(
        task_id="create_table",
        conn_id=CONN_ID,
        sql="sql/raw/reviews.sql",   # a path ending in .sql = the operator reads the file
    )

    truncate_table = SQLExecuteQueryOperator(
        task_id="truncate_table",
        conn_id=CONN_ID,
        sql="TRUNCATE TABLE raw.reviews;",
    )

    @task
    def load_to_raw(path: str) -> int:
        df = read_json_records(path)   # JSON -> rows, ready to insert as text
        return write_raw(df, TABLE, path)

    @task(outlets=[raw_asset(TABLE)])   # when this task succeeds, Airflow records that raw.reviews
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


load_raw_reviews()
