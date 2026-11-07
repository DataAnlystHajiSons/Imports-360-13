-- Migration: 28_add_pending_status_and_triggers.sql
-- Description:
-- 1. Ensure 'pending' exists in public.status enum
-- 2. Update advance_stage to automatically set status to 'pending' when entering 'bills' stage (unless completed or cancelled)
-- 3. Maintain trigger on costing to automatically set status to 'completed' once costing is finalized

BEGIN;

-- 1. Add 'pending' to status enum if not already present
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type t 
    JOIN pg_enum e ON t.oid = e.enumtypid 
    WHERE t.typname = 'status' AND e.enumlabel = 'pending'
  ) THEN
    ALTER TYPE public.status ADD VALUE IF NOT EXISTS 'pending';
  END IF;
END $$;

-- 2. Update advance_stage function to auto-mark status as pending when arriving at 'bills'
CREATE OR REPLACE FUNCTION public.advance_stage(
  p_shipment_id uuid,
  p_to_stage public.stage,
  p_meta jsonb DEFAULT NULL
) RETURNS void AS $$
DECLARE
  v_from_stage public.stage;
  v_current_status public.status;
BEGIN
  -- Lock the shipment row to prevent race conditions
  SELECT current_stage, status INTO v_from_stage, v_current_status
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

  -- Update the shipment stage and auto-mark pending if entering bills
  UPDATE public.shipment
  SET current_stage = p_to_stage,
      status = CASE
        WHEN p_to_stage = 'bills' AND v_current_status NOT IN ('completed', 'cancelled') THEN 'pending'::public.status
        ELSE status
      END
  WHERE id = p_shipment_id;

  -- Insert a record into the audit log
  INSERT INTO public.audit_log(shipment_id, actor_id, action, from_stage, to_stage, meta)
  VALUES (p_shipment_id, auth.uid(), 'advance_stage', v_from_stage, p_to_stage, p_meta);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Trigger function to mark shipment as completed when costing/bills is finished
CREATE OR REPLACE FUNCTION public.update_shipment_status_to_completed()
RETURNS TRIGGER AS $$
DECLARE
    v_current_stage public.stage;
BEGIN
    SELECT current_stage INTO v_current_stage
    FROM public.shipment
    WHERE id = NEW.shipment_id;

    -- Mark shipment as completed if:
    -- 1. per_unit_rate is greater than zero or final_payment is set
    -- 2. current_stage is 'bills'
    IF (NEW.per_unit_rate > 0 OR NEW.final_payment IS NOT NULL) AND v_current_stage = 'bills' THEN
        UPDATE public.shipment
        SET status = 'completed'::public.status
        WHERE id = NEW.shipment_id
        AND status != 'cancelled';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_costing_update_or_insert ON public.costing;

CREATE TRIGGER on_costing_update_or_insert
  AFTER INSERT OR UPDATE ON public.costing
  FOR EACH ROW 
  EXECUTE FUNCTION public.update_shipment_status_to_completed();

NOTIFY pgrst, 'reload schema';

COMMIT;
