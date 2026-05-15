-- Add bl_date column to original_docs table
ALTER TABLE public.original_docs ADD COLUMN IF NOT EXISTS bl_date date;

-- Add comment for clarity
COMMENT ON COLUMN public.original_docs.bl_date IS 'Bill of Lading Date';
