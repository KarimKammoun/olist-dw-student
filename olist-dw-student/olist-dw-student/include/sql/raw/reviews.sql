-- raw.reviews  (source file: JSON - one array, one object per review)
-- Creates the table only if it does not exist yet.
-- Same shape as payments: one JSON document per review in the column "record".
-- review_comment_message contains accents and line breaks, and can be long:
-- the loader escapes the JSON, so the document always fits in NVARCHAR(4000).
IF OBJECT_ID(N'raw.reviews', N'U') IS NULL
BEGIN
    CREATE TABLE raw.reviews (
        record        NVARCHAR(4000), -- the whole review as a JSON document
        _source_file  NVARCHAR(260),
        _loaded_at    NVARCHAR(30)
    );
END;
