-- fact_sales  (mart - FACT)
-- Grain: one row = ONE ORDER LINE (112,650 rows, same as the source file).
-- Measures: item price, freight, total. Dimensions: date (purchase), customer, product,
-- seller, order status. The "distinct order count" measure of the cube is computed as a
-- distinct count of order_id (a degenerate dimension kept on the fact).
with sales as (

    select * from {{ ref('int_sales_enriched') }}

),

products as (

    select product_key, product_id from {{ ref('dim_products') }}

),

sellers as (

    select seller_key, seller_id from {{ ref('dim_sellers') }}

),

customers as (

    select customer_key, customer_id from {{ ref('dim_customers') }}

),

statuses as (

    select order_status_key, order_status from {{ ref('dim_order_status') }}

)

select
    -- degenerate dimensions (no dimension table, they live on the fact)
    s.order_id,
    s.order_item_id,

    -- foreign keys
    {{ date_key('s.purchased_at') }}    as date_key,
    c.customer_key,
    p.product_key,
    s2.seller_key,
    st.order_status_key,

    -- measures
    s.price,
    s.freight_value,
    s.total_value,
    1                                   as item_count
from sales s
left join products  p  on p.product_id      = s.product_id
left join sellers   s2 on s2.seller_id      = s.seller_id
left join customers c  on c.customer_id     = s.customer_id
left join statuses  st on st.order_status   = s.order_status
