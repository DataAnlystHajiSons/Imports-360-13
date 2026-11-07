-- Migration: 28_add_pending_status_and_triggers.sql
-- Description:
-- 1. Ensure 'pending' exists in public.status enum
-- 2. Drop and recreate advance_stage to return boolean and auto-mark status as 'pending' when entering 'bills' stage
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

-- 2. Drop existing advance_stage overloads first to prevent return type conflict (ERROR 42P13)
DROP FUNCTION IF EXISTS public.advance_stage(uuid, public.stage, jsonb) CASCADE;
DROP FUNCTION IF EXISTS public.advance_stage(uuid, public.stage) CASCADE;

-- 3. Recreate advance_stage function returning boolean
CREATE OR REPLACE FUNCTION public.advance_stage(
  p_shipment_id uuid,
  p_to_stage public.stage,
  p_meta jsonb DEFAULT '{}'::jsonb
)
RETURNS boolean AS $$
DECLARE
  v_from_stage public.stage;
  v_current_status public.status;
  v_user_id uuid;
BEGIN
  -- Get current stage and status
  SELECT current_stage, status INTO v_from_stage, v_current_status
  FROM public.shipment
  WHERE id = p_shipment_id;

  -- Get current user safely if running in Supabase context
  BEGIN
    v_user_id := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_user_id := NULL;
  END;

  -- Update shipment stage AND log latest activity AND auto-mark pending if entering bills
  UPDATE public.shipment
  SET current_stage = p_to_stage,
      latest_activity_stage = p_to_stage::text,
      latest_activity_at = NOW(),
      status = CASE
        WHEN p_to_stage = 'bills' AND v_current_status NOT IN ('completed', 'cancelled') THEN 'pending'::public.status
        ELSE status
      END
  WHERE id = p_shipment_id;

  -- Log in audit_log
  BEGIN
    INSERT INTO public.audit_log(shipment_id, actor_id, action, from_stage, to_stage, meta, at)
    VALUES (p_shipment_id, v_user_id, 'advance_stage', v_from_stage, p_to_stage, p_meta, NOW());
  EXCEPTION WHEN OTHERS THEN
    -- Fallback if audit_log column signature varies
    NULL;
  END;

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 4. Trigger function to mark shipment as completed when costing/bills is finished
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

-- 5. Permissions
GRANT EXECUTE ON FUNCTION public.advance_stage(uuid, public.stage, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.advance_stage(uuid, public.stage, jsonb) TO anon;
GRANT EXECUTE ON FUNCTION public.advance_stage(uuid, public.stage, jsonb) TO service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;
