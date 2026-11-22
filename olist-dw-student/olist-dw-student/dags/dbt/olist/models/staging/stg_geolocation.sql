-- stg_geolocation  (source: raw.geolocation, from Parquet - 1,000,163 rows)
-- The source has 261,831 exact duplicates and 19,015 distinct zip prefixes.
-- One row per zip prefix is enough for the warehouse: the latitude/longitude are the
-- average of every point of that prefix (deterministic: same result on every rebuild).
--
-- MATERIALIZED AS A TABLE (exception to the "staging = view" rule):
-- reducing 1,000,163 rows to 19,015 means a GROUP BY over a million rows. As a view, that
-- GROUP BY would be re-executed by every model joining it (dim_customers, dim_sellers).
-- As a table it is computed once per dbt run.
{{ config(materialized='table') }}

with source as (

    select
        geolocation_zip_code_prefix,
        geolocation_lat,
        geolocation_lng,
        geolocation_city,
        geolocation_state
    from {{ source('olist', 'geolocation') }}

),

typed as (

    select
        {{ zip5('geolocation_zip_code_prefix') }}       as zip_code_prefix,
        {{ to_float('geolocation_lat') }}               as lat,
        {{ to_float('geolocation_lng') }}               as lng,
        lower({{ clean_text('geolocation_city') }})     as city,
        upper({{ clean_text('geolocation_state') }})    as state
    from source
    where {{ clean_text('geolocation_zip_code_prefix') }} is not null

)

select
    zip_code_prefix,
    cast(round(avg(lat), 6) as decimal(10, 6))  as lat,
    cast(round(avg(lng), 6) as decimal(10, 6))  as lng,
    max(city)                                   as city,
    max(state)                                  as state
from typed
group by zip_code_prefix
