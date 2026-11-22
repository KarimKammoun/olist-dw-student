-- stg_order_items  (source: raw.order_items, from Parquet)
-- Parquet arrives already "column per field", so there is no OPENJSON here:
-- only clean (trim, '' -> NULL) and type (text -> INT / DECIMAL / DATETIME2).
with source as (

    select
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date,
        price,
        freight_value
    from {{ source('olist', 'order_items') }}

),

typed as (

    select
        {{ clean_text('order_id') }}        as order_id,
        {{ to_int('order_item_id') }}       as order_item_id,
        {{ clean_text('product_id') }}      as product_id,
        {{ clean_text('seller_id') }}       as seller_id,
        {{ to_ts('shipping_limit_date') }}  as shipping_limit_at,
        {{ to_money('price') }}             as price,
        {{ to_money('freight_value') }}     as freight_value
    from source

)

select
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_at,
    price,
    freight_value,
    cast(coalesce(price, 0) + coalesce(freight_value, 0) as decimal(12, 2)) as total_value
from typed
where order_id is not null
  and order_item_id is not null
