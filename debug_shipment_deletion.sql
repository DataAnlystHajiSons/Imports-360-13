-- Debug Script: Why Won't My Shipment Delete?
-- Run these queries one by one to diagnose the issue

-- ============================================
-- 1. CHECK IF SHIPMENT EXISTS
-- ============================================
SELECT 
  id, 
  reference_code, 
  status, 
  created_at
FROM shipment 
WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';

-- Expected: Should return 1 row with your test shipment


-- ============================================
-- 2. CHECK ALL RELATED RECORDS (What will be deleted)
-- ============================================
SELECT 'supplier_payments' as table_name, COUNT(*) as count FROM supplier_payments WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18'
UNION ALL
SELECT 'shipment_products', COUNT(*) FROM shipment_products WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18'
UNION ALL
SELECT 'shipment_stage_targets', COUNT(*) FROM shipment_stage_targets WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18'
UNION ALL
SELECT 'bank_communication', COUNT(*) FROM bank_communication WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18'
UNION ALL
SELECT 'document', COUNT(*) FROM document WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18'
UNION ALL
SELECT 'audit_log', COUNT(*) FROM audit_log WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18'
UNION ALL
SELECT 'costing', COUNT(*) FROM costing WHERE shipment_id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18'
ORDER BY count DESC;

-- Expected: Shows how many related records exist


-- ============================================
-- 3. CHECK FOR TRIGGERS ON SHIPMENT TABLE
-- ============================================
SELECT 
  trigger_name,
  event_manipulation as trigger_event,
  action_timing as when_fires,
  action_statement as what_it_does
FROM information_schema.triggers
WHERE event_object_table = 'shipment'
  AND trigger_schema = 'public'
ORDER BY trigger_name;

-- Expected: May show triggers that could prevent deletion


-- ============================================
-- 4. CHECK RLS (Row Level Security) POLICIES
-- ============================================
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd as command,
  qual as using_expression,
  with_check
FROM pg_policies
WHERE tablename = 'shipment'
  AND schemaname = 'public';

-- Expected: Shows RLS policies that might block deletion


-- ============================================
-- 5. CHECK YOUR CURRENT ROLE/PERMISSIONS
-- ============================================
SELECT 
  current_user as your_role,
  session_user,
  pg_has_role(current_user, 'postgres', 'MEMBER') as is_postgres_member,
  pg_has_role(current_user, 'authenticated', 'MEMBER') as is_authenticated;

-- Expected: Shows your current database role


-- ============================================
-- 6. TEST DELETE WITH VERBOSE OUTPUT
-- ============================================
DO $$
DECLARE
  shipment_exists BOOLEAN;
  delete_count INTEGER;
BEGIN
  -- Check if shipment exists
  SELECT EXISTS(
    SELECT 1 FROM shipment WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18'
  ) INTO shipment_exists;
  
  RAISE NOTICE '=== DELETE TEST ===';
  RAISE NOTICE 'Shipment exists: %', shipment_exists;
  
  IF shipment_exists THEN
    -- Try to delete
    DELETE FROM shipment 
    WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';
    
    GET DIAGNOSTICS delete_count = ROW_COUNT;
    
    RAISE NOTICE 'Rows deleted: %', delete_count;
    
    IF delete_count > 0 THEN
      RAISE NOTICE '✅ DELETE SUCCESSFUL!';
      ROLLBACK; -- Don't actually commit, just testing
    ELSE
      RAISE NOTICE '❌ DELETE FAILED - No rows affected';
    END IF;
  ELSE
    RAISE NOTICE '⚠️  Shipment does not exist';
  END IF;
  
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE '❌ ERROR: %', SQLERRM;
  RAISE NOTICE 'Error Detail: %', SQLSTATE;
END $$;


-- ============================================
-- 7. MANUAL DELETE ATTEMPT (Will show actual error)
-- ============================================
-- Uncomment and run this separately if you want to actually try deleting:

-- BEGIN;
-- DELETE FROM shipment WHERE id = '1ce68160-0f4e-4ac1-85c6-b6062f3b6a18';
-- SELECT 'Deleted successfully! (Transaction rolled back for safety)' as result;
-- ROLLBACK; -- Remove this line if you want to actually commit the delete


-- ============================================
-- 8. CHECK FOR CIRCULAR DEPENDENCIES
-- ============================================
WITH RECURSIVE fk_tree AS (
  -- Start with shipment table
  SELECT 
    'shipment'::text as base_table,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    rc.delete_rule,
    1 as depth
  FROM information_schema.table_constraints AS tc 
  JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
  JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
  JOIN information_schema.referential_constraints AS rc
    ON rc.constraint_name = tc.constraint_name
  WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND ccu.table_name = 'shipment'
  
  UNION ALL
  
  -- Find tables that reference the tables we found
  SELECT 
    ft.base_table,
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    rc.delete_rule,
    ft.depth + 1
  FROM fk_tree ft
  JOIN information_schema.table_constraints AS tc 
    ON tc.table_schema = 'public'
  JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
  JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
  JOIN information_schema.referential_constraints AS rc
    ON rc.constraint_name = tc.constraint_name
  WHERE tc.constraint_type = 'FOREIGN KEY' 
    AND ccu.table_name = ft.table_name
    AND ft.depth < 5  -- Prevent infinite recursion
)
SELECT DISTINCT
  table_name,
  foreign_table_name,
  delete_rule,
  depth,
  CASE 
    WHEN foreign_table_name = base_table THEN '⚠️  CIRCULAR REFERENCE!'
    ELSE '✅ OK'
  END as circular_check
FROM fk_tree
WHERE foreign_table_name = 'shipment'  -- Check for circular refs back to shipment
ORDER BY depth, table_name;

-- Expected: Should be empty (no circular dependencies)
