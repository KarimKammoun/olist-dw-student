-- raw.geolocation  (source file: Parquet - 1,000,163 rows)
-- Creates the table only if it does not exist yet.
-- The file contains 261,831 EXACT duplicates and 19,015 distinct zip prefixes:
-- raw keeps them all (it is a faithful copy). Deduplication happens in staging.
-- Zip was int64, so leading zeros are lost (same story as customers).
IF OBJECT_ID(N'raw.geolocation', N'U') IS NULL
BEGIN
    CREATE TABLE raw.geolocation (
        geolocation_zip_code_prefix NVARCHAR(20),
        geolocation_lat             NVARCHAR(40),   -- was a double
        geolocation_lng             NVARCHAR(40),   -- was a double
        geolocation_city            NVARCHAR(120),
        geolocation_state           NVARCHAR(10),
        _source_file                NVARCHAR(260),
        _loaded_at                  NVARCHAR(30)
    );
END;
