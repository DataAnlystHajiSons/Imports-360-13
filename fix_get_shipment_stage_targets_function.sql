-- ============================================================================
-- Fix: Update get_shipment_stage_targets function to remove "documents" stage
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
      WHEN 'bills' THEN 21
      ELSE 99
    END;
END;
$$;

COMMENT ON FUNCTION public.get_shipment_stage_targets(uuid) IS 
  'Returns all stage target dates for a specific shipment with status (documents stage excluded)';

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_shipment_stage_targets(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_shipment_stage_targets(uuid) TO service_role;

-- Test the function
SELECT * FROM public.get_shipment_stage_targets('8054b51e-da30-4e69-b609-3da8fe3e6646');
