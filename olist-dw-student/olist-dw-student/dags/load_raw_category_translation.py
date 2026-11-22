"""
load_raw_category_translation
=================================
Copies the category_translation file (CSV with a UTF-8 BOM) into raw.category_translation, AS IT IS.

    find -> create_table -> truncate_table -> load_to_raw -> check_rows

* find            : finds the file in include/data/olist and returns its path
* create_table    : runs include/sql/raw/category_translation.sql (CREATE TABLE ... only if it does not exist)
* truncate_table  : empties raw.category_translation, so a rerun never duplicates rows
* load_to_raw     : reads the file with read_csv_as_is and inserts the rows
* check_rows      : counts the rows now in raw.category_translation and fails if the numbers differ;
                    on success it updates the Asset "raw.category_translation", which dbt_olist waits for

Same structure as the reference DAG load_raw_orders: change TABLE, FILE_PATTERN and the reader.
"""
from datetime import datetime

from airflow.providers.common.sql.operators.sql import SQLExecuteQueryOperator

try:  # Airflow 3
    from airflow.sdk import dag, task
except ImportError:  # Airflow 2
    from airflow.decorators import dag, task

from include.olist_raw.loader import CONN_ID, SQL_DIR, count_rows, find_file, read_csv_as_is, raw_asset, write_raw

TABLE = "category_translation"
FILE_PATTERN = "*product_category_name_translation.*"   # the file may have a prefix (e.g. 1793..._product_category_name_translation)
EXPECTED_ROWS = 71      # reference count (documented in _sources.yml), printed by find


@dag(
    dag_id="load_raw_category_translation",
    start_date=datetime(2025, 1, 1),
    schedule=None,          # no automatic run: trigger it from the Airflow UI
    catchup=False,
    template_searchpath=[str(SQL_DIR)],   # where the .sql files are searched (the include folder)
    tags=["olist", "raw", "csv"],
)
def load_raw_category_translation():

    @task
    def find() -> str:
        path = find_file(FILE_PATTERN)
        print(f"raw.category_translation: reference row count = {EXPECTED_ROWS:,}")
        return path

    create_table = SQLExecuteQueryOperator(
        task_id="create_table",
        conn_id=CONN_ID,
        sql="sql/raw/category_translation.sql",   # a path ending in .sql = the operator reads the file
    )

    truncate_table = SQLExecuteQueryOperator(
        task_id="truncate_table",
        conn_id=CONN_ID,
        sql="TRUNCATE TABLE raw.category_translation;",
    )

    @task
    def load_to_raw(path: str) -> int:
        df = read_csv_as_is(path)
        return write_raw(df, TABLE, path)

    @task(outlets=[raw_asset(TABLE)])
    def check_rows(rows_written: int) -> None:
        rows_in_db = count_rows(TABLE)
        print(f"written: {rows_written:,} | in raw.{TABLE}: {rows_in_db:,}")
        if rows_in_db != rows_written:
            raise ValueError("Row counts differ")

    # dependencies: find -> create_table -> truncate_table -> load_to_raw -> check_rows
    path = find()
    rows = load_to_raw(path)
    path >> create_table >> truncate_table >> rows
    check_rows(rows)


load_raw_category_translation()
