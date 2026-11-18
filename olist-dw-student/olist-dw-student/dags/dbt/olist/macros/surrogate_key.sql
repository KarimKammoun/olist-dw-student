{#-
  Stable surrogate key: MD5 of the natural key columns, as a 32-char hex string.
  Same input -> same key on every rebuild, independent of load order.
-#}
{% macro surrogate_key(columns) -%}
CONVERT(CHAR(32), HASHBYTES('MD5', CONCAT_WS('|',
    {%- for col in columns %}
    COALESCE(CAST({{ col }} AS NVARCHAR(4000)), N'_null_'),
    {%- endfor %}
    N'')), 2)
{%- endmacro %}
