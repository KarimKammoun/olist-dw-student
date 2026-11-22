-- raw.customers  (source file: Parquet)
-- Creates the table only if it does not exist yet.
-- customer_zip_code_prefix was int64 in the Parquet file, so it arrives as text WITHOUT
-- its leading zero ('01037' -> '1037'). We keep it as it is in raw: staging pads it back
-- with the zip5() macro. That is exactly why raw must not convert anything.
IF OBJECT_ID(N'raw.customers', N'U') IS NULL
BEGIN
    CREATE TABLE raw.customers (
        customer_id              NVARCHAR(50),
        customer_unique_id       NVARCHAR(50),
        customer_zip_code_prefix NVARCHAR(20),   -- leading zeros already lost
        customer_city            NVARCHAR(120),
        customer_state           NVARCHAR(10),
        _source_file             NVARCHAR(260),
        _loaded_at               NVARCHAR(30)
    );
END;
