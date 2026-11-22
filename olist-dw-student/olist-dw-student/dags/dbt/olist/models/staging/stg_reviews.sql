-- stg_reviews  (source: raw.reviews, from JSON)
-- review_id is NOT unique in the source (814 repetitions), but (review_id, order_id) is.
-- 547 orders have more than one review: the marts pick one review per order (intermediate).
with source as (

    select record
    from {{ source('olist', 'reviews') }}

),

flattened as (

    select j.*
    from source
    cross apply openjson(source.record) with (
        review_id                 nvarchar(50)   '$.review_id',
        order_id                  nvarchar(50)   '$.order_id',
        review_score              nvarchar(20)   '$.review_score',
        review_comment_title      nvarchar(200)  '$.review_comment_title',
        review_comment_message    nvarchar(4000) '$.review_comment_message',
        review_creation_date      nvarchar(50)   '$.review_creation_date',
        review_answer_timestamp   nvarchar(50)   '$.review_answer_timestamp'
    ) as j

)

select
    {{ clean_text('review_id') }}                        as review_id,
    {{ clean_text('order_id') }}                         as order_id,
    {{ to_int('review_score') }}                         as review_score,
    {{ clean_text('review_comment_title') }}             as review_comment_title,
    {{ clean_text('review_comment_message') }}           as review_comment_message,
    {{ to_ts('review_creation_date') }}                  as review_created_at,
    {{ to_ts('review_answer_timestamp') }}               as review_answered_at
from flattened
where {{ clean_text('review_id') }} is not null
  and {{ clean_text('order_id') }} is not null
