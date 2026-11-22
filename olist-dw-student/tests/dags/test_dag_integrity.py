"""Run with: astro dev pytest"""
from airflow.models import DagBag

TABLES = ["orders", "order_items", "payments", "reviews", "customers",
          "products", "sellers", "geolocation", "category_translation"]


def test_no_import_errors():
    bag = DagBag(dag_folder="dags", include_examples=False)
    assert not bag.import_errors, bag.import_errors


def test_nine_loading_dags():
    bag = DagBag(dag_folder="dags", include_examples=False)
    for table in ["orders"]:   # TODO TP2: test all nine tables once your DAGs exist
        dag = bag.get_dag(f"load_raw_{table}")
        assert dag is not None, f"missing DAG load_raw_{table}"
        assert [t.task_id for t in dag.topological_sort()] == ["find", "create_table", "truncate_table", "load_to_raw", "check_rows"]


def test_dbt_dag_waits_for_the_nine_raw_assets():
    bag = DagBag(dag_folder="dags", include_examples=False)
    dag = bag.get_dag("dbt_olist")
    assert dag is not None, "missing DAG dbt_olist"
    uris = {a.uri for a in dag.timetable.asset_condition.objects}
    assert uris == {f"olistdw://raw/{t}" for t in TABLES}
