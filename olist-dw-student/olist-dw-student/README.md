# Olist DW - student starter

## 1. Create and test the connection first
1. `cp .env.example .env` (it enables the Test button). Keep `AIRFLOW_CONN_MSSQL_RAW` commented.
2. `astro dev start`, open http://localhost:8080
3. **Admin > Connections > Add Connection**:
   - Connection Id `mssql_raw`, Connection Type `Microsoft SQL Server`
   - Host `host.docker.internal`, Schema `OlistDW`, Port `1433`
   - Login `olist_ingest_login`, Password: given by your teacher
   - Extra: leave EMPTY
   - **Test** (green), then **Save**.
4. Trigger the DAG **test_sql_connection**. All seven tasks must be green.
   A red task? Open its log: it says what to fix.
5. Same test from a terminal:
   ```
   astro dev bash
   python include/olist_raw/diagnose.py
   sqlcmd -S host.docker.internal,1433 -U olist_ingest_login -P '<password>' -d OlistDW -C -Q "SELECT SUSER_NAME(), DB_NAME()"
   exit
   ```
   After `astro dev kill` the connection is deleted: create it again.
6. For dbt (TP3): create a second connection `mssql_dbt`, same fields, Login `olist_dbt_login`.
   The DAG `dbt_olist` then runs your dbt models automatically after the 9 raw loads.

## 2. What is already here
- `dags/load_raw_orders.py` - the reference DAG:
  find -> create_table -> truncate_table -> load_to_raw -> check_rows
- `include/sql/raw/orders.sql` - CREATE TABLE raw.orders (only if it does not exist).
- `include/olist_raw/loader.py` - helper functions for your DAGs (MsSqlHook). Do not modify it.
- `dags/dbt/olist/` - the dbt project with the reference model `stg_orders` (TP3).

## 3. Your TODO list
- TP2: for order_items, payments, reviews, customers, products, sellers, geolocation,
  category_translation write `include/sql/raw/<table>.sql` and `dags/load_raw_<table>.py`.
- TP3: the other staging models, the dimensions and the facts in `dags/dbt/olist/models/`.
- TP4: the cube `Olist Sales` (see `cube/README.md`).
