-- raw.sellers  (source file: CSV. One row = one seller.)
-- Creates the table only if it does not exist yet.
-- Every column is text: raw keeps the values exactly as they are in the file.
IF OBJECT_ID(N'raw.sellers', N'U') IS NULL
BEGIN
    CREATE TABLE raw.sellers (
        seller_id                        NVARCHAR(100),
        seller_zip_code_prefix           NVARCHAR(100),
        seller_city                      NVARCHAR(200),
        seller_state                     NVARCHAR(100),
        _source_file  NVARCHAR(260),  -- name of the file the row came from
        _loaded_at    NVARCHAR(30)    -- UTC time of the load
    );
END;
