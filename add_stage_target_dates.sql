-- ============================================================================
-- Stage Target Date Management System
-- ============================================================================
-- This script adds functionality to assign target dates to shipment stages
-- and tracks alert status for email notifications
-- ============================================================================

BEGIN;

-- ============================================================================
-- STEP 1: Create shipment_stage_targets table
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.shipment_stage_targets (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shipment_id uuid NOT NULL,
  stage_name stage NOT NULL,
  target_date date NOT NULL,
  
  -- Alert tracking
  three_day_alert_sent boolean DEFAULT false,
  three_day_alert_sent_at timestamp with time zone,
  overdue_alert_sent boolean DEFAULT false,
  overdue_alert_sent_at timestamp with time zone,
  
  -- Metadata
  notes text,
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_at timestamp with time zone DEFAULT now(),
  updated_by uuid,
  
  CONSTRAINT shipment_stage_targets_pkey PRIMARY KEY (id),
  CONSTRAINT shipment_stage_targets_unique UNIQUE (shipment_id, stage_name),
  CONSTRAINT shipment_stage_targets_shipment_id_fkey 
    FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE,
  CONSTRAINT shipment_stage_targets_created_by_fkey 
    FOREIGN KEY (created_by) REFERENCES public.app_user(id),
  CONSTRAINT shipment_stage_targets_updated_by_fkey 
    FOREIGN KEY (updated_by) REFERENCES public.app_user(id)
);

-- Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_shipment_stage_targets_shipment 
  ON public.shipment_stage_targets(shipment_id);
CREATE INDEX IF NOT EXISTS idx_shipment_stage_targets_stage 
  ON public.shipment_stage_targets(stage_name);
CREATE INDEX IF NOT EXISTS idx_shipment_stage_targets_target_date 
  ON public.shipment_stage_targets(target_date);
CREATE INDEX IF NOT EXISTS idx_shipment_stage_targets_alerts 
  ON public.shipment_stage_targets(three_day_alert_sent, overdue_alert_sent);

COMMENT ON TABLE public.shipment_stage_targets IS 
  'Stores target dates for each stage of each shipment with alert tracking';
COMMENT ON COLUMN public.shipment_stage_targets.three_day_alert_sent IS 
  'Flag to track if 3-day warning email has been sent';
COMMENT ON COLUMN public.shipment_stage_targets.overdue_alert_sent IS 
  'Flag to track if overdue warning email has been sent';

-- ============================================================================
-- STEP 2: Create function to get shipments needing alerts
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_shipments_needing_alerts()
RETURNS TABLE (
  shipment_id uuid,
  shipment_reference text,
  stage_name stage,
  target_date date,
  current_stage stage,
  alert_type text,
  days_until_target integer,
  responsible_team text,
  stage_target_id uuid
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    s.id as shipment_id,
    s.reference_code as shipment_reference,
    sst.stage_name,
    sst.target_date,
    s.current_stage,
    CASE 
      WHEN sst.target_date < CURRENT_DATE AND NOT sst.overdue_alert_sent 
        THEN 'overdue'
      WHEN sst.target_date - CURRENT_DATE <= 3 
        AND sst.target_date >= CURRENT_DATE 
        AND NOT sst.three_day_alert_sent 
        THEN 'upcoming'
      ELSE NULL
    END as alert_type,
    (sst.target_date - CURRENT_DATE)::integer as days_until_target,
    COALESCE(sd.responsible_team, 'Operations Team') as responsible_team,
    sst.id as stage_target_id
  FROM public.shipment_stage_targets sst
  INNER JOIN public.shipment s ON sst.shipment_id = s.id
  LEFT JOIN public.stage_details sd ON sst.stage_name = sd.stage_name
  WHERE 
    s.status = 'active'
    AND (
      -- Need to send 3-day warning
      (sst.target_date - CURRENT_DATE <= 3 
       AND sst.target_date >= CURRENT_DATE 
       AND NOT sst.three_day_alert_sent)
      OR
      -- Need to send overdue warning
      (sst.target_date < CURRENT_DATE 
       AND NOT sst.overdue_alert_sent
       AND s.current_stage = sst.stage_name) -- Only send overdue if still on that stage
    )
  ORDER BY sst.target_date ASC;
END;
$$;

COMMENT ON FUNCTION public.get_shipments_needing_alerts() IS 
  'Returns shipments that need 3-day warning or overdue alerts for their stage target dates';

-- ============================================================================
-- STEP 3: Create function to mark alert as sent
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_stage_alert_sent(
  p_stage_target_id uuid,
  p_alert_type text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF p_alert_type = 'upcoming' THEN
    UPDATE public.shipment_stage_targets
    SET 
      three_day_alert_sent = true,
      three_day_alert_sent_at = now(),
      updated_at = now()
    WHERE id = p_stage_target_id;
  ELSIF p_alert_type = 'overdue' THEN
    UPDATE public.shipment_stage_targets
    SET 
      overdue_alert_sent = true,
      overdue_alert_sent_at = now(),
      updated_at = now()
    WHERE id = p_stage_target_id;
  END IF;
END;
$$;

COMMENT ON FUNCTION public.mark_stage_alert_sent(uuid, text) IS 
  'Marks a stage target alert as sent (either upcoming or overdue)';

-- ============================================================================
-- STEP 4: Create function to set/update stage target date
-- ============================================================================
CREATE OR REPLACE FUNCTION public.set_stage_target_date(
  p_shipment_id uuid,
  p_stage_name stage,
  p_target_date date,
  p_notes text DEFAULT NULL,
  p_user_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_target_id uuid;
BEGIN
  -- Insert or update the target date
  INSERT INTO public.shipment_stage_targets (
    shipment_id,
    stage_name,
    target_date,
    notes,
    created_by,
    updated_by
  )
  VALUES (
    p_shipment_id,
    p_stage_name,
    p_target_date,
    p_notes,
    COALESCE(p_user_id, auth.uid()),
    COALESCE(p_user_id, auth.uid())
  )
  ON CONFLICT (shipment_id, stage_name)
  DO UPDATE SET
    target_date = p_target_date,
    notes = COALESCE(p_notes, shipment_stage_targets.notes),
    -- Reset alert flags if date changed
    three_day_alert_sent = CASE 
      WHEN shipment_stage_targets.target_date != p_target_date 
      THEN false 
      ELSE shipment_stage_targets.three_day_alert_sent 
    END,
    overdue_alert_sent = CASE 
      WHEN shipment_stage_targets.target_date != p_target_date 
      THEN false 
      ELSE shipment_stage_targets.overdue_alert_sent 
    END,
    updated_by = COALESCE(p_user_id, auth.uid()),
    updated_at = now()
  RETURNING id INTO v_target_id;
  
  RETURN v_target_id;
END;
$$;

COMMENT ON FUNCTION public.set_stage_target_date(uuid, stage, date, text, uuid) IS 
  'Sets or updates the target date for a specific stage of a shipment';

-- ============================================================================
-- STEP 5: Create function to get target dates for a shipment
-- ============================================================================
CREATE OR REPLACE FUNCTION public.get_shipment_stage_targets(
  p_shipment_id uuid
)
RETURNS TABLE (
  id uuid,
  stage_name stage,
  stage_display_name text,
  target_date date,
  days_remaining integer,
  status text,
  responsible_team text,
  notes text,
  three_day_alert_sent boolean,
  overdue_alert_sent boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT 
    sst.id,
    sst.stage_name,
    INITCAP(REPLACE(sst.stage_name::text, '_', ' ')) as stage_display_name,
    sst.target_date,
    (sst.target_date - CURRENT_DATE)::integer as days_remaining,
    CASE 
      WHEN sst.target_date < CURRENT_DATE THEN 'overdue'
      WHEN sst.target_date - CURRENT_DATE <= 3 THEN 'warning'
      ELSE 'on_track'
    END as status,
    COALESCE(sd.responsible_team, 'Operations Team') as responsible_team,
    sst.notes,
    sst.three_day_alert_sent,
    sst.overdue_alert_sent
  FROM public.shipment_stage_targets sst
  LEFT JOIN public.stage_details sd ON sst.stage_name = sd.stage_name
  WHERE sst.shipment_id = p_shipment_id
  ORDER BY 
    CASE sst.stage_name
      WHEN 'forecast' THEN 1
      WHEN 'enlistment_verification' THEN 2
      WHEN 'availability_confirmation' THEN 3
      WHEN 'purchase_order' THEN 4
      WHEN 'proforma' THEN 5
      WHEN 'invoice' THEN 6
      WHEN 'ip_number' THEN 7
      WHEN 'lc_opening' THEN 8
      WHEN 'shipment_details_from_supplier' THEN 9
      WHEN 'freight_query' THEN 10
      WHEN 'award_shipment' THEN 11
      WHEN 'original_docs' THEN 12
      WHEN 'non_negotiable_docs' THEN 13
      WHEN 'bank_endorsement' THEN 14
      WHEN 'send_to_clearing_agent' THEN 15
      WHEN 'under_clearing_agent' THEN 16
      WHEN 'release_orders' THEN 17
      WHEN 'gate_out' THEN 18
      WHEN 'transportation' THEN 19
      WHEN 'warehouse' THEN 20
      WHEN 'documents' THEN 21
      WHEN 'bills' THEN 22
      ELSE 99
    END;
END;
$$;

COMMENT ON FUNCTION public.get_shipment_stage_targets(uuid) IS 
  'Returns all stage target dates for a specific shipment with status';

-- ============================================================================
-- STEP 6: Create function to delete a stage target
-- ============================================================================
CREATE OR REPLACE FUNCTION public.delete_stage_target_date(
  p_stage_target_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  DELETE FROM public.shipment_stage_targets
  WHERE id = p_stage_target_id;
  
  RETURN FOUND;
END;
$$;

COMMENT ON FUNCTION public.delete_stage_target_date(uuid) IS 
  'Deletes a stage target date entry';

-- ============================================================================
-- STEP 7: Grant necessary permissions
-- ============================================================================
-- Adjust these based on your RLS policies and user roles
GRANT SELECT, INSERT, UPDATE, DELETE ON public.shipment_stage_targets TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_shipments_needing_alerts() TO authenticated;
GRANT EXECUTE ON FUNCTION public.mark_stage_alert_sent(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_stage_target_date(uuid, stage, date, text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_shipment_stage_targets(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.delete_stage_target_date(uuid) TO authenticated;

-- Also grant to service role for edge functions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.shipment_stage_targets TO service_role;
GRANT EXECUTE ON FUNCTION public.get_shipments_needing_alerts() TO service_role;
GRANT EXECUTE ON FUNCTION public.mark_stage_alert_sent(uuid, text) TO service_role;

COMMIT;

-- ============================================================================
-- Success message
-- ============================================================================
DO $$
BEGIN
  RAISE NOTICE '✅ Stage target date management system created successfully';
  RAISE NOTICE '📋 Created table: shipment_stage_targets';
  RAISE NOTICE '⚙️  Created 5 helper functions for managing target dates and alerts';
  RAISE NOTICE '🔔 Next steps:';
  RAISE NOTICE '   1. Update UI to allow setting target dates';
  RAISE NOTICE '   2. Deploy the scheduled edge function for monitoring alerts';
  RAISE NOTICE '   3. Test the alert system';
END $$;
