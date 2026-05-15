-- Add file_name column to document table
-- This fixes the error: "Could not find the 'file_name' column of 'document'"

BEGIN;

-- Add file_name column to document table
ALTER TABLE document 
ADD COLUMN IF NOT EXISTS file_name TEXT;

-- Add comment
COMMENT ON COLUMN document.file_name IS 'Original filename of the uploaded document';

-- Optionally: Extract file names from existing file_url values
-- This will populate file_name for existing documents
UPDATE document
SET file_name = 
    CASE 
        WHEN file_url IS NOT NULL THEN 
            regexp_replace(
                substring(file_url from '[^/]*$'),  -- Get last part after /
                '\?.*$', ''                          -- Remove query params
            )
        ELSE NULL
    END
WHERE file_name IS NULL;

-- Verify the change
SELECT 
    table_name,
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'document'
AND column_name = 'file_name';

-- Show sample data
SELECT 
    id,
    doc_type,
    file_name,
    LEFT(file_url, 50) as file_url_preview,
    uploaded_at
FROM document
LIMIT 5;

COMMIT;

-- After running this, the document upload should work without errors
