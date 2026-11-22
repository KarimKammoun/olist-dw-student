-- stg_products  (source: raw.products, from CSV)
-- Two Kaggle typos are fixed here (lenght -> length); an empty category ('') becomes NULL.
with source as (

    select
        product_id,
        product_category_name,
        product_name_lenght,
        product_description_lenght,
        product_photos_qty,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm
    from {{ source('olist', 'products') }}

)

select
    {{ clean_text('product_id') }}                      as product_id,
    {{ clean_text('product_category_name') }}           as category_name,
    {{ to_int('product_name_lenght') }}                 as name_length,
    {{ to_int('product_description_lenght') }}          as description_length,
    {{ to_int('product_photos_qty') }}                  as photos_qty,
    {{ to_int('product_weight_g') }}                    as weight_g,
    {{ to_int('product_length_cm') }}                   as length_cm,
    {{ to_int('product_height_cm') }}                   as height_cm,
    {{ to_int('product_width_cm') }}                    as width_cm
from source
where {{ clean_text('product_id') }} is not null
