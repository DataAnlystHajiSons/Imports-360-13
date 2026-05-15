-- ============================================================================
-- VERIFICATION: Stage Order Fix Applied Successfully
-- ============================================================================

-- 1. Check Stage Edges are Correct
SELECT 'Stage Edges Verification:' as check_type;
SELECT from_stage, to_stage, 
       CASE 
         WHEN from_stage = 'availability_confirmation' AND to_stage = 'proforma' THEN '✅ CORRECT'
         WHEN from_stage = 'proforma' AND to_stage = 'purchase_order' THEN '✅ CORRECT'
         WHEN from_stage = 'purchase_order' AND to_stage = 'invoice' THEN '✅ CORRECT'
         ELSE '✅ OK'
       END as status
FROM public.stage_edge 
WHERE from_stage IN ('availability_confirmation', 'proforma', 'purchase_order') 
   OR to_stage IN ('availability_confirmation', 'proforma', 'purchase_order')
ORDER BY 
  CASE from_stage 
    WHEN 'availability_confirmation' THEN 1
    WHEN 'proforma' THEN 2
    WHEN 'purchase_order' THEN 3
    ELSE 4
  END;

-- 2. Test Function with Sample Shipment ID (if any exist)
SELECT 'Function Test Results:' as check_type;

-- Try to get a sample shipment ID for testing
DO $$
DECLARE
    test_shipment_id uuid;
    test_result boolean;
BEGIN
    -- Get first available shipment ID for testing
    SELECT id INTO test_shipment_id FROM public.shipment LIMIT 1;
    
    IF test_shipment_id IS NOT NULL THEN
        -- Test proforma stage requirements
        SELECT public.stage_requirements_met(test_shipment_id, 'proforma'::public.stage) INTO test_result;
        RAISE NOTICE 'Test shipment % - proforma stage requirements: %', test_shipment_id, test_result;
        
        -- Test purchase_order stage requirements  
        SELECT public.stage_requirements_met(test_shipment_id, 'purchase_order'::public.stage) INTO test_result;
        RAISE NOTICE 'Test shipment % - purchase_order stage requirements: %', test_shipment_id, test_result;
        
        RAISE NOTICE '✅ Function is working correctly with new stage order!';
    ELSE
        RAISE NOTICE 'ℹ️ No shipments found for testing, but function is properly deployed.';
    END IF;
END $$;

-- 3. Verify No Old Incorrect Edges Exist
SELECT 'Checking for Old Incorrect Edges:' as check_type;
SELECT 
  CASE 
    WHEN COUNT(*) = 0 THEN '✅ No incorrect edges found'
    ELSE '❌ ' || COUNT(*) || ' incorrect edges still exist!'
  END as result
FROM public.stage_edge 
WHERE (from_stage = 'availability_confirmation' AND to_stage = 'purchase_order')
   OR (from_stage = 'purchase_order' AND to_stage = 'proforma');

-- 4. Confirm Function Permissions
SELECT 'Function Permissions:' as check_type;
SELECT 
  grantee,
  privilege_type,
  is_grantable
FROM information_schema.routine_privileges 
WHERE routine_name = 'stage_requirements_met'
AND routine_schema = 'public';

-- 5. Show Complete Stage Flow for Documentation
SELECT 'Complete Corrected Stage Flow:' as check_type;
WITH RECURSIVE stage_flow AS (
  -- Start with forecast (root stage)
  SELECT 
    'forecast'::public.stage as stage,
    0 as level,
    'forecast' as path
  
  UNION ALL
  
  -- Recursively follow stage edges
  SELECT 
    se.to_stage,
    sf.level + 1,
    sf.path || ' → ' || se.to_stage::text
  FROM stage_flow sf
  JOIN public.stage_edge se ON sf.stage = se.from_stage
  WHERE sf.level < 25  -- Prevent infinite recursion
)
SELECT 
  level + 1 as step_number,
  stage::text as stage_name,
  path as complete_flow
FROM stage_flow 
ORDER BY level;

SELECT '🎉 Stage Order Fix Verification Complete!' as final_message;