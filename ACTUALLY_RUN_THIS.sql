-- Complete fix with CASCADE to handle dependencies

BEGIN;

-- Step 1: Update any shipments in the old stage
UPDATE shipment
SET current_stage = 'lc_opening'
WHERE current_stage = 'lc_shared_with_supplier';

-- Step 2: Drop views with CASCADE (this will drop dependent functions too)
DROP VIEW IF EXISTS v_shipment_stage_checklist CASCADE;
DROP VIEW IF EXISTS v_shipments_with_details CASCADE;
DROP VIEW IF EXISTS v_shipments_with_all_details CASCADE;
DROP VIEW IF EXISTS v_forecast_with_order_status CASCADE;

-- Step 3: Drop the default temporarily
ALTER TABLE shipment ALTER COLUMN current_stage DROP DEFAULT;

-- Step 4: Update the enum type
ALTER TYPE stage RENAME TO stage_old;

CREATE TYPE stage AS ENUM (
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
    'bills'
);

-- Step 5: Update all tables that use the enum
ALTER TABLE shipment ALTER COLUMN current_stage TYPE stage USING current_stage::text::stage;
ALTER TABLE audit_log ALTER COLUMN from_stage TYPE stage USING from_stage::text::stage;
ALTER TABLE audit_log ALTER COLUMN to_stage TYPE stage USING to_stage::text::stage;
ALTER TABLE stage_edge ALTER COLUMN from_stage TYPE stage USING from_stage::text::stage;
ALTER TABLE stage_edge ALTER COLUMN to_stage TYPE stage USING to_stage::text::stage;
ALTER TABLE stage_details ALTER COLUMN stage_name TYPE stage USING stage_name::text::stage;

-- Step 6: Restore the default
ALTER TABLE shipment ALTER COLUMN current_stage SET DEFAULT 'forecast'::stage;

-- Step 7: Drop old enum
DROP TYPE stage_old;

-- Step 8: Recreate v_shipment_stage_checklist view WITHOUT lc_shared_with_supplier
CREATE OR REPLACE VIEW v_shipment_stage_checklist AS
SELECT
  s.id as shipment_id,
  s.reference_code,
  s.current_stage,
  EXISTS (SELECT 1 FROM public.shipment_products sp JOIN public.forecast f ON sp.product_variety_id = f.product_variety_id WHERE sp.shipment_id = s.id) as forecast_done,
  EXISTS (SELECT 1 FROM enlistment_verification ev WHERE ev.shipment_id = s.id AND ev.verified = true AND ev.verification_doc_url IS NOT NULL) as enlistment_verification_done,
  EXISTS (SELECT 1 FROM availability_confirmation ac WHERE ac.shipment_id = s.id AND ac.available = true) as availability_confirmation_done,
  EXISTS (SELECT 1 FROM purchase_order po WHERE po.shipment_id = s.id AND po.po_file_url IS NOT NULL) as purchase_order_done,
  EXISTS (SELECT 1 FROM proforma_invoice pi WHERE pi.shipment_id = s.id AND pi.file_url IS NOT NULL) as proforma_done,
  EXISTS (SELECT 1 FROM commercial_invoice ci WHERE ci.shipment_id = s.id AND ci.file_url IS NOT NULL) as invoice_done,
  EXISTS (SELECT 1 FROM ip_number ip WHERE ip.shipment_id = s.id AND ip.file_url IS NOT NULL) as ip_number_done,
  EXISTS (SELECT 1 FROM letter_of_credit lc WHERE lc.shipment_id = s.id AND lc.file_url IS NOT NULL) as lc_opening_done,
  EXISTS (SELECT 1 FROM supplier_shipment_details ssd WHERE ssd.shipment_id = s.id) as shipment_details_from_supplier_done,
  EXISTS (SELECT 1 FROM freight_query fq WHERE fq.shipment_id = s.id) as freight_query_done,
  EXISTS (SELECT 1 FROM shipment_awarded sa WHERE sa.shipment_id = s.id AND sa.awarded = true) as award_shipment_done,
  EXISTS (SELECT 1 FROM original_docs od WHERE od.shipment_id = s.id AND od.docs_url IS NOT NULL) as original_docs_done,
  EXISTS (SELECT 1 FROM non_negotiable_docs nnd WHERE nnd.shipment_id = s.id) as non_negotiable_docs_done,
  EXISTS (SELECT 1 FROM bank_endorsement be WHERE be.shipment_id = s.id AND be.endorsed = true) as bank_endorsement_done,
  EXISTS (SELECT 1 FROM docs_to_clearing_agent dtca WHERE dtca.shipment_id = s.id AND dtca.slip_picture_url IS NOT NULL) as send_to_clearing_agent_done,
  EXISTS (SELECT 1 FROM under_clearing_agent uca WHERE uca.shipment_id = s.id AND uca.is_received = true) as under_clearing_agent_done,
  EXISTS (SELECT 1 FROM release_orders ro WHERE ro.shipment_id = s.id AND ro.dpp_ro_number IS NOT NULL AND ro.fscrd_ro_number IS NOT NULL) as release_orders_done,
  EXISTS (SELECT 1 FROM gate_out go WHERE go.shipment_id = s.id AND go.is_gate_out = true) as gate_out_done,
  EXISTS (SELECT 1 FROM transporter t WHERE t.shipment_id = s.id AND t.bilti_number IS NOT NULL) as transportation_done,
  EXISTS (SELECT 1 FROM warehouse_arrival wa WHERE wa.shipment_id = s.id AND wa.gr_no IS NOT NULL) as warehouse_done,
  EXISTS (SELECT 1 FROM bills b WHERE b.shipment_id = s.id AND b.costing IS NOT NULL) as bills_done
FROM shipment s;

COMMIT;

SELECT 'SUCCESS! Now refresh your browser (Ctrl+F5)' as result;
