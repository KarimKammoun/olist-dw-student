-- REFERENCE MODEL (TP 4)
-- raw.orders comes from a JSONL file: one row per order, the whole order kept as a
-- JSON document in the column "record". Staging does three things:
--   1. flatten  : OPENJSON turns each JSON field into a column
--   2. clean    : trim text, empty strings become NULL
--   3. type     : text -> DATETIME2, etc.
with source as (

    select record
    from {{ source('olist', 'orders') }}

),

flattened as (

    select j.*
    from source
    cross apply openjson(source.record) with (
        order_id                        nvarchar(50)  '$.order_id',
        customer_id                     nvarchar(50)  '$.customer_id',
        order_status                    nvarchar(50)  '$.order_status',
        order_purchase_timestamp        nvarchar(50)  '$.order_purchase_timestamp',
        order_approved_at               nvarchar(50)  '$.order_approved_at',
        order_delivered_carrier_date    nvarchar(50)  '$.order_delivered_carrier_date',
        order_delivered_customer_date   nvarchar(50)  '$.order_delivered_customer_date',
        order_estimated_delivery_date   nvarchar(50)  '$.order_estimated_delivery_date'
    ) as j

)

select
    {{ clean_text('order_id') }}                    as order_id,
    {{ clean_text('customer_id') }}                 as customer_id,
    lower({{ clean_text('order_status') }})         as order_status,
    {{ to_ts('order_purchase_timestamp') }}         as purchased_at,
    {{ to_ts('order_approved_at') }}                as approved_at,
    {{ to_ts('order_delivered_carrier_date') }}     as delivered_carrier_at,
    {{ to_ts('order_delivered_customer_date') }}    as delivered_customer_at,
    {{ to_ts('order_estimated_delivery_date') }}    as estimated_delivery_at
from flattened
