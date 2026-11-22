-- dim_date  (mart - dimension)
-- One row per calendar day, 2016-01-01 .. 2019-12-31 (1,461 days) + one "unknown" member.
-- The cube relates fact_orders to this dimension FOUR times (purchase, approved,
-- delivered to carrier, delivered to customer): that is why fact_orders has four date keys.
-- date_key is an INT in YYYYMMDD form (-1 when the date is missing): readable and fast to join.
--
-- The numbers are generated with a small tally table (10 x 10 x 10 x 10 = 10,000) and NOT
-- with sys.all_objects: a low-privilege login like olist_dbt only sees its own objects
-- there, so sys.all_objects could return fewer than 1,461 rows and silently produce a
-- truncated calendar.
with digits as (

    select n from (values (0), (1), (2), (3), (4), (5), (6), (7), (8), (9)) as d(n)

),

numbers as (

    select
        d1.n + 10 * d2.n + 100 * d3.n + 1000 * d4.n as i
    from digits d1
    cross join digits d2
    cross join digits d3
    cross join digits d4

),

dates as (

    select dateadd(day, i, cast('2016-01-01' as date)) as full_date
    from numbers
    where i <= 1460          -- 2016-01-01 + 1,460 days = 2019-12-31

),

calendar as (

    select
        cast(convert(char(8), full_date, 112) as int)   as date_key,
        full_date,
        year(full_date)                                 as year,
        datepart(quarter, full_date)                    as quarter,
        month(full_date)                                as month,
        datename(month, full_date)                      as month_name,
        day(full_date)                                  as day_of_month,
        -- ISO day of week (1 = Monday .. 7 = Sunday) and weekend flag, both computed
        -- from the distance to 1900-01-01 (a Monday): independent of the DATEFIRST setting
        datediff(day, cast('1900-01-01' as date), full_date) % 7 + 1  as day_of_week,
        datename(weekday, full_date)                    as day_name,
        case when datediff(day, cast('1900-01-01' as date), full_date) % 7 in (5, 6)
             then 1 else 0 end                          as is_weekend
    from dates

)

select
    date_key,
    full_date,
    year,
    quarter,
    month,
    month_name,
    day_of_month,
    day_of_week,
    day_name,
    is_weekend
from calendar

union all

-- "unknown" member: every fact key that has no date (NULL) points here (-1),
-- so the cube always finds a dimension row and never loses a measure.
select
    -1                          as date_key,
    cast('1900-01-01' as date)  as full_date,
    0                           as year,
    0                           as quarter,
    0                           as month,
    'Unknown'                   as month_name,
    0                           as day_of_month,
    0                           as day_of_week,
    'Unknown'                   as day_name,
    0                           as is_weekend
