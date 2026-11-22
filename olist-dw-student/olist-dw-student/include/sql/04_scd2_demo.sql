/* ============================================================================
   TP 7 - demo of the SCD2 snapshot  (run in SSMS, as ADMIN, on OlistDW)
   ============================================================================
   Why two blocks and a pause in between?
     The snapshot keeps history by COMPARING the source table with what it stored.
     So the order is always:
        (1) change a row in raw.customers      <- this file, block A
        (2) run dbt snapshot                   <- in the container (README, TP7)
        (3) read staging.snap_customers        <- this file, block B
     olist_dbt has no UPDATE on raw: that is why block A needs the admin login.

   The customer is the first one by customer_id (00012a2ce...), the same one the
   README displays, so the expected output is predictable.
   ============================================================================ */

USE OlistDW;
GO

/* ------------------------------------------------------------------ BLOCK A
   Change the city of the first customer. The value toggles between 'sousse' and
   'recife' so the script can be replayed as many times as you want: each run is
   guaranteed to change something, which is what creates a new version.
   ------------------------------------------------------------------------- */
DECLARE @id   NVARCHAR(100) = (SELECT TOP 1 customer_id FROM raw.customers ORDER BY customer_id);
DECLARE @city NVARCHAR(100) = (SELECT CASE WHEN customer_city = 'sousse' THEN 'recife' ELSE 'sousse' END
                              FROM raw.customers WHERE customer_id = @id);

PRINT '--- A.1 BEFORE the update ---------------------------------------------';
SELECT customer_id, customer_city, customer_state FROM raw.customers WHERE customer_id = @id;

UPDATE raw.customers
SET customer_city  = @city,
    customer_state = CASE WHEN @city = 'sousse' THEN 'TN' ELSE 'PE' END
WHERE customer_id = @id;

PRINT '--- A.2 rows changed (must be 1) -------------------------------------';
SELECT @@ROWCOUNT AS rows_updated;

PRINT '--- A.3 AFTER the update ----------------------------------------------';
SELECT customer_id, customer_city, customer_state FROM raw.customers WHERE customer_id = @id;
GO

/* NOW, before anything else, run in the container (README TP7, step 5):
       /usr/local/airflow/dbt_venv/bin/dbt snapshot --profiles-dir . --target docker --select snap_customers
   Then come back and run BLOCK B.
*/

/* ------------------------------------------------------------------ BLOCK B
   The customer must now have TWO versions: the old one (closed) and the new one
   (open, dbt_valid_to IS NULL). One version = the snapshot did not run after the
   update; three versions = block A was run three times without a snapshot in
   between, which is also correct SCD2 behaviour.
   ------------------------------------------------------------------------- */
USE OlistDW;
GO
DECLARE @id NVARCHAR(100) = (SELECT TOP 1 customer_id FROM raw.customers ORDER BY customer_id);

SELECT customer_id,
       customer_city,
       customer_state,
       dbt_valid_from,
       dbt_valid_to,
       CASE WHEN dbt_valid_to IS NULL THEN 'current version' ELSE 'closed version' END AS version_type
FROM staging.snap_customers
WHERE customer_id = @id
ORDER BY dbt_valid_from;

-- summary of the whole snapshot: number of rows, of versions, of customers
SELECT COUNT(*)                            AS versions_total,
       COUNT(dbt_valid_to)                 AS closed_versions,
       COUNT(DISTINCT customer_id)         AS distinct_customers
FROM staging.snap_customers;
GO
