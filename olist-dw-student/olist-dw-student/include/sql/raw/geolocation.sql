-- raw.geolocation  (source file: Parquet. One row = one geolocation record (many rows per zip prefix; 1,000,163 rows).)
-- Creates the table only if it does not exist yet.
-- Every column is text: raw keeps the values exactly as they are in the file.
IF OBJECT_ID(N'raw.geolocation', N'U') IS NULL
BEGIN
    CREATE TABLE raw.geolocation (
        geolocation_zip_code_prefix      NVARCHAR(100),
        geolocation_lat                  NVARCHAR(100),
        geolocation_lng                  NVARCHAR(100),
        geolocation_city                 NVARCHAR(200),
        geolocation_state                NVARCHAR(100),
        _source_file  NVARCHAR(260),  -- name of the file the row came from
        _loaded_at    NVARCHAR(30)    -- UTC time of the load
    );
END;
