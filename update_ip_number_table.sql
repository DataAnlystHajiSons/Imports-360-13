-- This script updates the ip_number table to support a single attachment and multiple IP references per shipment.

-- 1. Drop the dependent view
DROP VIEW IF EXISTS public.v_shipment_stage_checklist;

-- 2. Drop the existing ip_number table
DROP TABLE IF EXISTS public.ip_number;

-- 3. Create the new ip_number table with a JSONB column for references
CREATE TABLE public.ip_number (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shipment_id uuid UNIQUE NOT NULL,
  issued_date date,
  file_url text,
  "references" jsonb,
  created_at timestamp with time zone DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  CONSTRAINT ip_number_pkey PRIMARY KEY (id),
  CONSTRAINT ip_number_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id) ON DELETE CASCADE,
  CONSTRAINT ip_number_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id)
);

-- Add a comment to explain the structure of the references column
COMMENT ON COLUMN public.ip_number.references IS 'JSONB array of objects, e.g., [{"product_variety_id": "...", "ip_reference": "..."}, ...]';

-- 4. Recreate the view with the updated logic
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
  EXISTS (SELECT 1 FROM ip_number ip WHERE ip.shipment_id = s.id AND ip.file_url IS NOT NULL AND ip.references IS NOT NULL AND jsonb_array_length(ip.references) > 0) as ip_number_done,
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
  EXISTS (SELECT 1 FROM non_negotiable_docs nnd WHERE nnd.shipment_id = s.id AND nnd.file_url IS NOT NULL) as non_negotiable_docs_done,
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
FROM shipment s;
