-- raw.products  (source file: CSV. One row = one product. Kaggle typos product_*_lenght are kept as-is.)
-- Creates the table only if it does not exist yet.
-- Every column is text: raw keeps the values exactly as they are in the file.
IF OBJECT_ID(N'raw.products', N'U') IS NULL
BEGIN
    CREATE TABLE raw.products (
        product_id                       NVARCHAR(100),
        product_category_name            NVARCHAR(200),
        product_name_lenght              NVARCHAR(100),
        product_description_lenght       NVARCHAR(100),
        product_photos_qty               NVARCHAR(100),
        product_weight_g                 NVARCHAR(100),
        product_length_cm                NVARCHAR(100),
        product_height_cm                NVARCHAR(100),
        product_width_cm                 NVARCHAR(100),
        _source_file  NVARCHAR(260),  -- name of the file the row came from
        _loaded_at    NVARCHAR(30)    -- UTC time of the load
    );
END;
