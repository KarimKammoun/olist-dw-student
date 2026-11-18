{#- Typing helpers for staging. Raw columns are all text; bad values become NULL. -#}

{% macro to_int(col) -%}
TRY_CAST(TRY_CAST(NULLIF(TRIM({{ col }}), '') AS FLOAT) AS INT)
{%- endmacro %}

{#- Through FLOAT first: Parquet doubles and JSON numbers may arrive as text like '58.9',
    '1.2e-05' or with extra decimals; FLOAT accepts them all, then DECIMAL rounds to cents. -#}
{% macro to_money(col) -%}
CAST(ROUND(TRY_CAST(NULLIF(TRIM({{ col }}), '') AS FLOAT), 2) AS DECIMAL(12, 2))
{%- endmacro %}

{% macro to_float(col) -%}
TRY_CAST(NULLIF(TRIM({{ col }}), '') AS FLOAT)
{%- endmacro %}

{% macro to_ts(col) -%}
TRY_CAST(NULLIF(TRIM({{ col }}), '') AS DATETIME2(0))
{%- endmacro %}

{#- Parquet/JSON store zip prefixes as integers, so 01037 arrives as 1037: pad back to 5 digits.
    Also accepts '1037.0' from float columns. -#}
{% macro zip5(col) -%}
RIGHT('00000' + CAST(TRY_CAST(TRY_CAST(NULLIF(TRIM({{ col }}), '') AS FLOAT) AS INT) AS VARCHAR(10)), 5)
{%- endmacro %}

{#- Integer date key YYYYMMDD, -1 when the date is missing -#}
{% macro date_key(col) -%}
COALESCE(CAST(CONVERT(CHAR(8), {{ col }}, 112) AS INT), -1)
{%- endmacro %}

{#- Text as it should be: trimmed, and an empty string becomes NULL (CSV keeps empty cells as '') -#}
{% macro clean_text(col) -%}
NULLIF(TRIM({{ col }}), '')
{%- endmacro %}
