-- stg_customers  (source: raw.customers, from Parquet)
-- customer_zip_code_prefix lost its leading zero in the Parquet file (int64):
-- zip5() pads it back to 5 characters ('1037' -> '01037').
with source as (

    select
        customer_id,
        customer_unique_id,
        customer_zip_code_prefix,
        customer_city,
        customer_state
    from {{ source('olist', 'customers') }}

)

select
    {{ clean_text('customer_id') }}                     as customer_id,
    {{ clean_text('customer_unique_id') }}              as customer_unique_id,
    {{ zip5('customer_zip_code_prefix') }}              as zip_code_prefix,
    lower({{ clean_text('customer_city') }})            as city,
    upper({{ clean_text('customer_state') }})           as state
from source
where {{ clean_text('customer_id') }} is not null
