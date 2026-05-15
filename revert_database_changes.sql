-- This script reverts the database changes to their original state.

-- Step 1: Drop the view and any dependent functions.
DROP VIEW IF EXISTS public.v_shipments_with_all_details CASCADE;

-- Step 2: Recreate the view in its original state (from update_v_shipments_with_all_details_v2.sql)
CREATE OR REPLACE VIEW public.v_shipments_with_all_details AS
SELECT
    s.id,
    s.reference_code,
    s.current_stage,
    s.status,
    s.created_at,
    (SELECT pv.product_name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id WHERE sp.shipment_id = s.id LIMIT 1) as product_name,
    (SELECT pv.variety_name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id WHERE sp.shipment_id = s.id LIMIT 1) as variety_name,
    (SELECT pv.commodity FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id WHERE sp.shipment_id = s.id LIMIT 1) as commodity,
    (SELECT sup.id FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.supplier sup ON pv.supplier_id = sup.id WHERE sp.shipment_id = s.id LIMIT 1) as supplier_id,
    (SELECT sup.name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.supplier sup ON pv.supplier_id = sup.id WHERE sp.shipment_id = s.id LIMIT 1) AS supplier_name,
    ca.id as clearing_agent_id,
    ca.name as clearing_agent_name,
    b.id as bank_id,
    b.name as bank_name,
    lc.lc_number,
    (SELECT jsonb_agg(jsonb_build_object('product_name', pv.product_name, 'variety_name', pv.variety_name, 'supplier', jsonb_build_object('name', sup.name))) FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.supplier sup ON pv.supplier_id = sup.id WHERE sp.shipment_id = s.id) AS product_variety
FROM
    public.shipment s
LEFT JOIN
    public.letter_of_credit lc ON s.id = lc.shipment_id
LEFT JOIN
    public.bank b ON lc.bank_id = b.id
LEFT JOIN
    public.docs_to_clearing_agent dtca ON s.id = dtca.shipment_id
LEFT JOIN
    public.clearing_agent ca ON dtca.clearing_agent_id = ca.id;

-- Step 3: Recreate the filter function in its original state (from update_filter_shipments_function_v5.sql)
CREATE OR REPLACE FUNCTION filter_shipments(
  p_search_term TEXT DEFAULT NULL,
  p_supplier_id UUID DEFAULT NULL,
  p_clearing_agent_id UUID DEFAULT NULL,
  p_bank_id UUID DEFAULT NULL,
  p_status TEXT DEFAULT NULL,
  p_commodity TEXT DEFAULT NULL,
  p_lc_number TEXT DEFAULT NULL,
  p_product_name TEXT DEFAULT NULL,
  p_variety_name TEXT DEFAULT NULL
)
RETURNS SETOF v_shipments_with_all_details AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM v_shipments_with_all_details s
  WHERE
    (p_search_term IS NULL OR s.reference_code ILIKE '%' || p_search_term || '%' OR s.product_name ILIKE '%' || p_search_term || '%' OR s.variety_name ILIKE '%' || p_search_term || '%' OR s.supplier_name ILIKE '%' || p_search_term || '%') AND
    (p_supplier_id IS NULL OR s.supplier_id = p_supplier_id) AND
    (p_clearing_agent_id IS NULL OR s.clearing_agent_id = p_clearing_agent_id) AND
    (p_bank_id IS NULL OR s.bank_id = p_bank_id) AND
    (p_status IS NULL OR s.status = p_status::status) AND
    (p_commodity IS NULL OR s.commodity = p_commodity::commodities) AND
    (p_lc_number IS NULL OR s.lc_number ILIKE '%' || p_lc_number || '%') AND
    (p_product_name IS NULL OR s.product_name ILIKE '%' || p_product_name || '%' OR EXISTS (
      SELECT 1
      FROM jsonb_to_recordset(s.product_variety) AS x(product_name TEXT)
      WHERE x.product_name ILIKE '%' || p_product_name || '%'
    )) AND
    (p_variety_name IS NULL OR s.variety_name ILIKE '%' || p_variety_name || '%' OR EXISTS (
      SELECT 1
      FROM jsonb_to_recordset(s.product_variety) AS x(variety_name TEXT)
      WHERE x.variety_name ILIKE '%' || p_variety_name || '%'
    ));
END;
$$ LANGUAGE plpgsql;
