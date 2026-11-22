-- raw.products  (source file: CSV - copied untouched)
-- Creates the table only if it does not exist yet.
-- The Kaggle header has two typos kept as-is: product_name_lenght / product_description_lenght.
-- 610 rows have an EMPTY category (''): read_csv_as_is keeps empty cells as '' (not NULL).
IF OBJECT_ID(N'raw.products', N'U') IS NULL
BEGIN
    CREATE TABLE raw.products (
        product_id                 NVARCHAR(50),
        product_category_name      NVARCHAR(120),  -- '' for 610 products
        product_name_lenght        NVARCHAR(20),   -- (sic) int in the file
        product_description_lenght NVARCHAR(20),   -- (sic) int in the file
        product_photos_qty         NVARCHAR(20),
        product_weight_g           NVARCHAR(20),
        product_length_cm          NVARCHAR(20),
        product_height_cm          NVARCHAR(20),
        product_width_cm           NVARCHAR(20),
        _source_file               NVARCHAR(260),
        _loaded_at                 NVARCHAR(30)
    );
END;
