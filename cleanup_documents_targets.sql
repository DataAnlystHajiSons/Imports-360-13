-- ============================================================================
-- Cleanup Script: Fix "documents" stage issue in target dates
-- ============================================================================
-- This script removes any invalid stage entries from shipment_stage_targets
-- The error "invalid input value for enum stage: documents" means there's
-- a row with a stage value that's not in the current stage enum
-- ============================================================================

BEGIN;

-- We need to temporarily allow deleting by converting the column to text
-- Step 1: Alter the column to text temporarily
ALTER TABLE public.shipment_stage_targets 
  ALTER COLUMN stage_name TYPE text;

-- Step 2: Delete any "documents" entries
DELETE FROM public.shipment_stage_targets
WHERE stage_name = 'documents';

-- Step 3: Show what's left
DO $$
DECLARE
  remaining_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO remaining_count FROM public.shipment_stage_targets;
  RAISE NOTICE '✅ Cleanup complete. Remaining target dates: %', remaining_count;
END $$;

-- Step 4: Convert the column back to the stage enum type
ALTER TABLE public.shipment_stage_targets 
  ALTER COLUMN stage_name TYPE stage USING stage_name::stage;

COMMIT;

-- ============================================================================
-- Verification Query
-- ============================================================================
-- Show all remaining target dates:
SELECT 
  id,
  shipment_id,
  stage_name::text as stage,
  target_date,
  created_at
FROM public.shipment_stage_targets
ORDER BY created_at DESC
LIMIT 10;
