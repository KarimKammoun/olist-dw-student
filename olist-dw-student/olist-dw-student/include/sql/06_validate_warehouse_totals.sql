-- validates the warehouse against the reference numbers of the course (cube/README.md).
-- Run in SSMS, as any login that can read marts (or as admin).
-- Every "expected" value below is the value given by the course files.
USE OlistDW;
GO

PRINT '--- 1. row counts (raw + staging + marts) -------------------------------';
SELECT 'raw.orders'               AS object_name, COUNT(*) AS row_count FROM raw.orders
UNION ALL SELECT 'raw.order_items',        COUNT(*) FROM raw.order_items
UNION ALL SELECT 'raw.payments',           COUNT(*) FROM raw.payments
UNION ALL SELECT 'raw.reviews',            COUNT(*) FROM raw.reviews
UNION ALL SELECT 'raw.customers',          COUNT(*) FROM raw.customers
UNION ALL SELECT 'raw.products',           COUNT(*) FROM raw.products
UNION ALL SELECT 'raw.sellers',            COUNT(*) FROM raw.sellers
UNION ALL SELECT 'raw.geolocation',        COUNT(*) FROM raw.geolocation
UNION ALL SELECT 'raw.category_translation', COUNT(*) FROM raw.category_translation
ORDER BY object_name;
GO

PRINT '--- 2. the five numbers of the course -----------------------------------';
SELECT 'Sales Amount (all years)'  AS kpi, CAST(SUM(price) AS DECIMAL(12, 2)) AS value, '13,591,643.70' AS expected FROM marts.fact_sales
UNION ALL
SELECT 'Freight Amount',           CAST(SUM(freight_value) AS DECIMAL(12, 2)),                '2,251,909.54'  FROM marts.fact_sales
UNION ALL
SELECT 'Total Amount',             CAST(SUM(price + freight_value) AS DECIMAL(12, 2)),        '15,843,553.24' FROM marts.fact_sales
UNION ALL
SELECT 'Item Count',               CAST(SUM(item_count) AS DECIMAL(12, 2)),                   '112,650'       FROM marts.fact_sales
UNION ALL
SELECT 'Order Count (distinct)',   CAST(COUNT(DISTINCT order_id) AS DECIMAL(12, 2)),          '99,441'        FROM marts.fact_sales
UNION ALL
SELECT 'Payment Value',            CAST(SUM(payment_value) AS DECIMAL(12, 2)),                '16,008,872.12' FROM marts.fact_payments
UNION ALL
SELECT 'Installments',             CAST(SUM(payment_installments) AS DECIMAL(12, 2)),         '104,634'       FROM marts.fact_payments;
GO

PRINT '--- 3. Sales Amount per year (expected 49,785.92 / 6,155,806.98 / 7,386,050.80) ---';
SELECT d.year,
       CAST(SUM(f.price) AS DECIMAL(12, 2))          AS sales_amount,
       SUM(f.item_count)                             AS item_count,
       COUNT(DISTINCT f.order_id)                    AS orders
FROM marts.fact_sales f
JOIN marts.dim_date d ON d.date_key = f.date_key
WHERE d.year BETWEEN 2016 AND 2018
GROUP BY d.year
ORDER BY d.year;
GO

PRINT '--- 4. Late rate (expected 6.77% = 6,534 / 96,478) ---------------------';
SELECT SUM(CASE WHEN s.order_status = 'delivered' THEN 1 ELSE 0 END)          AS delivered_orders,
       SUM(CASE WHEN s.order_status = 'delivered' THEN f.is_late ELSE 0 END)  AS late_orders,
       CAST(100.0 * SUM(CASE WHEN s.order_status = 'delivered' THEN f.is_late ELSE 0 END)
            / NULLIF(SUM(CASE WHEN s.order_status = 'delivered' THEN 1 ELSE 0 END), 0)
            AS DECIMAL(6, 2))                                                 AS late_rate_pct
FROM marts.fact_orders f
JOIN marts.dim_order_status s ON s.order_status_key = f.order_status_key;
GO

PRINT '--- 5. Payment Value per type (credit_card 12,511,046 / boleto 3,474,132 ...) ---';
SELECT t.payment_type,
       CAST(SUM(p.payment_value) AS DECIMAL(12, 2)) AS payment_value,
       SUM(p.payment_installments)                  AS installments
FROM marts.fact_payments p
JOIN marts.dim_payment_type t ON t.payment_type_key = p.payment_type_key
GROUP BY t.payment_type
ORDER BY payment_value DESC;
GO

PRINT '--- 6. SCD2 history (TP7): first customer, should show 2 rows after the demo ---';
SELECT customer_id, customer_city, customer_state, dbt_valid_from, dbt_valid_to
FROM staging.snap_customers
WHERE customer_id = (SELECT TOP 1 customer_id FROM raw.customers ORDER BY customer_id)
ORDER BY dbt_valid_from;
GO

PRINT '--- 7. what the SSAS cube reads: the 9 tables of schema marts ----------';
SELECT s.name AS table_name, SUM(p.rows) AS row_count
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
JOIN sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
WHERE s.name = 'marts'
GROUP BY s.name, t.name
ORDER BY t.name;
GO
