CREATE OR REPLACE FUNCTION filter_shipments_v2(
  p_search_term TEXT,
  p_supplier_ids UUID[],
  p_clearing_agent_ids UUID[],
  p_bank_ids UUID[],
  p_status TEXT,
  p_commodity TEXT,
  p_lc_number TEXT,
  p_product_name TEXT,
  p_variety_name TEXT
)
RETURNS SETOF v_shipments_with_all_details AS $$
BEGIN
  RETURN QUERY
  SELECT *
  FROM v_shipments_with_all_details s
  WHERE
    (p_search_term IS NULL OR s.reference_code ILIKE '%' || p_search_term || '%' OR s.product_name ILIKE '%' || p_search_term || '%' OR s.variety_name ILIKE '%' || p_search_term || '%' OR s.supplier_name ILIKE '%' || p_search_term || '%') AND
    (p_supplier_ids IS NULL OR s.supplier_id = ANY(p_supplier_ids)) AND
    (p_clearing_agent_ids IS NULL OR s.clearing_agent_id = ANY(p_clearing_agent_ids)) AND
    (p_bank_ids IS NULL OR s.bank_id = ANY(p_bank_ids)) AND
    (p_status IS NULL OR s.status = p_status) AND
    (p_commodity IS NULL OR s.commodity = p_commodity) AND
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
