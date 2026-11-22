-- fact_orders  (mart - FACT)
-- Grain: one row = ONE ORDER (99,441 rows).
-- This is the fact the cube uses for delivery performance and reviews.
-- FOUR date keys on purpose: the cube relates this fact to dim_date four times
-- (purchase, approved, delivered to carrier, delivered to customer).
-- Measures: orders_count (1), is_late (0/1), delivery_days, review_score.
-- is_late is computed on the DATE (day level): 6,534 of 96,478 delivered orders = 6.77%.
-- On the timestamp it would be 7,826 (8.11%), which is not what the course expects.
with orders as (

    select * from {{ ref('int_orders_enriched') }}

),

customers as (

    select customer_key, customer_id from {{ ref('dim_customers') }}

),

statuses as (

    select order_status_key, order_status from {{ ref('dim_order_status') }}

)

select
    o.order_id,

    -- foreign keys
    {{ date_key('o.purchased_at') }}            as purchase_date_key,
    {{ date_key('o.approved_at') }}             as approved_date_key,
    {{ date_key('o.delivered_carrier_at') }}    as delivered_carrier_date_key,
    {{ date_key('o.delivered_customer_at') }}   as delivered_customer_date_key,
    c.customer_key,
    st.order_status_key,

    -- measures
    1                                           as orders_count,
    o.is_late,
    o.delivery_days,
    o.review_score
from orders o
left join customers c  on c.customer_id   = o.customer_id
left join statuses  st on st.order_status = o.order_status
