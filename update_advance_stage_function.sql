
DROP FUNCTION IF EXISTS public.advance_stage(uuid, public.stage, jsonb);
DROP FUNCTION IF EXISTS public.advance_stage(uuid, public.stage);

CREATE OR REPLACE FUNCTION public.advance_stage(
  p_shipment_id uuid,
  p_to_stage public.stage,
  p_meta jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_from_stage public.stage;
BEGIN
  -- Lock the shipment row to prevent race conditions
  SELECT current_stage INTO v_from_stage
  FROM public.shipment
  WHERE id = p_shipment_id
  FOR UPDATE;

  -- Check if the transition is valid
  IF NOT EXISTS (
    SELECT 1 FROM public.stage_edge
    WHERE from_stage = v_from_stage AND to_stage = p_to_stage
  ) THEN
    RAISE EXCEPTION 'Invalid stage transition: % -> %', v_from_stage, p_to_stage;
  END IF;

  -- Check if the requirements for the new stage are met
  IF NOT public.stage_requirements_met(p_shipment_id, p_to_stage) THEN
    RAISE EXCEPTION 'Requirements not met for stage %', p_to_stage;
  END IF;

  -- Update the shipment stage
  UPDATE public.shipment
  SET current_stage = p_to_stage
  WHERE id = p_shipment_id;

  -- Insert a record into the audit log
  INSERT INTO public.audit_log(shipment_id, actor_id, action, from_stage, to_stage, meta)
  VALUES (p_shipment_id, auth.uid(), 'advance_stage', v_from_stage, p_to_stage, p_meta);
END;
$$;
