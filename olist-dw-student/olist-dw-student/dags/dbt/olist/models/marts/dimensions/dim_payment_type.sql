-- dim_payment_type  (mart - dimension)
-- Grain: one row per payment type (5 values, 'not_defined' included: it carries 3 rows
-- in the source and must not be dropped, otherwise the payment total changes).
with types as (

    select distinct payment_type
    from {{ ref('stg_payments') }}
    where payment_type is not null

)

select
    {{ surrogate_key(['payment_type']) }}   as payment_type_key,
    payment_type,
    case payment_type
        when 'credit_card' then 'Credit card'
        when 'boleto'      then 'Boleto (bank slip)'
        when 'voucher'     then 'Voucher'
        when 'debit_card'  then 'Debit card'
        else 'Not defined'
    end                                     as payment_type_label
from types
