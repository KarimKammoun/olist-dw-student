-- int_order_reviews  (intermediate, schema staging)
-- One review per order. The source has 547 orders with more than one review, so we keep
-- the most recent one (tie-break on review_id, so that the result is deterministic).
with reviews as (

    select * from {{ ref('stg_reviews') }}

),

ranked as (

    select
        *,
        row_number() over (
            partition by order_id
            order by review_created_at desc, review_id desc
        ) as rn
    from reviews

)

select
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_created_at,
    review_answered_at
from ranked
where rn = 1
