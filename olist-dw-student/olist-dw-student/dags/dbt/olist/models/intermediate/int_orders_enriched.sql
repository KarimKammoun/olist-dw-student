-- int_orders_enriched  (intermediate, schema staging)
-- One row per ORDER, with everything the dimensions and the fact_orders need:
-- the customer attributes, the single review, the payment summary and the delivery metrics.
-- is_late compares the DELIVERY DATE with the ESTIMATED DATE (day level, not timestamp):
-- doing it on the timestamp gives 7,826 late orders (8.11%) instead of the 6,534 (6.77%)
-- that the course expects.
with orders as (

    select * from {{ ref('stg_orders') }}

),

customers as (

    select * from {{ ref('stg_customers') }}

),

reviews as (

    select * from {{ ref('int_order_reviews') }}

),

payments as (

    select * from {{ ref('int_order_payments') }}

)

select
    o.order_id,
    o.customer_id,
    o.order_status,
    o.purchased_at,
    o.approved_at,
    o.delivered_carrier_at,
    o.delivered_customer_at,
    o.estimated_delivery_at,
    cast(o.purchased_at as date)                    as purchase_date,

    c.customer_unique_id,
    c.zip_code_prefix                               as customer_zip,
    c.city                                          as customer_city,
    c.state                                         as customer_state,

    r.review_id,
    r.review_score,

    p.payment_total,
    p.payment_count,
    p.payment_installments_max,

    -- delivery performance
    datediff(day, cast(o.purchased_at as date), cast(o.delivered_customer_at as date))
                                                    as delivery_days,
    case
        when o.order_status = 'delivered'
         and o.delivered_customer_at is not null
         and o.estimated_delivery_at is not null
         and cast(o.delivered_customer_at as date) > cast(o.estimated_delivery_at as date)
        then 1 else 0
    end                                             as is_late
from orders o
left join customers c on c.customer_id = o.customer_id
left join reviews   r on r.order_id    = o.order_id
left join payments  p on p.order_id    = o.order_id
