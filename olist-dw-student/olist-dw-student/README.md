# Olist DW - student starter

Project layout, what is provided, what was completed, and how to run everything.

```
olist-dw-student/                     <- the Astro project (Dockerfile, dags/, include/)
  include/data/olist/                 <- the nine source files (112 MB, git-ignored normally)
  include/sql/raw/*.sql               <- CREATE TABLE for the nine raw tables
  include/sql/0*.sql                  <- scripts you run by hand in SSMS
  include/olist_raw/loader.py         <- helpers used by the DAGs (do not modify)
  dags/load_raw_*.py                  <- one DAG per raw table (9)
  dags/dbt_olist.py                   <- Cosmos DAG that runs the dbt project
  dags/dbt/olist/                     <- the dbt project (staging -> intermediate -> marts)
  cube/                               <- SSAS cube (TP8): MDX calculations and queries
  tests/dags/                         <- astro dev pytest
```

---

## 1. Setup (once)

1. `cp .env.example .env` (it enables the **Test** button and raises the DAG import
   timeout). Keep `AIRFLOW_CONN_MSSQL_RAW` commented.
2. `astro dev start` -> open the URL printed by the command (not always 8080).
3. **Admin > Connections > Add Connection**:

   | Field | `mssql_raw` | `mssql_dbt` |
   |---|---|---|
   | Connection Id | `mssql_raw` | `mssql_dbt` |
   | Connection Type | Microsoft SQL Server | Microsoft SQL Server |
   | Host | `host.docker.internal` | `host.docker.internal` |
   | Schema | `OlistDW` | `OlistDW` |
   | Login | `olist_ingest_login` | `olist_dbt_login` |
   | Password | (given by the teacher) | (given by the teacher) |
   | Port | `1433` | `1433` |
   | Extra | **empty** | **empty** |

   **Test** (green) then **Save**. `astro dev kill` deletes the connections; `stop`/`start`
   keep them. An `Extra` field that is not empty breaks `create_table`
   (`connect() got an unexpected keyword argument`).
4. Trigger **`test_sql_connection`**: its seven tasks must be green.
5. The nine files must sit in `include/data/olist/` **of the Astro project**
   (`ls include/data/olist | wc -l` -> 9).

---

## 2. What is provided / what was written

| Layer | Provided | Written |
|---|---|---|
| raw tables (`include/sql/raw`) | `orders.sql` | the 8 others |
| loading DAGs (`dags/`) | `load_raw_orders.py`, `test_sql_connection.py`, `dbt_olist.py` | the 8 others |
| staging models | `stg_orders.sql`, `_sources.yml` | the 8 others + tests |
| intermediate | - | `int_order_reviews`, `int_order_payments`, `int_orders_enriched`, `int_sales_enriched` |
| dimensions (marts) | - | `dim_date`, `dim_customers`, `dim_products`, `dim_sellers`, `dim_payment_type`, `dim_order_status` |
| facts (marts) | - | `fact_sales`, `fact_payments`, `fact_orders` |
| SCD2 | - | `snapshots/snap_customers.sql` |
| cube | `cube/README.md` | `cube/README.md` (rewritten step by step), `cube/mdx/calculated_members.mdx`, `cube/mdx/business_questions.mdx`, `include/sql/05_ssas_service_access.sql` |
| validation | - | `include/sql/06_validate_warehouse_totals.sql` |
| tests / infra | - | `tests/dags/test_dag_integrity.py` (all 9 tables), `.dockerignore`, `.env.example`, `dbt-sqlserver[pyodbc]` in the Dockerfile |

### The loading pattern (identical for the nine tables)

```
find -> create_table -> truncate_table -> load_to_raw -> check_rows
```

* `find` finds the file in `include/data/olist` (the pattern tolerates a file-name prefix);
* `create_table` runs `include/sql/raw/<table>.sql` with `SQLExecuteQueryOperator`;
* `truncate_table` empties the table, so a rerun never duplicates rows;
* `load_to_raw` reads the file with the reader that matches its format and inserts through
  `MsSqlHook` (batches of 1,000);
* `check_rows` compares written vs stored rows and publishes the Asset
  `olistdw://raw/<table>`; `dbt_olist` starts when the nine Assets are fresh.

| Source file | Format | Reader | Raw table shape | Rows |
|---|---|---|---|---|
| `olist_orders_dataset` | JSONL | `read_json_records` | `record` (JSON document) | 99,441 |
| `olist_order_items_dataset` | Parquet | `read_parquet_as_is` | one column per field | 112,650 |
| `olist_order_payments_dataset` | JSON | `read_json_records` | `record` (JSON document) | 103,886 |
| `olist_order_reviews_dataset` | JSON | `read_json_records` | `record` (JSON document) | 99,224 |
| `olist_customers_dataset` | Parquet | `read_parquet_as_is` | one column per field | 99,441 |
| `olist_products_dataset` | CSV | `read_csv_as_is` | one column per field | 32,951 |
| `olist_sellers_dataset` | CSV | `read_csv_as_is` | one column per field | 3,095 |
| `olist_geolocation_dataset` | Parquet | `read_parquet_as_is` | one column per field | 1,000,163 |
| `product_category_name_translation` | CSV (BOM) | `read_csv_as_is` | one column per field | 71 |

---

## 3. Order of work

1. **TP2 - raw layer**: trigger the nine `load_raw_*` DAGs. Check with
   `include/sql/02_raw_counts_and_audit.sql`.
2. **TP3a - staging**: `dbt build --select tag:staging`, or trigger `dbt_olist`.
3. **TP3b - marts**: dimensions then facts (dbt resolves the order through `ref`).
4. **Validation**: run `include/sql/06_validate_warehouse_totals.sql` in SSMS:

   | KPI | Expected |
   |---|---|
   | Sales Amount | 13,591,643.70 |
   | Freight Amount | 2,251,909.54 |
   | Payment Value | 16,008,872.12 |
   | Item Count | 112,650 |
   | Sales 2016 / 2017 / 2018 | 49,785.92 / 6,155,806.98 / 7,386,050.80 |
   | Late Rate (delivered orders) | 6.77% (6,534 of 96,478) |

5. **TP7 - SCD2**: `dbt snapshot` is **not** run by Cosmos, it is run by hand.
   The dbt packages must be installed first, and they must **not** land inside the project
   that Cosmos hashes (a `dbt_packages/` folder there brings back the
   `DagBag import timeout`), so the snapshot runs in a throw-away copy:

   ```powershell
   cd C:\dev\olist-dw-student\olist-dw-student\olist-dw-student
   astro dev bash
   ```
   ```bash
   # inside the container (DBT_USER / DBT_PASSWORD come from .env)
   rm -rf /tmp/dbtsnap && cp -r /usr/local/airflow/dags/dbt/olist /tmp/dbtsnap
   cd /tmp/dbtsnap
   /usr/local/airflow/dbt_venv/bin/dbt deps     --profiles-dir .
   /usr/local/airflow/dbt_venv/bin/dbt snapshot --profiles-dir . --target docker --select snap_customers
   cd / && rm -rf /tmp/dbtsnap
   exit
   ```

   Expected: `OK snapshotted staging.snap_customers` then `Done. PASS=1 ERROR=0`,
   and `SELECT COUNT(*) FROM staging.snap_customers` = 99,441 rows.
   To prove the SCD2 behaviour run, in this order:
   1. `include/sql/04_scd2_demo.sql`, **block A only** (as admin): it prints the row,
      updates the city of the first customer (the value toggles `sousse` / `recife`,
      so the script can be replayed), and prints `rows_updated = 1`;
   2. the `dbt snapshot` block above;
   3. `include/sql/04_scd2_demo.sql`, **block B**: the customer now has **two** rows,
      one closed (`dbt_valid_to` filled) and one open (`dbt_valid_to` NULL).
6. **TP8 - cube**: `cube/README.md` (install SSAS from the Developer media, service account
   grants in `include/sql/05_ssas_service_access.sql`), then paste
   `cube/mdx/calculated_members.mdx` in the Calculations tab and run
   `cube/mdx/business_questions.mdx`.

### dbt on Windows (development)

Keep the virtualenv **outside** the dbt project - a `.venv` inside `dags/dbt/olist` is
hashed by Cosmos on every DAG parse and causes `DagBag import timeout`:

```powershell
cd C:\dev
python -m venv dbt-venv
C:\dev\dbt-venv\Scripts\Activate.ps1
pip install "dbt-sqlserver[pyodbc]>=1.10,<2.0"

cd C:\dev\olist-dw-student\olist-dw-student\dags\dbt\olist
$env:DBT_USER="olist_dbt_login"; $env:DBT_PASSWORD="<password>"; $env:MSSQL_SERVER="localhost"
dbt deps  --profiles-dir .
dbt debug --profiles-dir .
dbt build --profiles-dir .
```

---

## 4. Design decisions worth knowing

* **raw keeps everything as text** (`NVARCHAR`): no conversion, no cleaning. That is why
  `price` arrives as `'58.9'` and a zip code `01037` arrives as `'1037'` (the Parquet file
  had it as an integer). Staging repairs it with `zip5()`.
* **JSON sources are not flattened in raw**: one column `record` holds the whole document;
  `OPENJSON` in staging turns it into columns.
* **`is_late` compares dates, not timestamps.** On the timestamp there are 7,826 late orders
  (8.11%); on the day there are 6,534 (6.77%), which is the reference value.
* **`stg_geolocation` is materialized as a table** (the only staging model that is not a
  view): reducing 1,000,163 rows to 19,015 zip prefixes with a `GROUP BY` would otherwise be
  re-executed by every model that joins it.
* **`dim_date` is built from a tally table**, not from `sys.all_objects`: a low-privilege
  login (`olist_dbt`) only sees its own objects there, which could truncate the calendar.
  Day-of-week and weekend are computed from the distance to 1900-01-01 (a Monday), so they
  do not depend on `DATEFIRST`.
* **`fact_orders` has four date keys**, because the cube relates it to `dim_date` four times.
* **`dim_date` also exposes `quarter_key` (YYYYQ) and `month_key` (YYYYMM)**: the raw `quarter`
  and `month` numbers repeat every year, so they cannot key a Date hierarchy in SSAS
  (all four Januaries would collapse into one member).
* **Unknown members**: `date_key = -1` and `'unknown'` categories keep measures that would
  otherwise be lost by an inner join.
* **Two logins, two purposes**: `olist_ingest` writes `raw` only; `olist_dbt` reads `raw`
  and writes `staging` + `marts`. Least privilege.

---

## 5. Every-day commands

| Command | Effect |
|---|---|
| `astro dev start` | start Airflow (read the printed URL) |
| `astro dev stop` / `start` | keep containers and connections |
| `astro dev restart` | rebuild after a change in `Dockerfile`, `requirements.txt` or `.env` |
| `astro dev logs -f` | follow the scheduler logs |
| `astro dev bash` | shell inside the container (no `-c` option) |
| `astro dev pytest` | import all DAGs and run `tests/` |
| `astro dev run config get-value core dagbag_import_timeout` | check a setting |
| `astro dev kill` | **deletes** containers, the metadata DB and the connections |

`dags/` and `include/` are mounted: a change in a DAG, a `.sql` file or a dbt model is
picked up in about 30 seconds. No restart needed.

---

## 6. Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `DagBag import timeout for .../dbt_olist.py` | Cosmos hashes every file of the dbt project: a `.venv`, `target/`, `logs/` or `dbt_packages/` inside it, or a project in OneDrive | clean those folders, keep the project **outside** OneDrive, `.dockerignore`, raise `AIRFLOW__CORE__DAGBAG_IMPORT_TIMEOUT` |
| `The legacy pyodbc backend was requested, but ... not installed` | dbt-sqlserver >= 1.12 does not install `pyodbc` by default | `dbt-sqlserver[pyodbc]` in the Dockerfile, then `astro dev restart` |
| `connect() got an unexpected keyword argument 'driver'` | something written in the `Extra` of `mssql_raw` | empty the `Extra` field, save, clear the task |
| `Login failed for user` (18456) / `Cannot open database` (4060) | Windows-only auth, wrong password, missing user, wrong Schema | see the setup guide, parts B1/B3; Schema = `OlistDW` |
| `These columns of the file are missing in raw.<table>` | the `.sql` does not match the file | fix the `.sql`, then `DROP TABLE raw.<table>` (`IF NOT EXISTS` never alters an existing table) |
| `Invalid object name 'staging.snap_customers'` | `dbt snapshot` was never run | run it (TP7, step 5) |
| `dbt expects 1 package(s) ... but found only 0` | `dbt_packages/` is not installed | `dbt deps --profiles-dir .` (inside the copy, see TP7) |
| `Deprecation: MissingArgumentsPropertyInGenericTestDeprecation` | dbt 1.12 prefers `arguments:` in generic tests | warning only, tests still pass |
| `Login failed for user 'olist_dbt_login'` (18456) after `ALTER LOGIN` | the password in `.env` and in the `mssql_dbt` connection was not updated | update both, `astro dev restart`, `SELECT LOGINPROPERTY('olist_dbt_login','IsLocked')` |
| `Invalid column name 'is_expired'` | `sys.sql_logins` has no such column | use `LOGINPROPERTY(name, 'IsExpired')` |
| SSAS: `Login failed for user 'NT SERVICE\MSSQLSERVEROLAPService'` | the service account has no SQL login | `include/sql/05_ssas_service_access.sql` |
| SSAS: `The 'Date' dimension ... is used in multiple relationships` / ambiguous | `fact_orders` has 4 date keys | create 4 roles in the Dimension Usage tab (`cube/README.md` §6) |
| Red `tcp_port` task while Windows tests pass | firewall or `Host = localhost` | `Host = host.docker.internal` |
| Port already in use | another service | `astro config set postgres.port 5433` / `api-server.port 8090` |
