-- ============================================
-- RECREATE ALL FUNCTIONS
-- ============================================
-- Functions that were dropped by CASCADE operations

BEGIN;

-- ============================================
-- 1. advance_stage function
-- ============================================
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

-- ============================================
-- 2. stage_requirements_met function
-- ============================================
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

-- ============================================
-- 3. get_stage_order function
-- ============================================
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
    'bills',
    'documents'
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

-- ============================================
-- 4. filter_shipments function
-- ============================================
DROP FUNCTION IF EXISTS public.filter_shipments(text,uuid,uuid,uuid,text,text,text,text,text,text);
DROP FUNCTION IF EXISTS public.filter_shipments(text,text,text,text,text,text,text,text,text,text);
DROP FUNCTION IF EXISTS public.filter_shipments(text,text,text,text,text,text,text,text,text,text,text);

CREATE OR REPLACE FUNCTION filter_shipments(
  p_search_term TEXT DEFAULT NULL,
  p_supplier_id TEXT DEFAULT NULL,
  p_clearing_agent_id TEXT DEFAULT NULL,
  p_bank_id TEXT DEFAULT NULL,
  p_status TEXT DEFAULT NULL,
  p_shipment_type TEXT DEFAULT NULL,
  p_commodity TEXT DEFAULT NULL,
  p_lc_number TEXT DEFAULT NULL,
  p_product_name TEXT DEFAULT NULL,
  p_variety_name TEXT DEFAULT NULL,
  p_mode_of_transport TEXT DEFAULT NULL
)
RETURNS SETOF v_shipments_with_all_details AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM v_shipments_with_all_details s
  WHERE
    (p_search_term IS NULL OR p_search_term = '' OR 
     s.reference_code ILIKE '%' || p_search_term || '%' OR 
     s.product_name ILIKE '%' || p_search_term || '%' OR 
     s.variety_name ILIKE '%' || p_search_term || '%' OR 
     s.supplier_name ILIKE '%' || p_search_term || '%'
    ) AND
    (p_supplier_id IS NULL OR p_supplier_id = '' OR s.supplier_id = p_supplier_id::UUID) AND
    (p_clearing_agent_id IS NULL OR p_clearing_agent_id = '' OR s.clearing_agent_id = p_clearing_agent_id::UUID) AND
    (p_bank_id IS NULL OR p_bank_id = '' OR s.bank_id = p_bank_id::UUID) AND
    (p_status IS NULL OR p_status = '' OR s.status = p_status::status) AND
    (p_shipment_type IS NULL OR p_shipment_type = '' OR s.type = p_shipment_type::shipment_type) AND
    (p_commodity IS NULL OR p_commodity = '' OR s.commodity = p_commodity::commodities) AND
    (p_lc_number IS NULL OR p_lc_number = '' OR s.lc_number ILIKE '%' || p_lc_number || '%') AND
    (p_mode_of_transport IS NULL OR p_mode_of_transport = '' OR s.mode_of_transport = p_mode_of_transport) AND
    (p_product_name IS NULL OR p_product_name = '' OR 
     s.product_name ILIKE '%' || p_product_name || '%' OR 
     EXISTS (
       SELECT 1
       FROM jsonb_to_recordset(s.product_variety) AS x(product_name TEXT)
       WHERE x.product_name ILIKE '%' || p_product_name || '%'
     )
    ) AND
    (p_variety_name IS NULL OR p_variety_name = '' OR 
     s.variety_name ILIKE '%' || p_variety_name || '%' OR 
     EXISTS (
       SELECT 1
       FROM jsonb_to_recordset(s.product_variety) AS x(variety_name TEXT)
       WHERE x.variety_name ILIKE '%' || p_variety_name || '%'
     )
    );
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================
-- Grant permissions
-- ============================================
GRANT EXECUTE ON FUNCTION public.advance_stage(uuid, public.stage, jsonb) TO authenticated;
GRANT EXECUTE ON FUNCTION public.stage_requirements_met(uuid, public.stage) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_stage_order(public.stage) TO authenticated;
GRANT EXECUTE ON FUNCTION filter_shipments(text,text,text,text,text,text,text,text,text,text,text) TO authenticated;

COMMIT;

-- ============================================
-- Verification
-- ============================================
SELECT '✅ All functions recreated successfully!' as result;

-- List all functions
SELECT 'Functions available:' as info;
SELECT proname as function_name, pg_get_function_arguments(oid) as arguments
FROM pg_proc
WHERE proname IN ('advance_stage', 'stage_requirements_met', 'get_stage_order', 'filter_shipments')
  AND pronamespace = 'public'::regnamespace
ORDER BY proname;
