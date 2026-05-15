-- ============================================================================
-- FIX: Correct FOR loop syntax error in advance_stage function
-- ============================================================================

-- Fixed advance_stage function without the syntax error
CREATE OR REPLACE FUNCTION public.advance_stage(
    p_shipment_id uuid,
    p_to_stage public.stage,
    p_meta jsonb DEFAULT '{}'::jsonb
) RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_from_stage public.stage;
  v_user_id uuid;
BEGIN
  -- Enhanced logging
  RAISE NOTICE 'advance_stage called: shipment=%, to_stage=%, meta=%', p_shipment_id, p_to_stage, p_meta;
  
  -- Get current user (with fallback)
  BEGIN
    v_user_id := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_user_id := NULL;
  END;
  
  -- Lock the shipment row to prevent race conditions
  SELECT current_stage INTO v_from_stage
  FROM public.shipment
  WHERE id = p_shipment_id
  FOR UPDATE;

  IF v_from_stage IS NULL THEN
    RAISE EXCEPTION 'Shipment % not found', p_shipment_id;
  END IF;
  
  RAISE NOTICE 'Current stage: %, Target stage: %', v_from_stage, p_to_stage;

  -- Check if the transition is valid
  IF NOT EXISTS (
    SELECT 1 FROM public.stage_edge
    WHERE from_stage = v_from_stage AND to_stage = p_to_stage
  ) THEN
    RAISE EXCEPTION 'Invalid stage transition: % -> %', v_from_stage, p_to_stage;
  END IF;
  
  RAISE NOTICE 'Stage transition is valid';

  -- Check if the requirements for the new stage are met
  IF NOT public.stage_requirements_met(p_shipment_id, p_to_stage) THEN
    RAISE EXCEPTION 'Requirements not met for stage %', p_to_stage;
  END IF;
  
  RAISE NOTICE 'Stage requirements are met';

  -- Update the shipment stage (WITHOUT updated_at column)
  UPDATE public.shipment
  SET current_stage = p_to_stage
  WHERE id = p_shipment_id;
  
  RAISE NOTICE 'Shipment stage updated to %', p_to_stage;

  -- Insert a record into the audit log
  INSERT INTO public.audit_log(shipment_id, actor_id, action, from_stage, to_stage, meta, at)
  VALUES (p_shipment_id, v_user_id, 'advance_stage', v_from_stage, p_to_stage, p_meta, NOW());
  
  RAISE NOTICE 'Audit log entry created';
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'advance_stage error: %', SQLERRM;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.advance_stage(uuid, public.stage, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.advance_stage(uuid, public.stage, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.advance_stage(uuid, public.stage, jsonb) TO anon;

-- Fixed test block with correct FOR loop syntax
DO $$
DECLARE
    test_shipment_id uuid := 'fb6c3681-d213-40a3-998e-62fec92d0453';
    current_stage_val public.stage;
    next_stage_val public.stage;
    rec record;  -- Declare record variable properly
BEGIN
    -- Get current stage
    SELECT current_stage INTO current_stage_val
    FROM public.shipment
    WHERE id = test_shipment_id;
    
    -- Get next stage
    SELECT to_stage INTO next_stage_val
    FROM public.stage_edge
    WHERE from_stage = current_stage_val;
    
    RAISE NOTICE '=== TESTING ADVANCE_STAGE FIX ===';
    RAISE NOTICE 'Shipment: %', test_shipment_id;
    RAISE NOTICE 'Current stage: %', current_stage_val;
    RAISE NOTICE 'Next stage: %', next_stage_val;
    
    -- Test stage requirements first
    IF public.stage_requirements_met(test_shipment_id, next_stage_val) THEN
        RAISE NOTICE '✅ Requirements met for %', next_stage_val;
        
        -- Test advance_stage
        BEGIN
            PERFORM public.advance_stage(test_shipment_id, next_stage_val, '{"test_fix": true}'::jsonb);
            RAISE NOTICE '✅ advance_stage succeeded! Stage should now be %', next_stage_val;
            
            -- Verify the stage was actually updated
            SELECT current_stage INTO current_stage_val
            FROM public.shipment
            WHERE id = test_shipment_id;
            
            RAISE NOTICE 'Verified: Current stage is now %', current_stage_val;
            
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ advance_stage still failed: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE '❌ Requirements NOT met for %', next_stage_val;
        
        -- Check IP Number data specifically with correct FOR loop syntax
        IF next_stage_val = 'lc_opening' THEN
            RAISE NOTICE '🔍 Checking IP Number data for lc_opening requirements...';
            
            -- Fixed FOR loop with proper record declaration
            FOR rec IN 
                SELECT id, ip_number, ip_reference, file_url, created_at 
                FROM public.ip_number 
                WHERE shipment_id = test_shipment_id
            LOOP
                RAISE NOTICE 'IP Record: ID=%, IP Number=%, Reference=%, File URL=%, Created=%', 
                    rec.id, rec.ip_number, rec.ip_reference, rec.file_url, rec.created_at;
            END LOOP;
        END IF;
    END IF;
END $$;

-- Show that the function is now properly created
SELECT 'advance_stage function recreated successfully!' as status;