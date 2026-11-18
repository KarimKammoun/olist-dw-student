-- raw.orders  (source file: JSONL)
-- Creates the table only if it does not exist yet.
-- Every column is text: raw keeps the values exactly as they are in the file.
IF OBJECT_ID(N'raw.orders', N'U') IS NULL
BEGIN
    CREATE TABLE raw.orders (
        record        NVARCHAR(4000), -- the whole record as a JSON document
        _source_file  NVARCHAR(260),  -- name of the file the row came from
        _loaded_at    NVARCHAR(30)    -- UTC time of the load
    );
END;
