-- ============================================================================
-- DEBUG: advance_stage RPC 400 Error for IP Number Stage
-- ============================================================================

-- 1. Check if advance_stage function exists and is accessible
SELECT 'Checking advance_stage function:' as debug_section;
SELECT 
  proname,
  proargnames,
  pronargs,
  prorettype::regtype as return_type
FROM pg_proc 
WHERE proname = 'advance_stage';

-- 2. Test the specific shipment that's failing
SELECT 'Testing specific shipment:' as debug_section;

DO $$
DECLARE
    problem_shipment_id uuid := 'fb6c3681-d213-40a3-998e-62fec92d0453';
    current_stage_val public.stage;
    next_stage_val public.stage;
    ip_data_exists boolean;
    stage_req_result boolean;
BEGIN
    -- Get current stage
    SELECT current_stage INTO current_stage_val
    FROM public.shipment
    WHERE id = problem_shipment_id;
    
    RAISE NOTICE '=== DEBUGGING SHIPMENT: % ===', problem_shipment_id;
    RAISE NOTICE 'Current stage: %', current_stage_val;
    
    -- Get next stage from stage_edge
    SELECT to_stage INTO next_stage_val
    FROM public.stage_edge
    WHERE from_stage = current_stage_val;
    
    RAISE NOTICE 'Next stage from stage_edge: %', next_stage_val;
    
    -- Check if IP Number data exists with file_url
    SELECT EXISTS(
        SELECT 1 FROM public.ip_number ip
        WHERE ip.shipment_id = problem_shipment_id AND ip.file_url IS NOT NULL
    ) INTO ip_data_exists;
    
    RAISE NOTICE 'IP Number data with file_url exists: %', ip_data_exists;
    
    -- Test stage requirements
    BEGIN
        SELECT public.stage_requirements_met(problem_shipment_id, next_stage_val) INTO stage_req_result;
        RAISE NOTICE 'stage_requirements_met result: %', stage_req_result;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'ERROR in stage_requirements_met: %', SQLERRM;
    END;
    
    -- Test advance_stage function call
    BEGIN
        RAISE NOTICE 'Testing advance_stage function call...';
        PERFORM public.advance_stage(
            problem_shipment_id, 
            next_stage_val, 
            '{"manual": true}'::jsonb
        );
        RAISE NOTICE '✅ advance_stage call succeeded!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ advance_stage call failed with error: %', SQLERRM;
        
        -- Additional debugging for the specific error
        IF SQLERRM LIKE '%Requirements not met%' THEN
            RAISE NOTICE '🔍 This is a requirements validation error';
            RAISE NOTICE '🔍 Checking IP Number table data...';
            
            -- Show IP Number record details
            FOR rec IN 
                SELECT * FROM public.ip_number WHERE shipment_id = problem_shipment_id
            LOOP
                RAISE NOTICE 'IP Record - ID: %, IP Number: %, Reference: %, File URL: %', 
                    rec.id, rec.ip_number, rec.ip_reference, rec.file_url;
            END LOOP;
        END IF;
    END;
END $$;

-- 3. Check stage_edge table for ip_number transitions
SELECT 'Stage transitions for ip_number:' as debug_section;
SELECT from_stage, to_stage 
FROM public.stage_edge 
WHERE from_stage = 'ip_number' OR to_stage = 'ip_number';

-- 4. Verify the stage enum values
SELECT 'Valid stage enum values:' as debug_section;
SELECT enumlabel as stage_name
FROM pg_enum 
WHERE enumtypid = (SELECT oid FROM pg_type WHERE typname = 'stage')
ORDER BY enumsortorder;

-- 5. Check function permissions
SELECT 'Function permissions:' as debug_section;
SELECT 
  routine_name,
  grantee,
  privilege_type
FROM information_schema.routine_privileges 
WHERE routine_name = 'advance_stage'
AND routine_schema = 'public';

-- 6. Test if the issue is with the function parameters
SELECT 'Testing function parameter types:' as debug_section;

DO $$
BEGIN
    -- Test if the issue is with UUID parameter
    IF NOT EXISTS(SELECT 1 FROM public.shipment WHERE id = 'fb6c3681-d213-40a3-998e-62fec92d0453') THEN
        RAISE NOTICE '❌ Shipment ID does not exist in database!';
    ELSE
        RAISE NOTICE '✅ Shipment ID exists in database';
    END IF;
    
    -- Test if lc_opening is a valid stage enum value
    BEGIN
        PERFORM 'lc_opening'::public.stage;
        RAISE NOTICE '✅ lc_opening is a valid stage enum value';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ lc_opening is NOT a valid stage enum value: %', SQLERRM;
    END;
END $$;