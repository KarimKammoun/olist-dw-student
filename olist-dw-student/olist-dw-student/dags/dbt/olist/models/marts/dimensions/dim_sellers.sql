-- dim_sellers  (mart - dimension)
-- Grain: one row per seller (3,095). Seller attributes are the ones of the CSV file;
-- the geolocation average of the seller zip prefix is joined when it exists.
with sellers as (

    select * from {{ ref('stg_sellers') }}

),

geo as (

    select * from {{ ref('stg_geolocation') }}

)

select
    {{ surrogate_key(['s.seller_id']) }}        as seller_key,
    s.seller_id,
    s.zip_code_prefix,
    s.city,
    s.state,
    g.lat                                       as lat,
    g.lng                                       as lng
from sellers s
left join geo g on g.zip_code_prefix = s.zip_code_prefix
