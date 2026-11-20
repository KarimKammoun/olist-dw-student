-- raw.customers  (source file: Parquet. One row = one customer of the file (one row per order in Olist).)
-- Creates the table only if it does not exist yet.
-- Every column is text: raw keeps the values exactly as they are in the file.
IF OBJECT_ID(N'raw.customers', N'U') IS NULL
BEGIN
    CREATE TABLE raw.customers (
        customer_id                      NVARCHAR(100),
        customer_unique_id               NVARCHAR(100),
        customer_zip_code_prefix         NVARCHAR(100),
        customer_city                    NVARCHAR(200),
        customer_state                   NVARCHAR(100),
        _source_file  NVARCHAR(260),  -- name of the file the row came from
        _loaded_at    NVARCHAR(30)    -- UTC time of the load
    );
END;
