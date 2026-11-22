-- snap_customers  (TP7 - SCD2, schema staging)
-- A snapshot keeps the HISTORY of a table: when an attribute changes, dbt closes the old
-- row (dbt_valid_to) and opens a new one (dbt_valid_from) instead of overwriting it.
--
-- Why `check` and not `timestamp`?
--   raw.customers has no "updated_at" column, so we cannot know *when* a change happened:
--   we only know *that* it happened, at the moment dbt snapshot runs. `check` compares the
--   listed columns; `timestamp` needs a column with the modification date.
--
-- Demo (include/sql/04_scd2_demo.sql):
--   UPDATE raw.customers SET customer_city = 'sousse', customer_state = 'TN' WHERE ...
--   dbt snapshot --select snap_customers
--   SELECT * FROM staging.snap_customers WHERE customer_id = ... ORDER BY dbt_valid_from;
{% snapshot snap_customers %}

{{
    config(
        target_schema='staging',
        unique_key='customer_id',
        strategy='check',
        check_cols=['customer_city', 'customer_state', 'customer_zip_code_prefix'],
        tags=['scd2'],
    )
}}

select
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state
from {{ source('olist', 'customers') }}
where customer_id is not null

{% endsnapshot %}
