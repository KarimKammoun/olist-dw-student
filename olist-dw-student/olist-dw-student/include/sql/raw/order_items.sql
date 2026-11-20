-- raw.order_items  (source file: Parquet. One row = one article in an order. Kaggle order_items.)
-- Creates the table only if it does not exist yet.
-- Every column is text: raw keeps the values exactly as they are in the file.
IF OBJECT_ID(N'raw.order_items', N'U') IS NULL
BEGIN
    CREATE TABLE raw.order_items (
        order_id                         NVARCHAR(100),
        order_item_id                    NVARCHAR(100),
        product_id                       NVARCHAR(100),
        seller_id                        NVARCHAR(100),
        shipping_limit_date              NVARCHAR(100),
        price                            NVARCHAR(100),
        freight_value                    NVARCHAR(100),
        _source_file  NVARCHAR(260),  -- name of the file the row came from
        _loaded_at    NVARCHAR(30)    -- UTC time of the load
    );
END;
