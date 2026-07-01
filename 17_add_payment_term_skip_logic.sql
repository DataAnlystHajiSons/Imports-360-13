-- 17_add_payment_term_skip_logic.sql
-- This migration implements LC at Sight, Advance Payment, and CAD skip logic for Bank Endorsement.
-- It:
--   1. Updates stage_requirements_met validation function to auto-pass Bank Endorsement and adjust original_docs checks.
--   2. Updates v_shipments_with_all_details view to include pt.name AS payment_term_name and evaluate bank_endorsement as 1 (completed).
--   3. Recreates public.filter_shipments function.

BEGIN;

-- 1. Drop view and dependent functions first
DROP VIEW IF EXISTS public.v_shipments_with_all_details CASCADE;
DROP FUNCTION IF EXISTS public.stage_requirements_met(uuid, public.stage) CASCADE;

-- 2. Recreate stage_requirements_met with Payment Terms skip logic
CREATE OR REPLACE FUNCTION public.stage_requirements_met(p_shipment_id uuid, p_to_stage public.stage) RETURNS boolean
LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE 
  shipment_rec record; 
  has_seed_commodity boolean := FALSE; 
  seed_commodity_id uuid;
  v_inco_term text;
  v_payment_term_name text;
  v_current_year integer := EXTRACT(YEAR FROM CURRENT_DATE);
BEGIN
  SELECT s.*, pt.name as payment_term_name INTO shipment_rec 
  FROM public.shipment s
  LEFT JOIN public.payment_terms pt ON s.payment_term_id = pt.id
  WHERE s.id = p_shipment_id;
  
  IF NOT FOUND THEN RETURN FALSE; END IF;
  v_inco_term := shipment_rec.inco_term;
  v_payment_term_name := shipment_rec.payment_term_name;

  SELECT id INTO seed_commodity_id FROM public.commodity WHERE LOWER(name) = 'seed' LIMIT 1;
  IF seed_commodity_id IS NOT NULL THEN
    SELECT EXISTS (SELECT 1 FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id WHERE sp.shipment_id = p_shipment_id AND pv.commodity_id = seed_commodity_id) INTO has_seed_commodity;
  END IF;

  CASE p_to_stage
    WHEN 'forecast' THEN RETURN TRUE;
    WHEN 'enlistment_verification' THEN 
      IF NOT has_seed_commodity THEN RETURN TRUE; END IF;
      RETURN EXISTS (SELECT 1 FROM public.shipment_products sp JOIN public.forecast f ON f.product_variety_id = sp.product_variety_id WHERE sp.shipment_id = p_shipment_id AND f.year = v_current_year);
    WHEN 'availability_confirmation' THEN 
      IF NOT has_seed_commodity THEN RETURN TRUE; END IF;
      RETURN EXISTS (SELECT 1 FROM public.shipment_products sp JOIN public.forecast f ON f.product_variety_id = sp.product_variety_id WHERE sp.shipment_id = p_shipment_id AND f.enlistment_status = TRUE AND f.year = v_current_year);
    WHEN 'purchase_order' THEN 
      IF NOT has_seed_commodity THEN RETURN TRUE; END IF;
      RETURN EXISTS (SELECT 1 FROM public.availability_confirmation WHERE shipment_id = p_shipment_id AND available = TRUE);
    WHEN 'proforma' THEN RETURN EXISTS (SELECT 1 FROM public.purchase_order WHERE shipment_id = p_shipment_id AND po_file_url IS NOT NULL);
    WHEN 'ip_number' THEN RETURN EXISTS (SELECT 1 FROM public.proforma_invoice WHERE shipment_id = p_shipment_id AND file_url IS NOT NULL);
    WHEN 'lc_opening' THEN RETURN EXISTS (SELECT 1 FROM public.ip_number WHERE shipment_id = p_shipment_id AND file_url IS NOT NULL);
    WHEN 'bank_debit_advice' THEN RETURN EXISTS (SELECT 1 FROM public.letter_of_credit WHERE shipment_id = p_shipment_id AND file_url IS NOT NULL);
    WHEN 'invoice' THEN RETURN EXISTS (SELECT 1 FROM public.bank_debit_advice WHERE shipment_id = p_shipment_id AND is_received = true);
    WHEN 'shipment_details_from_supplier' THEN 
      IF v_inco_term = 'CFR' THEN RETURN TRUE; END IF;
      RETURN EXISTS (SELECT 1 FROM public.commercial_invoice WHERE shipment_id = p_shipment_id AND file_url IS NOT NULL);
    WHEN 'freight_query' THEN 
      IF v_inco_term IN ('CFR', 'CPT', 'CNF') THEN RETURN TRUE; END IF;
      RETURN EXISTS (SELECT 1 FROM public.supplier_shipment_details WHERE shipment_id = p_shipment_id);
    WHEN 'award_shipment' THEN 
      IF v_inco_term IN ('CFR', 'CPT', 'CNF') THEN RETURN TRUE; END IF;
      RETURN EXISTS (SELECT 1 FROM public.freight_query WHERE shipment_id = p_shipment_id);
    WHEN 'non_negotiable_docs' THEN 
      RETURN EXISTS (SELECT 1 FROM public.shipment_awarded sa WHERE sa.shipment_id = p_shipment_id AND sa.awarded = TRUE) OR v_inco_term IN ('CFR', 'CPT', 'CNF');
    WHEN 'bank_endorsement' THEN 
      IF v_payment_term_name IN ('LC at Sight', 'Advance Payment', 'CAD', 'Dp at Sight', 'DP at Sight') THEN RETURN TRUE; END IF;
      RETURN EXISTS (SELECT 1 FROM public.non_negotiable_docs WHERE shipment_id = p_shipment_id AND file_url IS NOT NULL);
    WHEN 'original_docs' THEN 
      IF v_payment_term_name IN ('LC at Sight', 'Advance Payment', 'CAD', 'Dp at Sight', 'DP at Sight') THEN
        RETURN EXISTS (SELECT 1 FROM public.non_negotiable_docs WHERE shipment_id = p_shipment_id AND file_url IS NOT NULL);
      END IF;
      RETURN EXISTS (SELECT 1 FROM public.bank_endorsement WHERE shipment_id = p_shipment_id AND endorsed = TRUE);
    WHEN 'send_to_clearing_agent' THEN RETURN EXISTS (SELECT 1 FROM public.original_docs WHERE shipment_id = p_shipment_id AND docs_url IS NOT NULL);
    WHEN 'good_declaration' THEN RETURN EXISTS (SELECT 1 FROM public.docs_to_clearing_agent WHERE shipment_id = p_shipment_id);
    WHEN 'under_clearing_agent' THEN RETURN EXISTS (SELECT 1 FROM public.good_declaration WHERE shipment_id = p_shipment_id AND gd_number IS NOT NULL);
    WHEN 'warehouse' THEN RETURN EXISTS (SELECT 1 FROM public.under_clearing_agent WHERE shipment_id = p_shipment_id AND is_received = TRUE);
    WHEN 'release_orders' THEN RETURN EXISTS (SELECT 1 FROM public.warehouse_arrival WHERE shipment_id = p_shipment_id);
    WHEN 'gate_out' THEN RETURN EXISTS (SELECT 1 FROM public.release_orders WHERE shipment_id = p_shipment_id);
    WHEN 'transportation' THEN RETURN EXISTS (SELECT 1 FROM public.gate_out go WHERE go.shipment_id = p_shipment_id AND go.is_gate_out = TRUE);
    WHEN 'documents' THEN RETURN TRUE; 
    WHEN 'bills' THEN RETURN TRUE; 
    ELSE RETURN FALSE;
  END CASE;
END; $$;


-- 3. Recreate the v_shipments_with_all_details view
CREATE OR REPLACE VIEW public.v_shipments_with_all_details AS
SELECT
    s.id,
    s.reference_code,
    s.current_stage,
    s.status,
    s.type,
    s.created_at,
    s.payment_term_id,
    pt.name AS payment_term_name,
    s.mode_of_transport,
    s.inco_term,
    s.freight_charges,
    s.created_by,
    s.latest_activity_stage,
    s.latest_activity_at,
    (SELECT pv.product_name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id WHERE sp.shipment_id = s.id LIMIT 1) as product_name,
    (SELECT pv.variety_name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id WHERE sp.shipment_id = s.id LIMIT 1) as variety_name,
    (SELECT sup.name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.supplier sup ON pv.supplier_id = sup.id WHERE sp.shipment_id = s.id LIMIT 1) AS supplier_name,
    
    -- letter of credit
    lc.id AS lc_id,
    lc.lc_number,
    lc.opened_date AS lc_opened_date,
    lc.lc_shared_date,
    lc.notes AS lc_notes,
    
    -- bank
    b.id AS bank_id,
    b.name AS bank_name,
    b.branch_name AS bank_branch,
    b.branch_address AS bank_address,
    
    -- documents view fkeys
    dtca.clearing_agent_id,
    ca.name AS clearing_agent_name,
    
    -- Calculate overall progress dynamically adapting to CPT, CFR, CNF and Payment Terms
    (
        (CASE WHEN EXISTS (SELECT 1 FROM public.forecast t JOIN public.shipment_products sp ON t.product_variety_id = sp.product_variety_id WHERE sp.shipment_id = s.id AND t.year IS NOT NULL AND t.forecast_qty IS NOT NULL AND t.date_of_sowing IS NOT NULL AND t.enlistment_status IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.enlistment_verification t WHERE t.shipment_id = s.id AND t.verified IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.availability_confirmation t WHERE t.shipment_id = s.id AND t.available IS NOT NULL AND t.supplier_id IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.purchase_order t WHERE t.shipment_id = s.id AND t.po_number IS NOT NULL AND t.po_number::text <> '' AND t.po_date IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.proforma_invoice t WHERE t.shipment_id = s.id AND t.proforma_number IS NOT NULL AND t.proforma_number::text <> '' AND t.proforma_date IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.ip_number t WHERE t.shipment_id = s.id AND t.issued_date IS NOT NULL AND t.references IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.letter_of_credit t WHERE t.shipment_id = s.id AND t.lc_number IS NOT NULL AND t.lc_number::text <> '' AND t.opened_date IS NOT NULL AND t.lc_shared_date IS NOT NULL AND t.bank_id IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.bank_debit_advice t WHERE t.shipment_id = s.id AND t.is_received IS NOT NULL AND t.opening_da_amount IS NOT NULL AND t.opening_da_date IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.commercial_invoice t WHERE t.shipment_id = s.id AND t.invoice_number IS NOT NULL AND t.invoice_number::text <> '' AND t.invoice_date IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN s.inco_term = 'CFR' OR EXISTS (SELECT 1 FROM public.supplier_shipment_details t WHERE t.shipment_id = s.id AND t.readiness_date IS NOT NULL AND t.address IS NOT NULL AND t.address::text <> '' AND t.origin IS NOT NULL AND t.origin::text <> '' AND t.transport IS NOT NULL AND t.inco_terms IS NOT NULL AND t.container_type IS NOT NULL AND t.cartons_count IS NOT NULL AND t.gross_weight IS NOT NULL AND t.net_weight IS NOT NULL AND t.length IS NOT NULL AND t.width IS NOT NULL AND t.height IS NOT NULL AND t.details_received_date IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN s.inco_term IN ('CFR', 'CPT', 'CNF') OR EXISTS (SELECT 1 FROM public.freight_query t WHERE t.shipment_id = s.id AND t.logistics_company_id IS NOT NULL AND t.term IS NOT NULL AND t.shipment_from IS NOT NULL AND t.shipment_from::text <> '' AND t.destination IS NOT NULL AND t.destination::text <> '' AND t.origin IS NOT NULL AND t.origin::text <> '' AND t.readiness_date IS NOT NULL AND t.gross_weight IS NOT NULL AND t.net_weight IS NOT NULL AND t.no_of_cartoons IS NOT NULL AND t.pick_up_address IS NOT NULL AND t.pick_up_address::text <> '') THEN 1 ELSE 0 END) +
        (CASE WHEN s.inco_term IN ('CFR', 'CPT', 'CNF') OR EXISTS (SELECT 1 FROM public.shipment_awarded t WHERE t.shipment_id = s.id AND t.awarded IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.non_negotiable_docs t WHERE t.shipment_id = s.id AND t.status IS NOT NULL AND t.bank_id IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN pt.name IN ('LC at Sight', 'Advance Payment', 'CAD', 'Dp at Sight', 'DP at Sight') OR EXISTS (SELECT 1 FROM public.bank_endorsement t WHERE t.shipment_id = s.id AND t.endorsed IS NOT NULL AND t.endorsed_at IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.original_docs t WHERE t.shipment_id = s.id AND t.status IS NOT NULL AND t.status::text <> '' AND t.bl_date IS NOT NULL AND t.shipping_company IS NOT NULL AND t.shipping_company::text <> '' AND t.tracking_number IS NOT NULL AND t.tracking_number::text <> '' AND t.shipping_guarantee_applied_date IS NOT NULL AND t.shipping_guarantee_received_date IS NOT NULL AND t.dispatch_date IS NOT NULL AND t.arrival_at_bank IS NOT NULL AND t.due_date IS NOT NULL AND t.payment_date IS NOT NULL AND t.bank_id IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.docs_to_clearing_agent t WHERE t.shipment_id = s.id AND t.name IS NOT NULL AND t.name::text <> '' AND t.shipping_company IS NOT NULL AND t.shipping_company::text <> '' AND t.tracking_number IS NOT NULL AND t.tracking_number::text <> '' AND t.expected_arrival_date IS NOT NULL AND t.clearing_agent_id IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.good_declaration t WHERE t.shipment_id = s.id AND t.gd_number IS NOT NULL AND t.gd_number::text <> '' AND t.gd_date IS NOT NULL AND t.gd_file_date IS NOT NULL AND t.clearing_agent_id IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.under_clearing_agent t WHERE t.shipment_id = s.id AND t.is_received IS NOT NULL AND t.receiving_date IS NOT NULL AND t.destuffed_date IS NOT NULL AND t.frsd_application_date IS NOT NULL AND t.duty_payment_date IS NOT NULL AND t.sampling_date IS NOT NULL AND t.do_date IS NOT NULL AND t.clearing_agent_id IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.warehouse_arrival t WHERE t.shipment_id = s.id AND t.warehouse_id IS NOT NULL AND t.arrival_date IS NOT NULL AND t.gr_no IS NOT NULL AND t.gr_no::text <> '') THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.release_orders t WHERE t.shipment_id = s.id AND t.dpp_ro_number IS NOT NULL AND t.dpp_ro_number::text <> '' AND t.dpp_date IS NOT NULL AND t.fscrd_ro_number IS NOT NULL AND t.fscrd_ro_number::text <> '' AND t.fscrd_date IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.gate_out t WHERE t.shipment_id = s.id AND t.is_gate_out IS NOT NULL AND t.gate_out_date IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.transporter t WHERE t.shipment_id = s.id AND t.transporter_name IS NOT NULL AND t.transporter_name::text <> '' AND t.bilti_number IS NOT NULL AND t.bilti_number::text <> '' AND t.bilti_date IS NOT NULL AND t.no_of_pieces IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.costing t WHERE t.shipment_id = s.id AND t.final_payment IS NOT NULL AND t.invoice_charges IS NOT NULL AND t.exchange_rate IS NOT NULL AND t.ip_charges IS NOT NULL AND t.bank_contract_opening_charges IS NOT NULL AND t.shipping_guarantee IS NOT NULL AND t.fbr_duty IS NOT NULL AND t.forwarder_charges IS NOT NULL AND t.clearing_charges IS NOT NULL AND t.local_transporter IS NOT NULL AND t.port_charges IS NOT NULL AND t.final_payment_charges IS NOT NULL AND t.total IS NOT NULL AND t.total_cost IS NOT NULL AND t.oh_perc IS NOT NULL AND t.qty IS NOT NULL AND t.per_unit_rate IS NOT NULL) THEN 1 ELSE 0 END)
    ) AS completed_milestones_count,
    
    23 AS total_milestones_count,
    
    -- product varieties
    (SELECT jsonb_agg(jsonb_build_object('product_name', pv.product_name, 'variety_name', pv.variety_name, 'supplier', jsonb_build_object('name', sup.name))) FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.supplier sup ON pv.supplier_id = sup.id WHERE sp.shipment_id = s.id) AS product_variety
FROM
    public.shipment s
LEFT JOIN
    public.payment_terms pt ON s.payment_term_id = pt.id
LEFT JOIN
    public.letter_of_credit lc ON s.id = lc.shipment_id
LEFT JOIN
    public.bank b ON lc.bank_id = b.id
LEFT JOIN
    public.docs_to_clearing_agent dtca ON s.id = dtca.shipment_id
LEFT JOIN
    public.clearing_agent ca ON dtca.clearing_agent_id = ca.id;


-- 4. Recreate filter_shipments function
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
    (p_search_term IS NULL OR p_search_term = '' OR 
     s.reference_code ILIKE '%' || p_search_term || '%' OR 
     EXISTS (
       SELECT 1 
       FROM jsonb_to_recordset(s.product_variety) AS x(product_name TEXT, variety_name TEXT, supplier JSONB)
       WHERE x.product_name ILIKE '%' || p_search_term || '%' OR x.variety_name ILIKE '%' || p_search_term || '%' OR (x.supplier->>'name') ILIKE '%' || p_search_term || '%'
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
    (p_mode_of_transport IS NULL OR p_mode_of_transport = '' OR s.mode_of_transport::text = p_mode_of_transport); 
END; $$ LANGUAGE plpgsql STABLE;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';

COMMIT;
