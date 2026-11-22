-- stg_sellers  (source: raw.sellers, from CSV)
-- This CSV kept its leading zeros, zip5() is applied anyway so both sources look the same.
with source as (

    select
        seller_id,
        seller_zip_code_prefix,
        seller_city,
        seller_state
    from {{ source('olist', 'sellers') }}

)

select
    {{ clean_text('seller_id') }}                   as seller_id,
    {{ zip5('seller_zip_code_prefix') }}            as zip_code_prefix,
    lower({{ clean_text('seller_city') }})          as city,
    upper({{ clean_text('seller_state') }})         as state
from source
where {{ clean_text('seller_id') }} is not null
