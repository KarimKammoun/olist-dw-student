USE OlistDW;
-- Row counts of every raw table (compare with the log of the check_rows task of each load_raw_* DAG)
SELECT t.name AS table_name, SUM(p.rows) AS row_count
FROM sys.tables t
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE SCHEMA_NAME(t.schema_id) = 'raw'
GROUP BY t.name ORDER BY t.name;

-- Expected volumes:
-- orders 99,441 | order_items 112,650 | payments 103,886 | reviews 99,224 | customers 99,441
-- products 32,951 | sellers 3,095 | geolocation 1,000,163 | category_translation 71

-- When was each table loaded, and from which file? (the 2 metadata columns added by write_raw)
SELECT 'orders' AS raw_table, MAX(_source_file) AS source_file, MAX(_loaded_at) AS loaded_at FROM raw.orders
UNION ALL SELECT 'order_items', MAX(_source_file), MAX(_loaded_at) FROM raw.order_items
UNION ALL SELECT 'payments',    MAX(_source_file), MAX(_loaded_at) FROM raw.payments
UNION ALL SELECT 'reviews',     MAX(_source_file), MAX(_loaded_at) FROM raw.reviews
UNION ALL SELECT 'customers',   MAX(_source_file), MAX(_loaded_at) FROM raw.customers
UNION ALL SELECT 'products',    MAX(_source_file), MAX(_loaded_at) FROM raw.products
UNION ALL SELECT 'sellers',     MAX(_source_file), MAX(_loaded_at) FROM raw.sellers
UNION ALL SELECT 'geolocation', MAX(_source_file), MAX(_loaded_at) FROM raw.geolocation
UNION ALL SELECT 'category_translation', MAX(_source_file), MAX(_loaded_at) FROM raw.category_translation;

-- Basic sanity checks (all values come from the files, stored as text)
SELECT COUNT(*) AS orders_rows, COUNT(DISTINCT record) AS distinct_orders FROM raw.orders;          -- 99,441 / 99,441
SELECT COUNT(*) AS items_rows, COUNT(DISTINCT order_id + '|' + CAST(order_item_id AS NVARCHAR(10))) AS distinct_items FROM raw.order_items;  -- 112,650 / 112,650
SELECT COUNT(*) AS payments_rows FROM raw.payments;                                                 -- 103,886
SELECT COUNT(*) AS reviews_rows FROM raw.reviews;                                                   -- 99,224
SELECT COUNT(*) AS customers_rows FROM raw.customers;                                               -- 99,441
SELECT COUNT(*) AS products_rows FROM raw.products;                                                 -- 32,951
SELECT COUNT(*) AS sellers_rows FROM raw.sellers;                                                   -- 3,095
SELECT COUNT(*) AS geolocation_rows FROM raw.geolocation;                                           -- 1,000,163
SELECT COUNT(*) AS category_translation_rows FROM raw.category_translation;                          -- 71
