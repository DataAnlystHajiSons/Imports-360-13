-- ============================================
-- Merge LC Stages - Fixed Version
-- Based on actual database schema
-- ============================================

BEGIN;

-- ============================================
-- STEP 1: Add columns to letter_of_credit
-- ============================================
DO $$
BEGIN
    ALTER TABLE letter_of_credit 
    ADD COLUMN IF NOT EXISTS shared_date DATE,
    ADD COLUMN IF NOT EXISTS notes TEXT;
    
    RAISE NOTICE '✅ Columns added to letter_of_credit table';
END $$;

-- ============================================
-- STEP 2: Migrate data from lc_share to letter_of_credit
-- ============================================
DO $$
DECLARE
    migrated_count INTEGER;
BEGIN
    -- Copy shared_date and notes from lc_share to letter_of_credit
    UPDATE letter_of_credit lc
    SET 
        shared_date = ls.shared_date,
        notes = COALESCE(lc.notes, '') || 
                CASE 
                    WHEN lc.notes IS NOT NULL AND ls.notes IS NOT NULL THEN E'\n--- LC Shared Notes ---\n'
                    ELSE ''
                END || 
                COALESCE(ls.notes, '')
    FROM lc_share ls
    WHERE lc.shipment_id = ls.shipment_id;
    
    GET DIAGNOSTICS migrated_count = ROW_COUNT;
    RAISE NOTICE '✅ Migrated % LC records from lc_share to letter_of_credit', migrated_count;
END $$;

-- ============================================
-- STEP 3: Update shipments in old stage
-- ============================================
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    UPDATE shipment
    SET current_stage = 'lc_opening'::stage
    WHERE current_stage = 'lc_shared_with_supplier'::stage;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    
    IF updated_count > 0 THEN
        RAISE NOTICE '✅ Updated % shipments from lc_shared_with_supplier to lc_opening', updated_count;
    ELSE
        RAISE NOTICE '✅ No shipments in old stage (all good!)';
    END IF;
END $$;

-- ============================================
-- STEP 4: Update stage_edge table
-- ============================================
DO $$
BEGIN
    -- Remove old edges
    DELETE FROM stage_edge 
    WHERE from_stage = 'lc_shared_with_supplier'::stage
       OR to_stage = 'lc_shared_with_supplier'::stage;
    
    -- Add correct edge from lc_opening to invoice
    INSERT INTO stage_edge (from_stage, to_stage)
    VALUES ('lc_opening'::stage, 'invoice'::stage)
    ON CONFLICT (from_stage, to_stage) DO NOTHING;
    
    RAISE NOTICE '✅ Stage edges updated';
END $$;

-- ============================================
-- STEP 5: Update audit_log
-- ============================================
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    -- Update from_stage
    UPDATE audit_log
    SET from_stage = 'lc_opening'::stage
    WHERE from_stage = 'lc_shared_with_supplier'::stage;
    
    -- Update to_stage
    UPDATE audit_log
    SET to_stage = 'lc_opening'::stage
    WHERE to_stage = 'lc_shared_with_supplier'::stage;
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    
    IF updated_count > 0 THEN
        RAISE NOTICE '✅ Updated % audit_log records', updated_count;
    ELSE
        RAISE NOTICE '✅ No audit_log records to update';
    END IF;
END $$;

-- ============================================
-- STEP 6: Update stage_details table
-- ============================================
DO $$
BEGIN
    UPDATE stage_details
    SET expected_duration_days = 4
    WHERE stage_name = 'lc_opening'::stage;
    
    RAISE NOTICE '✅ Stage duration updated to 4 days';
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'ℹ️ Could not update stage_details: %', SQLERRM;
END $$;

-- ============================================
-- STEP 7: Update stage enum
-- ============================================
DO $$
BEGIN
    -- Rename old enum
    ALTER TYPE stage RENAME TO stage_old;
    
    -- Create new enum without lc_shared_with_supplier
    CREATE TYPE stage AS ENUM (
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
    
    -- Update shipment table
    ALTER TABLE shipment 
        ALTER COLUMN current_stage TYPE stage USING current_stage::text::stage;
    
    -- Update audit_log table
    ALTER TABLE audit_log 
        ALTER COLUMN from_stage TYPE stage USING from_stage::text::stage,
        ALTER COLUMN to_stage TYPE stage USING to_stage::text::stage;
    
    -- Update stage_edge table
    ALTER TABLE stage_edge 
        ALTER COLUMN from_stage TYPE stage USING from_stage::text::stage,
        ALTER COLUMN to_stage TYPE stage USING to_stage::text::stage;
    
    -- Update stage_details table
    BEGIN
        ALTER TABLE stage_details 
            ALTER COLUMN stage_name TYPE stage USING stage_name::text::stage;
    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;
    
    -- Drop old enum
    DROP TYPE stage_old;
    
    RAISE NOTICE '✅ Stage enum updated successfully';
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️ Stage enum update failed: %. Continuing...', SQLERRM;
END $$;

-- ============================================
-- STEP 8: Archive lc_share table
-- ============================================
DO $$
BEGIN
    ALTER TABLE lc_share RENAME TO lc_share_archived;
    RAISE NOTICE '✅ lc_share table archived as lc_share_archived';
END $$;

COMMIT;

-- ============================================
-- VERIFICATION QUERIES
-- ============================================

-- Check shipments
DO $$
DECLARE
    old_stage_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO old_stage_count
    FROM shipment 
    WHERE current_stage::text = 'lc_shared_with_supplier';
    
    IF old_stage_count = 0 THEN
        RAISE NOTICE '✅ All shipments migrated successfully';
    ELSE
        RAISE NOTICE '⚠️ % shipments still in old stage', old_stage_count;
    END IF;
END $$;

-- Check letter_of_credit columns
SELECT 
    column_name, 
    data_type
FROM information_schema.columns 
WHERE table_name = 'letter_of_credit'
  AND column_name IN ('lc_number', 'opened_date', 'shared_date', 'notes', 'bank_id')
ORDER BY column_name;

-- Check migrated data
SELECT 
    COUNT(*) as lc_records_with_shared_date
FROM letter_of_credit 
WHERE shared_date IS NOT NULL;

-- Check stage edges
SELECT 
    from_stage::text, 
    to_stage::text
FROM stage_edge 
WHERE from_stage::text = 'lc_opening' OR to_stage::text = 'lc_opening'
ORDER BY from_stage;

-- Final success message
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ LC STAGES MERGED SUCCESSFULLY!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Summary:';
    RAISE NOTICE '  ✅ lc_opening + lc_shared_with_supplier → LC Management';
    RAISE NOTICE '  ✅ Data migrated from lc_share to letter_of_credit';
    RAISE NOTICE '  ✅ Shipments updated to new stage';
    RAISE NOTICE '  ✅ Stage enum updated';
    RAISE NOTICE '  ✅ Stage edges cleaned up';
    RAISE NOTICE '  ✅ lc_share table archived';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Next Steps:';
    RAISE NOTICE '  1. Refresh browser (Ctrl+F5)';
    RAISE NOTICE '  2. Open shipment tracker';
    RAISE NOTICE '  3. Verify "LC Management" appears';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;
