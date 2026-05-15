-- ============================================================================
-- Migration Script: Apply New Completion Logic to Existing Shipments
-- ============================================================================
-- This script retroactively applies the new completion logic to existing data
-- 
-- Logic: Mark shipment as 'completed' if:
--   1. current_stage = 'bills' (all stages completed)
--   2. costing.per_unit_rate > 0 (costing is finalized)
-- ============================================================================

-- ============================================================================
-- STEP 1: PRE-MIGRATION ANALYSIS
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'PRE-MIGRATION ANALYSIS';
    RAISE NOTICE '========================================';
END $$;

-- Check current shipment status distribution
SELECT 
    'Current Shipment Status Distribution' as analysis_type,
    status,
    COUNT(*) as count
FROM shipment
GROUP BY status
ORDER BY status;

-- Find shipments that SHOULD be completed based on new logic
SELECT 
    'Shipments That Should Be Completed (New Logic)' as analysis_type,
    COUNT(*) as count_should_be_completed
FROM shipment s
JOIN costing c ON c.shipment_id = s.id
WHERE s.current_stage = 'bills'
  AND c.per_unit_rate > 0
  AND s.status != 'completed';

-- Find shipments currently marked as completed (for comparison)
SELECT 
    'Shipments Currently Marked as Completed' as analysis_type,
    COUNT(*) as count_currently_completed
FROM shipment
WHERE status = 'completed';

-- Detailed list of shipments to be updated
SELECT 
    'DETAILED LIST: Shipments to be updated' as info,
    s.id,
    s.reference_code,
    s.current_stage,
    s.status as current_status,
    c.per_unit_rate,
    c.total_cost,
    c.qty,
    c.created_at as costing_created_at
FROM shipment s
JOIN costing c ON c.shipment_id = s.id
WHERE s.current_stage = 'bills'
  AND c.per_unit_rate > 0
  AND s.status != 'completed'
ORDER BY s.created_at DESC;

-- ============================================================================
-- STEP 2: CREATE BACKUP TABLE
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CREATING BACKUP TABLE';
    RAISE NOTICE '========================================';
END $$;

-- Drop backup table if it exists from previous run
DROP TABLE IF EXISTS shipment_status_migration_backup;

-- Create backup of ALL shipments before migration
CREATE TABLE shipment_status_migration_backup AS
SELECT 
    id,
    reference_code,
    current_stage,
    status,
    created_at,
    NOW() as backup_created_at
FROM shipment;

-- Verify backup was created
SELECT 
    'Backup Table Created' as info,
    COUNT(*) as total_records_backed_up
FROM shipment_status_migration_backup;

-- ============================================================================
-- STEP 3: DRY RUN - PREVIEW CHANGES
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'DRY RUN - PREVIEW OF CHANGES';
    RAISE NOTICE '========================================';
END $$;

-- Show what WOULD be updated (without actually updating)
WITH shipments_to_update AS (
    SELECT 
        s.id,
        s.reference_code,
        s.status as old_status,
        'completed' as new_status,
        c.per_unit_rate,
        c.total_cost
    FROM shipment s
    JOIN costing c ON c.shipment_id = s.id
    WHERE s.current_stage = 'bills'
      AND c.per_unit_rate > 0
      AND s.status != 'completed'
)
SELECT 
    'DRY RUN RESULTS' as info,
    COUNT(*) as shipments_will_be_updated,
    SUM(CASE WHEN old_status = 'active' THEN 1 ELSE 0 END) as from_active,
    SUM(CASE WHEN old_status = 'on_hold' THEN 1 ELSE 0 END) as from_on_hold,
    SUM(CASE WHEN old_status = 'cancelled' THEN 1 ELSE 0 END) as from_cancelled
FROM shipments_to_update;

-- ============================================================================
-- STEP 4: PERFORM MIGRATION
-- ============================================================================

DO $$
DECLARE
    v_updated_count INTEGER;
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'PERFORMING MIGRATION';
    RAISE NOTICE '========================================';
    
    -- Update shipments that meet the criteria
    WITH updated_shipments AS (
        UPDATE shipment s
        SET status = 'completed'
        FROM costing c
        WHERE s.id = c.shipment_id
          AND s.current_stage = 'bills'
          AND c.per_unit_rate > 0
          AND s.status != 'completed'
        RETURNING s.id, s.reference_code, c.per_unit_rate
    )
    SELECT COUNT(*) INTO v_updated_count FROM updated_shipments;
    
    RAISE NOTICE 'Migration completed. Updated % shipments to completed status.', v_updated_count;
END $$;

-- ============================================================================
-- STEP 5: POST-MIGRATION VERIFICATION
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'POST-MIGRATION VERIFICATION';
    RAISE NOTICE '========================================';
END $$;

-- Check new shipment status distribution
SELECT 
    'NEW Shipment Status Distribution' as analysis_type,
    status,
    COUNT(*) as count
FROM shipment
GROUP BY status
ORDER BY status;

-- Verify all shipments at bills stage with per_unit_rate > 0 are now completed
SELECT 
    'Verification: Should Be Zero' as check_type,
    COUNT(*) as remaining_should_be_completed
FROM shipment s
JOIN costing c ON c.shipment_id = s.id
WHERE s.current_stage = 'bills'
  AND c.per_unit_rate > 0
  AND s.status != 'completed';

-- Show changes made
SELECT 
    'Changes Made in Migration' as info,
    backup.reference_code,
    backup.status as old_status,
    current.status as new_status,
    backup.current_stage,
    c.per_unit_rate
FROM shipment_status_migration_backup backup
JOIN shipment current ON backup.id = current.id
JOIN costing c ON c.shipment_id = current.id
WHERE backup.status != current.status
ORDER BY backup.reference_code;

-- Summary of migration
SELECT 
    'MIGRATION SUMMARY' as summary,
    (SELECT COUNT(*) FROM shipment_status_migration_backup WHERE status = 'completed') as completed_before_migration,
    (SELECT COUNT(*) FROM shipment WHERE status = 'completed') as completed_after_migration,
    (SELECT COUNT(*) FROM shipment WHERE status = 'completed') - 
    (SELECT COUNT(*) FROM shipment_status_migration_backup WHERE status = 'completed') as newly_completed
FROM shipment
LIMIT 1;

-- ============================================================================
-- STEP 6: VALIDATION CHECKS
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'VALIDATION CHECKS';
    RAISE NOTICE '========================================';
END $$;

-- Check 1: Ensure no shipments were incorrectly marked as completed
SELECT 
    'VALIDATION CHECK 1: Incorrectly Completed Shipments (Should be 0)' as check,
    COUNT(*) as count
FROM shipment s
WHERE s.status = 'completed'
  AND (
    s.current_stage != 'bills' 
    OR NOT EXISTS (
        SELECT 1 FROM costing c 
        WHERE c.shipment_id = s.id 
        AND c.per_unit_rate > 0
    )
  );

-- Check 2: Ensure all eligible shipments are marked as completed
SELECT 
    'VALIDATION CHECK 2: Missing Completed Shipments (Should be 0)' as check,
    COUNT(*) as count
FROM shipment s
JOIN costing c ON c.shipment_id = s.id
WHERE s.current_stage = 'bills'
  AND c.per_unit_rate > 0
  AND s.status != 'completed';

-- Check 3: Verify no data loss
SELECT 
    'VALIDATION CHECK 3: Data Integrity (Counts Should Match)' as check,
    (SELECT COUNT(*) FROM shipment) as current_shipment_count,
    (SELECT COUNT(*) FROM shipment_status_migration_backup) as backup_shipment_count;

-- ============================================================================
-- STEP 7: FINAL REPORT
-- ============================================================================

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'MIGRATION COMPLETE';
    RAISE NOTICE '========================================';
    RAISE NOTICE 'Backup table: shipment_status_migration_backup';
    RAISE NOTICE 'To rollback: See rollback section below';
    RAISE NOTICE '========================================';
END $$;

-- ============================================================================
-- ROLLBACK INSTRUCTIONS (RUN ONLY IF NEEDED)
-- ============================================================================

/*
-- UNCOMMENT AND RUN THIS SECTION ONLY IF YOU NEED TO ROLLBACK THE MIGRATION

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'ROLLING BACK MIGRATION';
    RAISE NOTICE '========================================';
END $$;

-- Restore original statuses from backup
UPDATE shipment s
SET status = backup.status
FROM shipment_status_migration_backup backup
WHERE s.id = backup.id
  AND s.status != backup.status;

-- Verify rollback
SELECT 
    'Rollback Complete' as info,
    COUNT(*) as shipments_restored
FROM shipment s
JOIN shipment_status_migration_backup backup ON s.id = backup.id
WHERE s.status = backup.status;

RAISE NOTICE 'Rollback completed successfully';

*/

-- ============================================================================
-- CLEANUP (RUN AFTER CONFIRMING MIGRATION IS SUCCESSFUL)
-- ============================================================================

/*
-- UNCOMMENT AND RUN THIS AFTER VERIFYING MIGRATION IS SUCCESSFUL
-- This removes the backup table to free up space

DO $$
BEGIN
    RAISE NOTICE '========================================';
    RAISE NOTICE 'CLEANING UP BACKUP TABLE';
    RAISE NOTICE '========================================';
END $$;

DROP TABLE IF EXISTS shipment_status_migration_backup;

SELECT 'Backup table dropped successfully' as info;

*/
