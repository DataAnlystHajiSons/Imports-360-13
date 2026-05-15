-- Step 0: Drop dependent objects
DROP FUNCTION IF EXISTS public.filter_shipments(text,uuid,uuid,uuid,text,text,text,text,text);
DROP VIEW IF EXISTS public.v_shipments_with_all_details;
DROP VIEW IF EXISTS public.v_shipments_with_details;
DROP VIEW IF EXISTS public.v_shipment_stage_checklist;

-- Step 1: Create the new commodity table
CREATE TABLE public.commodity (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  name text NOT NULL,
  CONSTRAINT commodity_pkey PRIMARY KEY (id),
  CONSTRAINT commodity_name_key UNIQUE (name)
);

-- Step 2: Populate the new commodity table with existing distinct commodities
INSERT INTO public.commodity (name)
SELECT DISTINCT commodity::text FROM public.product_variety;

-- Step 3: Add the new commodity_id column to the product_variety table
ALTER TABLE public.product_variety
ADD COLUMN commodity_id uuid;

-- Step 4: Update the new commodity_id column with the corresponding id from the commodity table
UPDATE public.product_variety pv
SET commodity_id = c.id
FROM public.commodity c
WHERE pv.commodity::text = c.name;

-- Step 5: Add the foreign key constraint
ALTER TABLE public.product_variety
ADD CONSTRAINT product_variety_commodity_id_fkey
FOREIGN KEY (commodity_id) REFERENCES public.commodity(id);

-- Step 6: Drop the old commodity column
ALTER TABLE public.product_variety
DROP COLUMN commodity;

-- Step 7: Recreate the views and functions

-- v_shipment_stage_checklist
CREATE OR REPLACE VIEW public.v_shipment_stage_checklist AS
SELECT
  s.id AS shipment_id,
  s.reference_code,
  s.current_stage,
  -- Forecast
  EXISTS (SELECT 1 FROM public.shipment_products sp JOIN public.forecast f ON sp.product_variety_id = f.product_variety_id WHERE sp.shipment_id = s.id) as forecast_done,
  -- Enlistment Verification
  EXISTS (SELECT 1 FROM enlistment_verification ev WHERE ev.shipment_id = s.id AND ev.verified = true AND ev.verification_doc_url IS NOT NULL) as enlistment_verification_done,
  -- Availability
  EXISTS (SELECT 1 FROM availability_confirmation ac WHERE ac.shipment_id = s.id AND ac.available = true) as availability_confirmation_done,
  -- Purchase Order
  EXISTS (SELECT 1 FROM purchase_order po WHERE po.shipment_id = s.id AND po.po_file_url IS NOT NULL) as purchase_order_done,
  -- Proforma
  EXISTS (SELECT 1 FROM proforma_invoice pi WHERE pi.shipment_id = s.id AND pi.file_url IS NOT NULL) as proforma_done,
  -- Invoice
  EXISTS (SELECT 1 FROM commercial_invoice ci WHERE ci.shipment_id = s.id AND ci.file_url IS NOT NULL) as invoice_done,
  -- IP Number
  EXISTS (SELECT 1 FROM ip_number ip WHERE ip.shipment_id = s.id AND ip.file_url IS NOT NULL AND ip.ip_reference IS NOT NULL) as ip_number_done,
  -- LC Opening (manual)
  EXISTS (SELECT 1 FROM letter_of_credit lc WHERE lc.shipment_id = s.id AND lc.file_url IS NOT NULL) as lc_opening_done,
  -- LC Shared (manual)
  EXISTS (SELECT 1 FROM lc_share lcs WHERE lcs.shipment_id = s.id) as lc_shared_with_supplier_done,
  -- Supplier Details (manual)
  EXISTS (SELECT 1 FROM supplier_shipment_details ssd WHERE ssd.shipment_id = s.id) as shipment_details_from_supplier_done,
  -- Freight Query (manual)
  EXISTS (SELECT 1 FROM freight_query fq WHERE fq.shipment_id = s.id) as freight_query_done,
  -- Award Shipment
  EXISTS (SELECT 1 FROM shipment_awarded sa WHERE sa.shipment_id = s.id AND sa.awarded = true) as award_shipment_done,
  -- Non Negotiable Docs
  EXISTS (SELECT 1 FROM non_negotiable_docs nnd WHERE nnd.shipment_id = s.id AND nnd.docs_url IS NOT NULL) as non_negotiable_docs_done,
  -- Original Docs
  EXISTS (SELECT 1 FROM original_docs od WHERE od.shipment_id = s.id AND od.docs_url IS NOT NULL) as original_docs_done,
  -- Bank Endorsement
  EXISTS (SELECT 1 FROM bank_endorsement be WHERE be.shipment_id = s.id AND be.endorsed = true) as bank_endorsement_done,
  -- Send to Clearing Agent
  EXISTS (SELECT 1 FROM docs_to_clearing_agent dtca WHERE dtca.shipment_id = s.id AND dtca.slip_picture_url IS NOT NULL) as send_to_clearing_agent_done,
  -- Under Clearing Agent
  EXISTS (SELECT 1 FROM under_clearing_agent uca WHERE uca.shipment_id = s.id AND uca.is_received = true) as under_clearing_agent_done,
  -- Release Orders
  EXISTS (SELECT 1 FROM release_orders ro WHERE ro.shipment_id = s.id AND ro.dpp_ro_number IS NOT NULL AND ro.fscrd_ro_number IS NOT NULL) as release_orders_done,
  -- Gate out
  EXISTS (SELECT 1 FROM gate_out go WHERE go.shipment_id = s.id AND go.is_gate_out = true) as gate_out_done,
  -- Transportation
  EXISTS (SELECT 1 FROM transporter t WHERE t.shipment_id = s.id AND t.bilti_number IS NOT NULL) as transportation_done,
  -- Warehouse
  EXISTS (SELECT 1 FROM warehouse_arrival wa WHERE wa.shipment_id = s.id AND wa.gr_no IS NOT NULL) as warehouse_done,
  -- Bills
  EXISTS (SELECT 1 FROM bills b WHERE b.shipment_id = s.id AND b.costing IS NOT NULL) as bills_done
from shipment s;

-- v_shipments_with_details
CREATE OR REPLACE VIEW public.v_shipments_with_details AS
SELECT
    s.id,
    s.reference_code,
    s.current_stage,
    s.status,
    s.created_at,
    (SELECT pv.product_name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id WHERE sp.shipment_id = s.id LIMIT 1) as product_name,
    (SELECT pv.variety_name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id WHERE sp.shipment_id = s.id LIMIT 1) as variety_name,
    (SELECT sup.name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.supplier sup ON pv.supplier_id = sup.id WHERE sp.shipment_id = s.id LIMIT 1) AS supplier_name,
    (SELECT jsonb_agg(jsonb_build_object('product_name', pv.product_name, 'variety_name', pv.variety_name, 'supplier', jsonb_build_object('name', sup.name))) FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.supplier sup ON pv.supplier_id = sup.id WHERE sp.shipment_id = s.id) AS product_variety
FROM
    public.shipment s;

-- v_shipments_with_all_details
CREATE OR REPLACE VIEW public.v_shipments_with_all_details AS
SELECT
    s.id,
    s.reference_code,
    s.current_stage,
    s.status,
    s.created_at,
    (SELECT pv.product_name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id WHERE sp.shipment_id = s.id LIMIT 1) as product_name,
    (SELECT pv.variety_name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id WHERE sp.shipment_id = s.id LIMIT 1) as variety_name,
    (SELECT c.name FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.commodity c ON pv.commodity_id = c.id WHERE sp.shipment_id = s.id LIMIT 1) as commodity,
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

-- filter_shipments
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
RETURNS SETOF v_shipments_with_all_details AS $
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
$ LANGUAGE plpgsql;