-- raw.category_translation  (source file: CSV (UTF-8 BOM). One row = one category translation.)
-- Creates the table only if it does not exist yet.
-- Every column is text: raw keeps the values exactly as they are in the file.
IF OBJECT_ID(N'raw.category_translation', N'U') IS NULL
BEGIN
    CREATE TABLE raw.category_translation (
        product_category_name            NVARCHAR(200),
        product_category_name_english    NVARCHAR(200),
        _source_file  NVARCHAR(260),  -- name of the file the row came from
        _loaded_at    NVARCHAR(30)    -- UTC time of the load
    );
END;
