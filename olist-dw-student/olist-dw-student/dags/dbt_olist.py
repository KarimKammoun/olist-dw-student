"""
dbt_olist  -  runs the dbt project with Astronomer Cosmos
==========================================================
Cosmos reads the dbt project and turns every dbt node into Airflow tasks:

    model stg_orders  ->  task group stg_orders: run (dbt run) -> test (dbt test)

The dependencies come from ref() and source(): the Graph view of this DAG is the
dbt lineage (staging -> intermediate -> dimensions -> facts).

When does it run?
    It is scheduled on the 9 Assets "raw.<table>". Each load_raw_* DAG updates its
    Asset when it succeeds; as soon as all 9 have been refreshed, dbt_olist starts.
    You can also trigger it by hand.

Credentials: the Airflow connection mssql_dbt (create it in the UI, like mssql_raw,
with the login olist_dbt_login). Cosmos builds the dbt profile from it.
"""
import os
from datetime import datetime
from pathlib import Path

from cosmos import DbtDag, ExecutionConfig, ProfileConfig, ProjectConfig, RenderConfig
from cosmos.constants import TestBehavior
from cosmos.profiles.sqlserver.standard_sqlserver_auth import StandardSQLServerAuth

from include.olist_raw.loader import raw_asset

TABLES = ["orders", "order_items", "payments", "reviews", "customers",
          "products", "sellers", "geolocation", "category_translation"]

DBT_PROJECT = Path(__file__).resolve().parent / "dbt" / "olist"
DBT_EXECUTABLE = Path(os.environ.get("AIRFLOW_HOME", "/usr/local/airflow")) / "dbt_venv" / "bin" / "dbt"

profile_config = ProfileConfig(
    profile_name="olist",
    target_name="airflow",
    profile_mapping=StandardSQLServerAuth(
        conn_id="mssql_dbt",                 # host, port, login, password come from this connection
        profile_args={                       # the rest of the dbt profile
            "database": "OlistDW",
            "schema": "staging",             # default schema; models set staging / marts themselves
            "driver": "ODBC Driver 18 for SQL Server",
            "encrypt": True,
            "trust_cert": True,
        },
    ),
)

dbt_olist = DbtDag(
    dag_id="dbt_olist",
    schedule=[raw_asset(t) for t in TABLES],   # starts when the 9 raw tables have been refreshed
    start_date=datetime(2025, 1, 1),
    catchup=False,
    tags=["olist", "dbt"],
    default_args={"retries": 0},
    project_config=ProjectConfig(DBT_PROJECT),
    profile_config=profile_config,
    execution_config=ExecutionConfig(dbt_executable_path=str(DBT_EXECUTABLE)),
    render_config=RenderConfig(test_behavior=TestBehavior.AFTER_EACH),   # test each model right after it runs
    operator_args={"install_deps": True},     # runs dbt deps (dbt_utils) before each command
    doc_md=__doc__,
)
