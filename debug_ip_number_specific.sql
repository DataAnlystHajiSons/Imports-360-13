-- ============================================================================
-- SPECIFIC DEBUG: IP Number Stage Issue for shipment_tracker.html
-- ============================================================================

-- 1. Find the current shipment on IP Number stage that's having issues
SELECT 'Current Shipments on IP Number Stage:' as debug_section;
SELECT 
  s.id,
  s.reference_code,
  s.current_stage,
  ip.file_url,
  CASE 
    WHEN ip.file_url IS NOT NULL THEN '✅ File URL exists'
    ELSE '❌ File URL missing'
  END as file_status
FROM public.shipment s
LEFT JOIN public.ip_number ip ON s.id = ip.shipment_id
WHERE s.current_stage = 'ip_number'
ORDER BY s.created_at DESC
LIMIT 5;

-- 2. Test the exact stage_requirements_met function for a specific shipment
SELECT 'Testing stage_requirements_met function:' as debug_section;

DO $$
DECLARE
    test_shipment_id uuid;
    current_stage_val public.stage;
    ip_file_url text;
    stage_req_result boolean;
    next_stage_val public.stage;
BEGIN
    -- Get the first shipment on IP Number stage
    SELECT s.id, s.current_stage INTO test_shipment_id, current_stage_val
    FROM public.shipment s
    WHERE s.current_stage = 'ip_number'
    LIMIT 1;
    
    IF test_shipment_id IS NOT NULL THEN
        RAISE NOTICE '=== DEBUGGING SHIPMENT: % ===', test_shipment_id;
        RAISE NOTICE 'Current stage: %', current_stage_val;
        
        -- Check IP Number table data
        SELECT file_url INTO ip_file_url
        FROM public.ip_number
        WHERE shipment_id = test_shipment_id;
        
        RAISE NOTICE 'IP Number file_url: %', COALESCE(ip_file_url, 'NULL');
        
        -- Get next stage from stage_edge
        SELECT to_stage INTO next_stage_val
        FROM public.stage_edge
        WHERE from_stage = current_stage_val;
        
        RAISE NOTICE 'Next stage from stage_edge: %', next_stage_val;
        
        -- Test stage requirements function
        SELECT public.stage_requirements_met(test_shipment_id, next_stage_val) INTO stage_req_result;
        
        RAISE NOTICE 'stage_requirements_met result: %', stage_req_result;
        
        -- Manual check of what the function should return
        IF EXISTS(
            SELECT 1 FROM public.ip_number ip
            WHERE ip.shipment_id = test_shipment_id AND ip.file_url IS NOT NULL
        ) THEN
            RAISE NOTICE 'Manual check: IP Number with file_url EXISTS ✅';
        ELSE
            RAISE NOTICE 'Manual check: IP Number with file_url MISSING ❌';
        END IF;
        
        -- Show the complete IP Number record
        RAISE NOTICE '=== COMPLETE IP NUMBER RECORD ===';
        FOR rec IN 
            SELECT * FROM public.ip_number WHERE shipment_id = test_shipment_id
        LOOP
            RAISE NOTICE 'ID: %, Shipment ID: %, IP Number: %, File URL: %, Created: %', 
                rec.id, rec.shipment_id, rec.ip_number, rec.file_url, rec.created_at;
        END LOOP;
    ELSE
        RAISE NOTICE 'No shipments found on ip_number stage';
    END IF;
END $$;

-- 3. Check if there are any duplicate or conflicting records
SELECT 'Checking for duplicate IP Number records:' as debug_section;
SELECT 
  shipment_id,
  COUNT(*) as record_count,
  STRING_AGG(COALESCE(file_url, 'NULL'), ', ') as all_file_urls
FROM public.ip_number
GROUP BY shipment_id
HAVING COUNT(*) > 1;

-- 4. Show the exact stage_requirements_met function code for lc_opening
SELECT 'Current stage_requirements_met function for lc_opening:' as debug_section;
SELECT pg_get_functiondef(oid) as function_definition
FROM pg_proc 
WHERE proname = 'stage_requirements_met';

-- 5. Test direct advance_stage call (this is what the frontend is doing)
SELECT 'Testing direct advance_stage call:' as debug_section;

DO $$
DECLARE
    test_shipment_id uuid;
    current_stage_val public.stage;
    next_stage_val public.stage;
BEGIN
    -- Get the first shipment on IP Number stage
    SELECT s.id, s.current_stage INTO test_shipment_id, current_stage_val
    FROM public.shipment s
    WHERE s.current_stage = 'ip_number'
    LIMIT 1;
    
    IF test_shipment_id IS NOT NULL THEN
        -- Get next stage
        SELECT to_stage INTO next_stage_val
        FROM public.stage_edge
        WHERE from_stage = current_stage_val;
        
        RAISE NOTICE 'Attempting to advance shipment % from % to %', 
            test_shipment_id, current_stage_val, next_stage_val;
        
        -- This is the same call the frontend makes
        BEGIN
            PERFORM public.advance_stage(test_shipment_id, next_stage_val, '{"test": true}'::jsonb);
            RAISE NOTICE '✅ advance_stage call succeeded!';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ advance_stage call failed: %', SQLERRM;
        END;
    END IF;
END $$;