-- stg_category_translation  (source: raw.category_translation, from a CSV with a UTF-8 BOM)
-- 71 rows. Two categories of the products file have NO translation
-- ('pc_gamer', 'portateis_cozinha_e_preparadores_de_alimentos'): the left join in the
-- dimension keeps them with the fallback 'unknown'.
with source as (

    select
        product_category_name,
        product_category_name_english
    from {{ source('olist', 'category_translation') }}

)

select
    {{ clean_text('product_category_name') }}           as category_name,
    {{ clean_text('product_category_name_english') }}   as category_name_english
from source
where {{ clean_text('product_category_name') }} is not null
