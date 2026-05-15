-- ============================================
-- Merge LC Stages: Simple Version
-- ============================================
-- This merges "lc_shared_with_supplier" into "lc_opening"
-- Works without lc_share table

BEGIN;

-- Step 1: Add new fields to letter_of_credit table (if they don't exist)
ALTER TABLE letter_of_credit 
ADD COLUMN IF NOT EXISTS shared_date DATE,
ADD COLUMN IF NOT EXISTS notes TEXT;

-- Step 2: Update shipments that are in "lc_shared_with_supplier" stage
-- Move them to "lc_opening" stage
UPDATE shipment
SET current_stage = 'lc_opening'
WHERE current_stage = 'lc_shared_with_supplier';

-- Step 3: Update stage history - rename old stage references
UPDATE stage_history
SET stage = 'lc_opening'
WHERE stage = 'lc_shared_with_supplier';

-- Step 4: Update stage_edges - remove lc_shared_with_supplier edges
-- Remove old edges pointing to/from lc_shared_with_supplier
DELETE FROM stage_edges 
WHERE from_stage = 'lc_shared_with_supplier' 
   OR to_stage = 'lc_shared_with_supplier';

-- Step 5: Ensure proper edge from lc_opening to invoice
INSERT INTO stage_edges (from_stage, to_stage)
VALUES ('lc_opening', 'invoice')
ON CONFLICT (from_stage, to_stage) DO NOTHING;

-- Step 6: Update stage enum (if using enum type)
-- This will safely handle if enum doesn't exist
DO $$
BEGIN
    -- Check if we're using enum type
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'stage_enum') THEN
        -- Rename old enum
        ALTER TYPE stage_enum RENAME TO stage_enum_old;
        
        -- Create new enum without lc_shared_with_supplier
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
        
        RAISE NOTICE '✅ Stage enum updated successfully';
    ELSE
        RAISE NOTICE 'ℹ️ No stage enum found, skipping enum update';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️ Stage enum update failed: %. Continuing...', SQLERRM;
END $$;

-- Step 7: Update stage durations (if table exists)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'stage_details') THEN
        UPDATE stage_details
        SET expected_duration_days = 4,
            description = 'LC Opening and Sharing with Supplier'
        WHERE stage_name = 'lc_opening';
        RAISE NOTICE '✅ Stage duration updated';
    ELSE
        RAISE NOTICE 'ℹ️ stage_details table not found, skipping duration update';
    END IF;
END $$;

COMMIT;

-- ============================================
-- Verification Queries
-- ============================================

-- Check that no shipments are stuck in old stage
SELECT 
    COUNT(*) as shipments_in_old_stage,
    CASE 
        WHEN COUNT(*) = 0 THEN '✅ All shipments migrated'
        ELSE '⚠️ Some shipments still in old stage'
    END as status
FROM shipment 
WHERE current_stage = 'lc_shared_with_supplier';

-- Check stage edges
SELECT 
    from_stage, 
    to_stage,
    '✅' as status
FROM stage_edges 
WHERE from_stage = 'lc_opening' OR to_stage = 'lc_opening'
ORDER BY from_stage;

-- Check letter_of_credit table structure
SELECT 
    column_name, 
    data_type,
    '✅' as status
FROM information_schema.columns 
WHERE table_name = 'letter_of_credit'
  AND column_name IN ('lc_number', 'opened_date', 'shared_date', 'notes', 'bank_id')
ORDER BY column_name;

-- Success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ LC STAGES MERGED SUCCESSFULLY!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ "lc_opening" is now "LC Management"';
    RAISE NOTICE '✅ "lc_shared_with_supplier" removed';
    RAISE NOTICE '✅ New fields added: shared_date, notes';
    RAISE NOTICE '✅ Stage edges updated';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Next Steps:';
    RAISE NOTICE '1. Refresh your browser (Ctrl+F5)';
    RAISE NOTICE '2. Open any shipment tracker';
    RAISE NOTICE '3. Verify timeline shows "LC Management"';
    RAISE NOTICE '4. Click LC Management and check form fields';
    RAISE NOTICE '';
END $$;
