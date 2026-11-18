USE OlistDW;
-- Row counts of every raw table (compare with the log of the task report_counts)
SELECT t.name AS table_name, SUM(p.rows) AS row_count
FROM sys.tables t
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE SCHEMA_NAME(t.schema_id) = 'raw'
GROUP BY t.name ORDER BY t.name;

-- When was each table loaded, and from which file?
SELECT 'orders' AS raw_table, MAX(_source_file) AS source_file, MAX(_loaded_at) AS loaded_at FROM raw.orders
UNION ALL SELECT 'payments', MAX(_source_file), MAX(_loaded_at) FROM raw.payments
UNION ALL SELECT 'reviews',  MAX(_source_file), MAX(_loaded_at) FROM raw.reviews
UNION ALL SELECT 'customers', MAX(_source_file), MAX(_loaded_at) FROM raw.customers;
