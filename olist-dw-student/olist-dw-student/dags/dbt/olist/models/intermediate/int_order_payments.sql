-- int_order_payments  (intermediate, schema staging)
-- One row per order: how much was paid, in how many payments, with how many installments.
-- Grain change: raw/staging are one row per PAYMENT, this model is one row per ORDER.
with payments as (

    select * from {{ ref('stg_payments') }}

)

select
    order_id,
    cast(sum(payment_value) as decimal(12, 2))  as payment_total,
    count(*)                                    as payment_count,
    max(payment_installments)                   as payment_installments_max
from payments
group by order_id
