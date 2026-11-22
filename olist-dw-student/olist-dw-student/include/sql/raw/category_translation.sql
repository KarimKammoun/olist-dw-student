-- raw.category_translation  (source file: CSV with a UTF-8 BOM)
-- Creates the table only if it does not exist yet.
-- The BOM (EF BB BF) is handled by the reader (encoding='utf-8-sig'), so the first column
-- really is product_category_name and not "<BOM>product_category_name".
IF OBJECT_ID(N'raw.category_translation', N'U') IS NULL
BEGIN
    CREATE TABLE raw.category_translation (
        product_category_name         NVARCHAR(120),
        product_category_name_english NVARCHAR(120),
        _source_file                  NVARCHAR(260),
        _loaded_at                    NVARCHAR(30)
    );
END;
