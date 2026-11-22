-- dim_customers  (mart - dimension)
-- Grain: one row per customer_id (99,441). customer_unique_id is the "real" person:
-- it repeats when the same person ordered more than once.
-- customer_key is the surrogate key (MD5 of the natural key): stable across rebuilds.
with customers as (

    select * from {{ ref('stg_customers') }}

),

geo as (

    select * from {{ ref('stg_geolocation') }}

)

select
    {{ surrogate_key(['c.customer_id']) }}      as customer_key,
    c.customer_id,
    c.customer_unique_id,
    c.zip_code_prefix,
    g.city                                      as geo_city,
    g.state                                     as geo_state,
    c.city                                      as city,
    c.state                                     as state
from customers c
left join geo g on g.zip_code_prefix = c.zip_code_prefix
