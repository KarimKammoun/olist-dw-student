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
-- 98,666 and not 99,441: the 775 orders that have NO order line (canceled / unavailable
-- before any item was added) do not exist in fact_sales. On the source file:
-- 99,441 orders, 98,666 with at least one item, 775 without. 99,441 is the count of
-- the ORDERS themselves -> that is [Measures].[Orders Count] in fact_orders (TP8).
SELECT 'Order Count (distinct, fact_sales)', CAST(COUNT(DISTINCT order_id) AS DECIMAL(12, 2)), '98,666'        FROM marts.fact_sales
UNION ALL
SELECT 'Payment Value',            CAST(SUM(payment_value) AS DECIMAL(12, 2)),                '16,008,872.12' FROM marts.fact_payments
UNION ALL
-- 296,423 and not 104,634: the sum of the payment_installments column of the source file
-- is 296,423 (103,886 payments, max 24 installments). 104,634 is NOT a sum of that column:
-- it is close to the number of payments made in more than one instalment (51,338) x 2,
-- so it is most likely the number of PAYMENT ROWS counted differently in the course
-- document. The value to keep is the one the source file gives: 296,423.
SELECT 'Installments',             CAST(SUM(payment_installments) AS DECIMAL(12, 2)),         '296,423'       FROM marts.fact_payments;
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

PRINT '--- 8. checks that settle the two numbers of the course documents ------';
-- a) orders with no order line: explain why COUNT(DISTINCT order_id) on fact_sales = 98,666
SELECT COUNT(DISTINCT order_id) AS orders_in_fact_sales,
       (SELECT COUNT(*) FROM marts.fact_orders)                       AS orders_in_fact_orders,
       (SELECT COUNT(*) FROM marts.fact_orders) - COUNT(DISTINCT order_id) AS orders_without_line
FROM marts.fact_sales;
GO

-- b) installments: distribution, to compare with the 104,634 of the course
SELECT COUNT(*)                                            AS payments,
       SUM(payment_installments)                           AS sum_installments,
       SUM(CASE WHEN payment_installments > 1 THEN 1 ELSE 0 END) AS payments_with_installments,
       AVG(CAST(payment_installments AS DECIMAL(6, 3)))    AS avg_installments,
       MAX(payment_installments)                           AS max_installments
FROM marts.fact_payments;
GO
