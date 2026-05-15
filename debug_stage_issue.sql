-- ============================================================================
-- DEBUG: Stage Order Issue - IP Number trying to advance to LC Opening
-- ============================================================================

-- 1. Check current stage edges to see what's wrong
SELECT 'Current Stage Edges Around IP Number:' as debug_info;
SELECT from_stage, to_stage 
FROM public.stage_edge 
WHERE from_stage IN ('invoice', 'ip_number', 'lc_opening')
   OR to_stage IN ('invoice', 'ip_number', 'lc_opening')
ORDER BY 
  CASE from_stage 
    WHEN 'invoice' THEN 1
    WHEN 'ip_number' THEN 2
    WHEN 'lc_opening' THEN 3
    ELSE 4
  END;

-- 2. Check if there are any shipments stuck on IP Number stage
SELECT 'Shipments on IP Number Stage:' as debug_info;
SELECT id, reference_code, current_stage 
FROM public.shipment 
WHERE current_stage = 'ip_number'
LIMIT 5;

-- 3. Test stage requirements for IP Number to LC Opening transition
SELECT 'Testing IP Number Stage Requirements:' as debug_info;

-- Get a sample shipment on IP Number stage
DO $$
DECLARE
    test_shipment_id uuid;
    test_result boolean;
BEGIN
    -- Get first shipment on IP Number stage
    SELECT id INTO test_shipment_id FROM public.shipment WHERE current_stage = 'ip_number' LIMIT 1;
    
    IF test_shipment_id IS NOT NULL THEN
        -- Test what the stage_requirements_met function returns for lc_opening
        SELECT public.stage_requirements_met(test_shipment_id, 'lc_opening'::public.stage) INTO test_result;
        RAISE NOTICE 'Shipment % - Requirements for LC Opening stage: %', test_shipment_id, test_result;
        
        -- Check if IP Number data exists for this shipment
        IF EXISTS(SELECT 1 FROM public.ip_number WHERE shipment_id = test_shipment_id AND file_url IS NOT NULL) THEN
            RAISE NOTICE 'IP Number data EXISTS with file_url for shipment %', test_shipment_id;
        ELSE
            RAISE NOTICE 'IP Number data MISSING or no file_url for shipment %', test_shipment_id;
        END IF;
        
    ELSE
        RAISE NOTICE 'No shipments found on ip_number stage for testing';
    END IF;
END $$;

-- 4. Check what should be the correct next stage after IP Number
SELECT 'Expected Stage Flow:' as debug_info;
SELECT 
  'IP Number should advance to LC Opening' as expected_flow,
  'Frontend order: invoice → ip_number → lc_opening' as frontend_expectation,
  'Backend should match this order' as requirement;

-- 5. Verify IP Number table structure
SELECT 'IP Number Table Structure:' as debug_info;
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_name = 'ip_number' 
AND table_schema = 'public'
ORDER BY ordinal_position;