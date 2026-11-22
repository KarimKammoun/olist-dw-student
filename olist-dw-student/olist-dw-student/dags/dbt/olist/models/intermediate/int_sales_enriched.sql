-- int_sales_enriched  (intermediate, schema staging)
-- One row per order LINE (112,650 rows), carrying the order and customer attributes.
-- This is the exact grain of fact_sales: "one line of one order".
with items as (

    select * from {{ ref('stg_order_items') }}

),

orders as (

    select * from {{ ref('int_orders_enriched') }}

)

select
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.seller_id,
    i.price,
    i.freight_value,
    i.total_value,
    i.shipping_limit_at,

    o.customer_id,
    o.customer_unique_id,
    o.order_status,
    o.purchase_date,
    o.purchased_at,
    o.delivered_customer_at,
    o.estimated_delivery_at,
    o.customer_zip,
    o.customer_city,
    o.customer_state,
    o.review_score,
    o.is_late
from items i
inner join orders o on o.order_id = i.order_id
