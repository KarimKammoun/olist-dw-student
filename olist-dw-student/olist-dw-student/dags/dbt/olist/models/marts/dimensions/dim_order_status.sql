-- dim_order_status  (mart - dimension)
-- Grain: one row per order status (8 values).
with statuses as (

    select distinct order_status
    from {{ ref('stg_orders') }}
    where order_status is not null

)

select
    {{ surrogate_key(['order_status']) }}   as order_status_key,
    order_status,
    case order_status
        when 'delivered'    then 'Delivered'
        when 'shipped'      then 'Shipped'
        when 'canceled'     then 'Canceled'
        when 'unavailable'  then 'Unavailable'
        when 'invoiced'     then 'Invoiced'
        when 'processing'   then 'Processing'
        when 'created'      then 'Created'
        when 'approved'     then 'Approved'
        else order_status
    end                                     as order_status_label,
    case when order_status = 'delivered' then 1 else 0 end as is_delivered
from statuses
