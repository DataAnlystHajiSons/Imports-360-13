-- Migration script for bank_debit_advice stage
-- 1. Add new columns
ALTER TABLE public.bank_debit_advice ADD COLUMN IF NOT EXISTS opening_da_amount numeric;
ALTER TABLE public.bank_debit_advice ADD COLUMN IF NOT EXISTS opening_da_date date;
ALTER TABLE public.bank_debit_advice ADD COLUMN IF NOT EXISTS amendment_da_amount numeric;
ALTER TABLE public.bank_debit_advice ADD COLUMN IF NOT EXISTS amendment_da_date date;

-- 2. Backfill opening_da_date from received_at if exists
UPDATE public.bank_debit_advice 
SET opening_da_date = received_at::date 
WHERE opening_da_date IS NULL AND received_at IS NOT NULL;

-- 3. Remove old columns (Optional: Keep for safety until confirmed, but user asked to remove)
ALTER TABLE public.bank_debit_advice DROP COLUMN IF EXISTS received_at;
ALTER TABLE public.bank_debit_advice DROP COLUMN IF EXISTS received_by;

-- Note: is_received is kept as a status indicator.
