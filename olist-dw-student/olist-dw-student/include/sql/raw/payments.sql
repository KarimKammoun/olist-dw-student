-- raw.payments  (source file: JSON - one array, one object per payment)
-- Creates the table only if it does not exist yet.
-- JSON files are NOT split into columns in raw: read_json_records() keeps each payment
-- as ONE JSON document in the column "record" (exactly like raw.orders with JSONL).
-- Flattening happens later, in staging (stg_payments, with OPENJSON).
IF OBJECT_ID(N'raw.payments', N'U') IS NULL
BEGIN
    CREATE TABLE raw.payments (
        record        NVARCHAR(4000), -- the whole payment as a JSON document
        _source_file  NVARCHAR(260),  -- name of the file the row came from
        _loaded_at    NVARCHAR(30)    -- UTC time of the load
    );
END;
