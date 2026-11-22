-- fact_payments  (mart - FACT)
-- Grain: one row = ONE PAYMENT (103,886 rows).
-- Payment Type is a real dimension here (a payment has exactly one type), and the same
-- payment can also carry the purchase date + customer, so the cube can slice payments
-- by time, by customer state, etc.
with payments as (

    select * from {{ ref('stg_payments') }}

),

orders as (

    select * from {{ ref('int_orders_enriched') }}

),

types as (

    select payment_type_key, payment_type from {{ ref('dim_payment_type') }}

),

customers as (

    select customer_key, customer_id from {{ ref('dim_customers') }}

)

select
    p.order_id,
    p.payment_sequential,

    {{ date_key('o.purchased_at') }}    as date_key,
    t.payment_type_key,
    c.customer_key,

    p.payment_value,
    p.payment_installments
from payments p
left join orders    o on o.order_id    = p.order_id
left join types     t on t.payment_type = p.payment_type
left join customers c on c.customer_id  = o.customer_id
