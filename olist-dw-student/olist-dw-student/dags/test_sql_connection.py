"""
test_sql_connection
===================
Run this DAG first. Each task tests one step of the connection
Airflow (Docker) -> SQL Server Express (Windows). The first red task shows
the problem; open its log to read how to fix it.

    connection -> odbc_driver -> dns -> tcp_port -> login -> hook -> permissions
"""
from datetime import datetime

try:  # Airflow 3
    from airflow.sdk import dag, task
except ImportError:  # Airflow 2
    from airflow.decorators import dag, task

from include.olist_raw import diagnose as d


@dag(dag_id="test_sql_connection", start_date=datetime(2025, 1, 1), schedule=None,
     catchup=False, tags=["olist", "setup"], default_args={"retries": 0})
def test_sql_connection():

    @task
    def connection():
        d.check_airflow_connection()

    @task
    def odbc_driver():
        d.check_odbc_driver()

    @task
    def dns():
        d.check_dns(d.get_connection())

    @task
    def tcp_port():
        d.check_tcp(d.get_connection())

    @task
    def login():
        d.check_login(d.get_connection()).close()

    @task
    def hook():
        d.check_hook()

    @task
    def permissions():
        d.check_permissions(d.check_login(d.get_connection()))

    connection() >> odbc_driver() >> dns() >> tcp_port() >> login() >> hook() >> permissions()


test_sql_connection()
