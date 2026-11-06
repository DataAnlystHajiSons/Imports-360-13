-- Migration: 24_search_relevance_case_insensitive.sql
-- Description: Update filter_shipments function to sort search results by case-insensitive relevance and created_at DESC

BEGIN;

DROP FUNCTION IF EXISTS public.filter_shipments(text,text,text,text,text,text,text,text,text,text,text);

CREATE OR REPLACE FUNCTION public.filter_shipments(
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
) RETURNS SETOF public.v_shipments_with_all_details AS $$
BEGIN 
  RETURN QUERY 
  SELECT * FROM public.v_shipments_with_all_details s 
  WHERE 
    (p_search_term IS NULL OR TRIM(p_search_term) = '' OR 
     s.reference_code ILIKE '%' || TRIM(p_search_term) || '%' OR 
     EXISTS (
       SELECT 1 
       FROM jsonb_to_recordset(s.product_variety) AS x(product_name TEXT, variety_name TEXT, supplier JSONB)
       WHERE x.product_name ILIKE '%' || TRIM(p_search_term) || '%' OR x.variety_name ILIKE '%' || TRIM(p_search_term) || '%' OR (x.supplier->>'name') ILIKE '%' || TRIM(p_search_term) || '%'
     )
    ) AND
    (p_supplier_id IS NULL OR p_supplier_id = '' OR EXISTS (
       SELECT 1 
       FROM jsonb_to_recordset(s.product_variety) AS x(supplier_id TEXT)
       WHERE x.supplier_id = p_supplier_id
    )) AND
    (p_clearing_agent_id IS NULL OR p_clearing_agent_id = '' OR s.clearing_agent_id::text = p_clearing_agent_id) AND
    (p_bank_id IS NULL OR p_bank_id = '' OR s.bank_id::text = p_bank_id) AND
    (p_status IS NULL OR p_status = '' OR s.status::text = p_status) AND
    (p_shipment_type IS NULL OR p_shipment_type = '' OR s.type::text = p_shipment_type) AND
    (p_commodity IS NULL OR p_commodity = '' OR EXISTS (
       SELECT 1 
       FROM jsonb_to_recordset(s.product_variety) AS x(commodity_name TEXT)
       WHERE x.commodity_name = p_commodity
    )) AND
    (p_lc_number IS NULL OR p_lc_number = '' OR s.lc_number ILIKE '%' || p_lc_number || '%') AND
    (p_product_name IS NULL OR p_product_name = '' OR EXISTS (
       SELECT 1 
       FROM jsonb_to_recordset(s.product_variety) AS x(product_name TEXT)
       WHERE x.product_name ILIKE '%' || p_product_name || '%'
    )) AND
    (p_variety_name IS NULL OR p_variety_name = '' OR EXISTS (
       SELECT 1 
       FROM jsonb_to_recordset(s.product_variety) AS x(variety_name TEXT)
       WHERE x.variety_name ILIKE '%' || p_variety_name || '%'
    )) AND
    (p_mode_of_transport IS NULL OR p_mode_of_transport = '' OR s.mode_of_transport::text = p_mode_of_transport)
  ORDER BY 
    CASE 
      WHEN p_search_term IS NULL OR TRIM(p_search_term) = '' THEN 100
      -- 1. Exact match on reference code (case-insensitive)
      WHEN LOWER(s.reference_code) = LOWER(TRIM(p_search_term)) THEN 1
      -- 2. Exact match on product name (case-insensitive)
      WHEN LOWER(s.product_name) = LOWER(TRIM(p_search_term)) THEN 2
      -- 3. Reference code starts with search term (case-insensitive)
      WHEN LOWER(s.reference_code) LIKE LOWER(TRIM(p_search_term)) || '%' THEN 3
      -- 4. Product name starts with search term (case-insensitive)
      WHEN LOWER(s.product_name) LIKE LOWER(TRIM(p_search_term)) || '%' THEN 4
      -- 5. Reference code contains search term
      WHEN LOWER(s.reference_code) LIKE '%' || LOWER(TRIM(p_search_term)) || '%' THEN 5
      -- 6. Product name contains search term
      WHEN LOWER(s.product_name) LIKE '%' || LOWER(TRIM(p_search_term)) || '%' THEN 6
      ELSE 7
    END ASC,
    s.created_at DESC;
END; $$ LANGUAGE plpgsql STABLE;

GRANT EXECUTE ON FUNCTION public.filter_shipments(text,text,text,text,text,text,text,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.filter_shipments(text,text,text,text,text,text,text,text,text,text,text) TO anon;

NOTIFY pgrst, 'reload schema';

COMMIT;
