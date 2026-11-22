-- stg_payments  (source: raw.payments, from JSON)
-- raw.payments has ONE column: record = the whole payment as a JSON document.
-- Same three steps as stg_orders: flatten (OPENJSON) -> clean -> type.
with source as (

    select record
    from {{ source('olist', 'payments') }}

),

flattened as (

    select j.*
    from source
    cross apply openjson(source.record) with (
        order_id             nvarchar(50)  '$.order_id',
        payment_sequential   nvarchar(20)  '$.payment_sequential',
        payment_type         nvarchar(50)  '$.payment_type',
        payment_installments nvarchar(20)  '$.payment_installments',
        payment_value        nvarchar(40)  '$.payment_value'
    ) as j

)

select
    {{ clean_text('order_id') }}                                as order_id,
    {{ to_int('payment_sequential') }}                           as payment_sequential,
    lower({{ clean_text('payment_type') }})                      as payment_type,
    {{ to_int('payment_installments') }}                         as payment_installments,
    {{ to_money('payment_value') }}                              as payment_value
from flattened
where {{ clean_text('order_id') }} is not null
