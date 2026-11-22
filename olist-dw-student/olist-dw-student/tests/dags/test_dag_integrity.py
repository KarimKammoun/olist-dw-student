"""
Run with: astro dev pytest
==========================
Checks the shape of every DAG of the project: no import error, the nine loading DAGs have
exactly the five reference tasks, and dbt_olist waits for the nine raw Assets.
"""
from airflow.models import DagBag

TABLES = ["orders", "order_items", "payments", "reviews", "customers",
          "products", "sellers", "geolocation", "category_translation"]

REFERENCE_TASKS = ["find", "create_table", "truncate_table", "load_to_raw", "check_rows"]


def _bag():
    return DagBag(dag_folder="dags", include_examples=False)


def test_no_import_errors():
    bag = _bag()
    assert not bag.import_errors, bag.import_errors


def test_nine_loading_dags():
    bag = _bag()
    for table in TABLES:
        dag = bag.get_dag(f"load_raw_{table}")
        assert dag is not None, f"missing DAG load_raw_{table}"
        assert [t.task_id for t in dag.topological_sort()] == REFERENCE_TASKS, (
            f"load_raw_{table}: unexpected task order")


def test_loading_dags_publish_their_asset():
    """check_rows must publish olistdw://raw/<table>: that is what wakes dbt_olist up."""
    bag = _bag()
    for table in TABLES:
        dag = bag.get_dag(f"load_raw_{table}")
        check_rows = dag.get_task("check_rows")
        uris = {getattr(outlet, "uri", str(outlet)) for outlet in check_rows.outlets}
        assert f"olistdw://raw/{table}" in uris, f"load_raw_{table} does not publish its Asset"


def test_dbt_dag_waits_for_the_nine_raw_assets():
    bag = _bag()
    dag = bag.get_dag("dbt_olist")
    assert dag is not None, "missing DAG dbt_olist"
    uris = {a.uri for a in dag.timetable.asset_condition.objects}
    assert uris == {f"olistdw://raw/{t}" for t in TABLES}
