DROP FUNCTION IF EXISTS public.filter_shipments(text,uuid,uuid,uuid,text,text,text,text,text,text);
DROP FUNCTION IF EXISTS public.filter_shipments(text,text,text,text,text,text,text,text,text,text);

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
  p_variety_name TEXT DEFAULT NULL
)
RETURNS SETOF v_shipments_with_all_details AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM v_shipments_with_all_details s
  WHERE
    (p_search_term IS NULL OR p_search_term = '' OR s.reference_code ILIKE '%' || p_search_term || '%' OR s.product_name ILIKE '%' || p_search_term || '%' OR s.variety_name ILIKE '%' || p_search_term || '%' OR s.supplier_name ILIKE '%' || p_search_term || '%') AND
    (p_supplier_id IS NULL OR p_supplier_id = '' OR s.supplier_id = p_supplier_id::UUID) AND
    (p_clearing_agent_id IS NULL OR p_clearing_agent_id = '' OR s.clearing_agent_id = p_clearing_agent_id::UUID) AND
    (p_bank_id IS NULL OR p_bank_id = '' OR s.bank_id = p_bank_id::UUID) AND
    (p_status IS NULL OR p_status = '' OR s.status = p_status::status) AND
    (p_shipment_type IS NULL OR p_shipment_type = '' OR s.type = p_shipment_type::shipment_type) AND
    (p_commodity IS NULL OR p_commodity = '' OR s.commodity = p_commodity::commodities) AND
    (p_lc_number IS NULL OR p_lc_number = '' OR s.lc_number ILIKE '%' || p_lc_number || '%') AND
    (p_product_name IS NULL OR p_product_name = '' OR s.product_name ILIKE '%' || p_product_name || '%' OR EXISTS (
      SELECT 1
      FROM jsonb_to_recordset(s.product_variety) AS x(product_name TEXT)
      WHERE x.product_name ILIKE '%' || p_product_name || '%'
    )) AND
    (p_variety_name IS NULL OR p_variety_name = '' OR s.variety_name ILIKE '%' || p_variety_name || '%' OR EXISTS (
      SELECT 1
      FROM jsonb_to_recordset(s.product_variety) AS x(variety_name TEXT)
      WHERE x.variety_name ILIKE '%' || p_variety_name || '%'
    ));
END;
$$ LANGUAGE plpgsql;
