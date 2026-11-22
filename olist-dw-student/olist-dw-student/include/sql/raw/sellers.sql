-- raw.sellers  (source file: CSV - copied untouched)
-- Creates the table only if it does not exist yet.
-- This CSV keeps its leading zeros ('01037' stays '01037'): a CSV is text from the start.
IF OBJECT_ID(N'raw.sellers', N'U') IS NULL
BEGIN
    CREATE TABLE raw.sellers (
        seller_id              NVARCHAR(50),
        seller_zip_code_prefix NVARCHAR(20),
        seller_city            NVARCHAR(120),
        seller_state           NVARCHAR(10),
        _source_file           NVARCHAR(260),
        _loaded_at             NVARCHAR(30)
    );
END;
