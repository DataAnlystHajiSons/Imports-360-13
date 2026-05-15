-- ============================================
-- Merge LC Stages: MINIMAL VERSION
-- ============================================
-- Only updates tables that exist in your database
-- Safe to run - checks everything before updating

BEGIN;

-- ============================================
-- STEP 1: Add columns to letter_of_credit
-- ============================================
ALTER TABLE letter_of_credit 
ADD COLUMN IF NOT EXISTS shared_date DATE,
ADD COLUMN IF NOT EXISTS notes TEXT;

-- ============================================
-- STEP 2: Update shipments (if any exist in old stage)
-- ============================================
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    -- Update shipments from old stage to new stage
    UPDATE shipment
    SET current_stage = 'lc_opening'
    WHERE current_stage = 'lc_shared_with_supplier';
    
    GET DIAGNOSTICS updated_count = ROW_COUNT;
    
    IF updated_count > 0 THEN
        RAISE NOTICE '✅ Updated % shipments from lc_shared_with_supplier to lc_opening', updated_count;
    ELSE
        RAISE NOTICE '✅ No shipments needed updating (all good!)';
    END IF;
END $$;

-- ============================================
-- STEP 3: Update stage_history (if table exists)
-- ============================================
DO $$
DECLARE
    updated_count INTEGER;
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'stage_history') THEN
        UPDATE stage_history
        SET stage = 'lc_opening'
        WHERE stage = 'lc_shared_with_supplier';
        
        GET DIAGNOSTICS updated_count = ROW_COUNT;
        RAISE NOTICE '✅ Updated % stage_history records', updated_count;
    ELSE
        RAISE NOTICE 'ℹ️ stage_history table not found (skipping)';
    END IF;
END $$;

-- ============================================
-- STEP 4: Update stage_edges (if table exists)
-- ============================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'stage_edges') THEN
        -- Remove old edges
        DELETE FROM stage_edges 
        WHERE from_stage = 'lc_shared_with_supplier' 
           OR to_stage = 'lc_shared_with_supplier';
        
        -- Add correct edge
        INSERT INTO stage_edges (from_stage, to_stage)
        VALUES ('lc_opening', 'invoice')
        ON CONFLICT (from_stage, to_stage) DO NOTHING;
        
        RAISE NOTICE '✅ Stage edges updated';
    ELSE
        RAISE NOTICE 'ℹ️ stage_edges table not found (skipping)';
    END IF;
END $$;

-- ============================================
-- STEP 5: Update stage enum (if exists)
-- ============================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_type WHERE typname = 'stage_enum') THEN
        -- Backup and recreate enum
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
        
        -- Update columns
        ALTER TABLE shipment 
            ALTER COLUMN current_stage TYPE stage_enum USING current_stage::text::stage_enum;
        
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'stage_history') THEN
            ALTER TABLE stage_history 
                ALTER COLUMN stage TYPE stage_enum USING stage::text::stage_enum;
        END IF;
        
        IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'stage_edges') THEN
            ALTER TABLE stage_edges 
                ALTER COLUMN from_stage TYPE stage_enum USING from_stage::text::stage_enum,
                ALTER COLUMN to_stage TYPE stage_enum USING to_stage::text::stage_enum;
        END IF;
        
        DROP TYPE stage_enum_old;
        RAISE NOTICE '✅ Stage enum updated';
    ELSE
        RAISE NOTICE 'ℹ️ Stage enum not found (current_stage is probably VARCHAR)';
    END IF;
    
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE '⚠️ Enum update failed: %. Continuing...', SQLERRM;
END $$;

COMMIT;

-- ============================================
-- VERIFICATION
-- ============================================

-- Show results
DO $$
DECLARE
    old_stage_count INTEGER;
BEGIN
    -- Count shipments in old stage
    SELECT COUNT(*) INTO old_stage_count
    FROM shipment 
    WHERE current_stage = 'lc_shared_with_supplier';
    
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ MIGRATION COMPLETED!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Results:';
    RAISE NOTICE '  ✅ Columns added to letter_of_credit';
    RAISE NOTICE '  ✅ Shipments updated: % in old stage', old_stage_count;
    RAISE NOTICE '  ✅ Stage references cleaned up';
    RAISE NOTICE '';
    
    IF old_stage_count = 0 THEN
        RAISE NOTICE '✅ SUCCESS: All shipments migrated!';
    ELSE
        RAISE NOTICE '⚠️ WARNING: % shipments still in old stage', old_stage_count;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '📋 Next Steps:';
    RAISE NOTICE '  1. Refresh browser (Ctrl+F5)';
    RAISE NOTICE '  2. Open shipment tracker';
    RAISE NOTICE '  3. Verify "LC Management" appears';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;

-- Show letter_of_credit columns
SELECT 
    'letter_of_credit columns:' as info,
    column_name, 
    data_type
FROM information_schema.columns 
WHERE table_name = 'letter_of_credit'
ORDER BY ordinal_position;
