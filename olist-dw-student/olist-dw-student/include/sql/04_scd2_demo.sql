/* TP 7 - run as admin in SSMS (olist_dbt has no UPDATE on raw). */
USE OlistDW;
DECLARE @id NVARCHAR(100) = (SELECT TOP 1 customer_id FROM raw.customers ORDER BY customer_id);
UPDATE raw.customers SET customer_city = 'sousse', customer_state = 'TN' WHERE customer_id = @id;
-- now run:  dbt snapshot   then:
SELECT customer_id, customer_city, customer_state, dbt_valid_from, dbt_valid_to
FROM staging.snap_customers WHERE customer_id = @id ORDER BY dbt_valid_from;
