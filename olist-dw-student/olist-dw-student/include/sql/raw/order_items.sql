-- raw.order_items  (source file: Parquet)
-- Creates the table only if it does not exist yet.
-- Every column is text: raw keeps the values exactly as they are in the file.
-- order_items was Parquet, so the reader (read_parquet_as_is) turns int64/double/timestamp
-- into text: order_item_id='1', price='58.9', shipping_limit_date='2017-09-19 09:45:35'.
IF OBJECT_ID(N'raw.order_items', N'U') IS NULL
BEGIN
    CREATE TABLE raw.order_items (
        order_id             NVARCHAR(50),   -- 32-char hex
        order_item_id        NVARCHAR(20),   -- was int64 in the file
        product_id           NVARCHAR(50),
        seller_id            NVARCHAR(50),
        shipping_limit_date  NVARCHAR(40),   -- was a timestamp
        price                NVARCHAR(40),   -- was a double
        freight_value        NVARCHAR(40),   -- was a double
        _source_file         NVARCHAR(260),  -- added by loader.write_raw()
        _loaded_at           NVARCHAR(30)    -- added by loader.write_raw()
    );
END;
