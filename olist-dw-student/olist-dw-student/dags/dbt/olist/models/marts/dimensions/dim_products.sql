-- dim_products  (mart - dimension)
-- Grain: one row per product (32,951). The English category comes from the translation
-- file; two categories have no translation ('pc_gamer', 'portateis_...') and the 610
-- products with an empty category are labelled 'unknown'.
with products as (

    select * from {{ ref('stg_products') }}

),

translation as (

    select * from {{ ref('stg_category_translation') }}

)

select
    {{ surrogate_key(['p.product_id']) }}                       as product_key,
    p.product_id,
    coalesce(p.category_name, 'unknown')                        as category_name,
    coalesce(t.category_name_english, 'unknown')                as category_name_english,
    p.name_length,
    p.description_length,
    p.photos_qty,
    p.weight_g,
    p.length_cm,
    p.height_cm,
    p.width_cm
from products p
left join translation t on t.category_name = p.category_name
