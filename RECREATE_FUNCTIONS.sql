-- Recreate functions that were dropped by CASCADE

-- 1. advance_stage function
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
  -- Get current user
  v_current_user_id := auth.uid();
  IF v_current_user_id IS NULL THEN
    SELECT id INTO v_current_user_id FROM public.app_user WHERE role = 'admin' LIMIT 1;
  END IF;
  
  -- Get current stage
  SELECT current_stage INTO v_from_stage
  FROM public.shipment
  WHERE id = p_shipment_id
  FOR UPDATE;
  
  IF v_from_stage IS NULL THEN
    RAISE EXCEPTION 'Shipment not found';
  END IF;
  
  IF v_from_stage = p_to_stage THEN
    RETURN;
  END IF;
  
  -- Check if transition is valid
  IF NOT EXISTS (
    SELECT 1 FROM public.stage_edge
    WHERE from_stage = v_from_stage AND to_stage = p_to_stage
  ) THEN
    RAISE EXCEPTION 'Invalid stage transition: % -> %', v_from_stage, p_to_stage;
  END IF;
  
  -- Check requirements
  IF NOT public.stage_requirements_met(p_shipment_id, p_to_stage) THEN
    RAISE EXCEPTION 'Requirements not met for stage %', p_to_stage;
  END IF;
  
  -- Update shipment
  UPDATE public.shipment
  SET current_stage = p_to_stage
  WHERE id = p_shipment_id;
  
  -- Audit log
  INSERT INTO public.audit_log(shipment_id, actor_id, action, from_stage, to_stage, meta)
  VALUES (p_shipment_id, v_current_user_id, 'advance_stage', v_from_stage, p_to_stage, p_meta);
END;
$$;

-- 2. stage_requirements_met function
CREATE OR REPLACE FUNCTION public.stage_requirements_met(
    p_shipment_id uuid,
    p_stage public.stage
) RETURNS boolean
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
  -- Simple check: always return true for now
  -- You can add specific requirements per stage later
  RETURN true;
END;
$$;

-- 3. get_stage_order function
CREATE OR REPLACE FUNCTION public.get_stage_order(
    p_stage public.stage
) RETURNS integer
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  stage_order text[] := ARRAY[
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
  ];
  i integer;
BEGIN
  FOR i IN 1..array_length(stage_order, 1) LOOP
    IF stage_order[i] = p_stage::text THEN
      RETURN i;
    END IF;
  END LOOP;
  RETURN NULL;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.advance_stage(uuid, public.stage, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stage_requirements_met(uuid, public.stage) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_stage_order(public.stage) TO authenticated;

SELECT 'SUCCESS! Functions recreated.' as result;
