-- ========================================================================
-- Migration: Update stage enum to merge LC stages
-- Purpose: Merge 'lc_opening' and 'lc_shared_with_supplier' into single 'lc_opening' stage
-- Note: Documents stage will be handled as a separate UI feature, not a sequential stage
-- ========================================================================

-- IMPORTANT: This migration removes 'lc_shared_with_supplier' from the workflow
-- The 'lc_opening' stage will now handle both LC opening and sharing with supplier

-- Step 1: Update any shipments currently in 'lc_shared_with_supplier' to 'lc_opening'
-- This ensures no shipments are stuck in a stage that no longer exists
UPDATE public.shipment 
SET current_stage = 'lc_opening'::stage
WHERE current_stage = 'lc_shared_with_supplier'::stage;

-- Step 2: Update audit log to reflect the merge
INSERT INTO public.audit_log(shipment_id, actor_id, action, from_stage, to_stage, meta, at)
SELECT 
  id as shipment_id,
  NULL as actor_id,
  'stage_merge_migration' as action,
  'lc_shared_with_supplier'::stage as from_stage,
  'lc_opening'::stage as to_stage,
  jsonb_build_object(
    'migration', true, 
    'reason', 'Merged lc_opening and lc_shared_with_supplier stages',
    'migration_date', NOW()
  ) as meta,
  NOW() as at
FROM public.shipment
WHERE current_stage = 'lc_opening'::stage
AND id IN (
  SELECT DISTINCT shipment_id 
  FROM public.audit_log 
  WHERE to_stage = 'lc_shared_with_supplier'::stage
);

-- Step 3: Merge lc_share data into letter_of_credit table
-- Add lc_shared and lc_shared_date columns to letter_of_credit
ALTER TABLE public.letter_of_credit 
ADD COLUMN IF NOT EXISTS lc_shared boolean DEFAULT false;

ALTER TABLE public.letter_of_credit 
ADD COLUMN IF NOT EXISTS lc_shared_date date;

ALTER TABLE public.letter_of_credit 
ADD COLUMN IF NOT EXISTS lc_shared_notes text;

-- Migrate data from lc_share to letter_of_credit
UPDATE public.letter_of_credit lc
SET 
  lc_shared = COALESCE(ls.is_lc_shared, false),
  lc_shared_date = ls.shared_date,
  lc_shared_notes = ls.notes
FROM public.lc_share ls
WHERE lc.shipment_id = ls.shipment_id;

-- Add comments for clarity
COMMENT ON COLUMN public.letter_of_credit.lc_shared IS 'Indicates if LC has been shared with supplier';
COMMENT ON COLUMN public.letter_of_credit.lc_shared_date IS 'Date when LC was shared with supplier';
COMMENT ON COLUMN public.letter_of_credit.lc_shared_notes IS 'Notes related to LC sharing with supplier';

-- Step 4: Archive lc_share table (keep for reference, but rename)
-- Don't drop it immediately in case we need to rollback
ALTER TABLE IF EXISTS public.lc_share RENAME TO lc_share_archived;

-- Add archive timestamp
ALTER TABLE IF EXISTS public.lc_share_archived 
ADD COLUMN IF NOT EXISTS archived_at timestamp with time zone DEFAULT NOW();

COMMENT ON TABLE public.lc_share_archived IS 'ARCHIVED: Data merged into letter_of_credit table. Stage merged with lc_opening. Kept for rollback purposes.';

-- Migration completed
SELECT 
  'LC stages merged successfully. lc_shared_with_supplier removed from workflow.' as migration_status,
  COUNT(*) as affected_shipments
FROM public.shipment 
WHERE current_stage = 'lc_opening'::stage;
