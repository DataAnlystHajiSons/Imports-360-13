-- Add email column to warehouse table
ALTER TABLE public.warehouse ADD COLUMN IF NOT EXISTS email text;

-- Add comment for clarity
COMMENT ON COLUMN public.warehouse.email IS 'Contact email for the warehouse';
