-- raw.reviews  (source file: JSON (one array). One row = one customer review.)
-- Creates the table only if it does not exist yet.
-- Every column is text: raw keeps the values exactly as they are in the file.
IF OBJECT_ID(N'raw.reviews', N'U') IS NULL
BEGIN
    CREATE TABLE raw.reviews (
        record        NVARCHAR(MAX), -- the whole review as a JSON document
        _source_file  NVARCHAR(260),  -- name of the file the row came from
        _loaded_at    NVARCHAR(30)    -- UTC time of the load
    );
END;
