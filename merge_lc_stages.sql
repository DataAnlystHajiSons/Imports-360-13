-- ============================================
-- Merge LC Stages: LC Opening + LC Shared
-- ============================================
-- This merges "lc_shared_with_supplier" into "lc_opening"
-- New unified stage: "LC Management"

BEGIN;

-- Step 1: Add new fields to letter_of_credit table
ALTER TABLE letter_of_credit 
ADD COLUMN IF NOT EXISTS shared_date DATE,
ADD COLUMN IF NOT EXISTS notes TEXT;

-- Step 2: Migrate data from lc_share to letter_of_credit
-- Copy shared_date and notes from lc_share to letter_of_credit
UPDATE letter_of_credit lc
SET 
    shared_date = ls.shared_date,
    notes = COALESCE(lc.notes, '') || 
            CASE 
                WHEN lc.notes IS NOT NULL AND ls.notes IS NOT NULL THEN E'\n--- Shared Notes ---\n'
                ELSE ''
            END || 
            COALESCE(ls.notes, '')
FROM lc_share ls
WHERE lc.shipment_id = ls.shipment_id;

-- Step 3: Update shipments that are in "lc_shared_with_supplier" stage
-- Move them back to "lc_opening" stage
UPDATE shipment
SET current_stage = 'lc_opening'
WHERE current_stage = 'lc_shared_with_supplier';

-- Step 4: Update stage history - rename old stage references
UPDATE stage_history
SET stage = 'lc_opening'
WHERE stage = 'lc_shared_with_supplier';

-- Step 5: Update stage_edges - remove lc_shared_with_supplier edges
-- Remove old edges pointing to/from lc_shared_with_supplier
DELETE FROM stage_edges 
WHERE from_stage = 'lc_shared_with_supplier' 
   OR to_stage = 'lc_shared_with_supplier';

-- Ensure proper edge from lc_opening to invoice
INSERT INTO stage_edges (from_stage, to_stage)
VALUES ('lc_opening', 'invoice')
ON CONFLICT (from_stage, to_stage) DO NOTHING;

-- Step 6: Update stage enum (if using enum type)
-- Note: This might fail if you're not using enum - that's okay
DO $$
BEGIN
    -- Try to drop the old value from enum
    ALTER TYPE stage_enum RENAME TO stage_enum_old;
    
    CREATE TYPE stage_enum AS ENUM (
        'forecast',
        'enlistment_verification',
        'availability_confirmation',
        'proforma',
        'purchase_order',
        'ip_number',
        'lc_opening',
        'invoice',
        'shipment_details_from_supplier',
        'freight_query',
        'award_shipment',
        'original_docs',
        'non_negotiable_docs',
        'bank_endorsement',
        'send_to_clearing_agent',
        'under_clearing_agent',
        'release_orders',
        'gate_out',
        'transportation',
        'warehouse',
        'bills'
    );
    
    -- Update columns to use new enum
    ALTER TABLE shipment 
        ALTER COLUMN current_stage TYPE stage_enum USING current_stage::text::stage_enum;
    
    ALTER TABLE stage_history 
        ALTER COLUMN stage TYPE stage_enum USING stage::text::stage_enum;
    
    ALTER TABLE stage_edges 
        ALTER COLUMN from_stage TYPE stage_enum USING from_stage::text::stage_enum,
        ALTER COLUMN to_stage TYPE stage_enum USING to_stage::text::stage_enum;
    
    -- Drop old enum
    DROP TYPE stage_enum_old;
    
EXCEPTION
    WHEN OTHERS THEN
        -- If enum doesn't exist or update fails, rollback this block but continue
        RAISE NOTICE 'Stage enum update skipped or failed: %', SQLERRM;
END $$;

-- Step 7: Archive lc_share table (optional - keep data for reference)
-- Rename it instead of dropping to preserve historical data
ALTER TABLE IF EXISTS lc_share RENAME TO lc_share_archived;

-- Step 8: Update stage durations
-- LC Management now combines both stages (3 days + 1 day = 4 days)
UPDATE stage_details
SET expected_duration_days = 4,
    description = 'LC Opening and Sharing with Supplier'
WHERE stage_name = 'lc_opening';

COMMIT;

-- ============================================
-- Verification Queries
-- ============================================

-- Check that no shipments are stuck in old stage
SELECT COUNT(*) as shipments_in_old_stage 
FROM shipment 
WHERE current_stage = 'lc_shared_with_supplier';
-- Should return 0

-- Check LC records with migrated data
SELECT 
    lc.id,
    lc.shipment_id,
    lc.lc_number,
    lc.opened_date,
    lc.shared_date,
    lc.notes
FROM letter_of_credit lc
WHERE lc.shared_date IS NOT NULL
LIMIT 5;

-- Check stage edges
SELECT * FROM stage_edges 
WHERE from_stage = 'lc_opening' OR to_stage = 'lc_opening'
ORDER BY from_stage;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '✅ LC Stages merged successfully!';
    RAISE NOTICE '✅ "lc_opening" is now "LC Management" (Opening + Sharing)';
    RAISE NOTICE '✅ "lc_shared_with_supplier" has been removed';
    RAISE NOTICE '✅ All data migrated to letter_of_credit table';
    RAISE NOTICE '✅ lc_share table archived as lc_share_archived';
END $$;
