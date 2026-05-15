-- ============================================================================
-- FIX: advance_stage 400 Error - Complete Function Recreation
-- ============================================================================
-- The 400 error suggests the advance_stage function has an issue
-- Let's recreate it with proper error handling

-- First, check if the function exists
SELECT 'Current advance_stage function:' as info;
SELECT pg_get_functiondef(oid) as function_definition
FROM pg_proc 
WHERE proname = 'advance_stage'
LIMIT 1;

-- Recreate the advance_stage function with enhanced error handling
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
  v_current_user_id uuid;
BEGIN
  -- Enhanced logging for debugging
  RAISE NOTICE 'advance_stage called: shipment_id=%, to_stage=%, meta=%', p_shipment_id, p_to_stage, p_meta;
  
  -- Validate input parameters
  IF p_shipment_id IS NULL THEN
    RAISE EXCEPTION 'Shipment ID cannot be null';
  END IF;
  
  IF p_to_stage IS NULL THEN
    RAISE EXCEPTION 'Target stage cannot be null';
  END IF;
  
  -- Get current user (with fallback for service calls)
  BEGIN
    v_current_user_id := auth.uid();
    IF v_current_user_id IS NULL THEN
      -- Use a system user or the first admin user as fallback
      SELECT id INTO v_current_user_id FROM public.app_user WHERE role = 'admin' LIMIT 1;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Warning: Could not get current user, using NULL';
    v_current_user_id := NULL;
  END;
  
  -- Lock the shipment row to prevent race conditions
  SELECT current_stage INTO v_from_stage
  FROM public.shipment
  WHERE id = p_shipment_id
  FOR UPDATE;
  
  -- Check if shipment exists
  IF v_from_stage IS NULL THEN
    RAISE EXCEPTION 'Shipment with ID % not found', p_shipment_id;
  END IF;
  
  RAISE NOTICE 'Current stage: %, Target stage: %', v_from_stage, p_to_stage;
  
  -- Check if already at target stage
  IF v_from_stage = p_to_stage THEN
    RAISE NOTICE 'Shipment already at target stage %', p_to_stage;
    RETURN;
  END IF;
  
  -- Check if the transition is valid (stage edge exists)
  IF NOT EXISTS (
    SELECT 1 FROM public.stage_edge
    WHERE from_stage = v_from_stage AND to_stage = p_to_stage
  ) THEN
    RAISE EXCEPTION 'Invalid stage transition: % -> %', v_from_stage, p_to_stage;
  END IF;
  
  RAISE NOTICE 'Stage transition is valid: % -> %', v_from_stage, p_to_stage;
  
  -- Check if the requirements for the new stage are met
  IF NOT public.stage_requirements_met(p_shipment_id, p_to_stage) THEN
    RAISE EXCEPTION 'Requirements not met for stage %', p_to_stage;
  END IF;
  
  RAISE NOTICE 'Stage requirements are met for %', p_to_stage;
  
  -- Update the shipment stage
  UPDATE public.shipment
  SET current_stage = p_to_stage,
      updated_at = NOW()
  WHERE id = p_shipment_id;
  
  RAISE NOTICE 'Shipment stage updated to %', p_to_stage;
  
  -- Insert a record into the audit log
  INSERT INTO public.audit_log(shipment_id, actor_id, action, from_stage, to_stage, meta, at)
  VALUES (p_shipment_id, v_current_user_id, 'advance_stage', v_from_stage, p_to_stage, p_meta, NOW());
  
  RAISE NOTICE 'Audit log entry created';
  
EXCEPTION
  WHEN OTHERS THEN
    RAISE EXCEPTION 'Error in advance_stage: %', SQLERRM;
END;
$$;

-- Grant proper permissions
GRANT EXECUTE ON FUNCTION public.advance_stage(uuid, public.stage, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.advance_stage(uuid, public.stage, jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.advance_stage(uuid, public.stage, jsonb) TO anon;

-- Test the function with the problematic shipment
SELECT 'Testing advance_stage function:' as test_info;

DO $$
DECLARE
    test_shipment_id uuid := 'fb6c3681-d213-40a3-998e-62fec92d0453';
    current_stage_val public.stage;
    next_stage_val public.stage;
BEGIN
    -- Get current stage
    SELECT current_stage INTO current_stage_val
    FROM public.shipment
    WHERE id = test_shipment_id;
    
    -- Get next stage
    SELECT to_stage INTO next_stage_val
    FROM public.stage_edge
    WHERE from_stage = current_stage_val;
    
    RAISE NOTICE 'Testing advance_stage: % from % to %', test_shipment_id, current_stage_val, next_stage_val;
    
    -- Test the function call
    BEGIN
        PERFORM public.advance_stage(test_shipment_id, next_stage_val, '{"test": true}'::jsonb);
        RAISE NOTICE '✅ advance_stage test succeeded!';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '❌ advance_stage test failed: %', SQLERRM;
    END;
END $$;