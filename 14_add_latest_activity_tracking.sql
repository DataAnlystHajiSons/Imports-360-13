-- 14_add_latest_activity_tracking.sql
-- Add columns to shipment table for tracking the actual latest stage on which modifications were made

BEGIN;

-- 1. Add columns to shipment table
ALTER TABLE public.shipment ADD COLUMN IF NOT EXISTS latest_activity_stage text;
ALTER TABLE public.shipment ADD COLUMN IF NOT EXISTS latest_activity_at timestamp with time zone DEFAULT now();

-- 2. Update advance_stage function to log stage transitions as latest activity
CREATE OR REPLACE FUNCTION public.advance_stage(
  p_shipment_id uuid,
  p_to_stage public.stage,
  p_meta jsonb DEFAULT '{}'::jsonb
)
RETURNS boolean AS $$
DECLARE
  v_from_stage public.stage;
  v_user_id uuid;
BEGIN
  -- Get current stage
  SELECT current_stage INTO v_from_stage
  FROM public.shipment
  WHERE id = p_shipment_id;

  -- Get current user (if running inside Supabase context)
  BEGIN
    v_user_id := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    v_user_id := NULL;
  END;

  -- Update shipment stage AND log latest activity
  UPDATE public.shipment
  SET current_stage = p_to_stage,
      latest_activity_stage = p_to_stage::text,
      latest_activity_at = NOW()
  WHERE id = p_shipment_id;

  -- Log in audit_log
  INSERT INTO public.audit_log(shipment_id, actor_id, action, from_stage, to_stage, meta, at)
  VALUES (p_shipment_id, v_user_id, 'advance_stage', v_from_stage, p_to_stage, p_meta, NOW());

  RETURN true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create robust trigger function to auto-update updated_at AND save latest activity to shipment
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
DECLARE
    v_shipment_id UUID;
    v_stage_name TEXT;
BEGIN
    -- Set the updated_at timestamp
    BEGIN
        NEW.updated_at = NOW();
    EXCEPTION WHEN OTHERS THEN
        -- Table might not have updated_at column, which is fine
    END;
    
    -- Find shipment_id and map TG_TABLE_NAME to stage key
    v_shipment_id := NULL;
    IF TG_TABLE_NAME = 'forecast' THEN
        -- forecast table uses product_variety_id, need to find shipment_id via shipment_products
        SELECT shipment_id INTO v_shipment_id FROM public.shipment_products WHERE product_variety_id = NEW.product_variety_id LIMIT 1;
        v_stage_name := 'forecast';
    ELSE
        -- All other stage tables have shipment_id directly
        BEGIN
            v_shipment_id := NEW.shipment_id;
        EXCEPTION WHEN OTHERS THEN
            v_shipment_id := NULL;
        END;
        
        -- Map table name to stage key
        IF TG_TABLE_NAME = 'proforma_invoice' THEN v_stage_name := 'proforma';
        ELSIF TG_TABLE_NAME = 'purchase_order' THEN v_stage_name := 'purchase_order';
        ELSIF TG_TABLE_NAME = 'commercial_invoice' THEN v_stage_name := 'invoice';
        ELSIF TG_TABLE_NAME = 'letter_of_credit' THEN v_stage_name := 'lc_opening';
        ELSIF TG_TABLE_NAME = 'ip_number' THEN v_stage_name := 'ip_number';
        ELSIF TG_TABLE_NAME = 'non_negotiable_docs' THEN v_stage_name := 'non_negotiable_docs';
        ELSIF TG_TABLE_NAME = 'original_docs' THEN v_stage_name := 'original_docs';
        ELSIF TG_TABLE_NAME = 'bank_charges' THEN v_stage_name := 'lc_opening';
        ELSIF TG_TABLE_NAME = 'insurance' THEN v_stage_name := 'lc_opening';
        ELSIF TG_TABLE_NAME = 'freight_forwarder_bill' THEN v_stage_name := 'bills';
        ELSIF TG_TABLE_NAME = 'fbr_duty' THEN v_stage_name := 'under_clearing_agent';
        ELSIF TG_TABLE_NAME = 'bility' THEN v_stage_name := 'transportation';
        ELSIF TG_TABLE_NAME = 'clearing_agent_bill' THEN v_stage_name := 'under_clearing_agent';
        ELSIF TG_TABLE_NAME = 'warehouse_arrival' THEN v_stage_name := 'warehouse';
        ELSIF TG_TABLE_NAME = 'under_clearing_agent' THEN v_stage_name := 'under_clearing_agent';
        ELSIF TG_TABLE_NAME = 'release_orders' THEN v_stage_name := 'release_orders';
        ELSIF TG_TABLE_NAME = 'docs_to_clearing_agent' THEN v_stage_name := 'send_to_clearing_agent';
        ELSIF TG_TABLE_NAME = 'supplier_shipment_details' THEN v_stage_name := 'shipment_details_from_supplier';
        ELSIF TG_TABLE_NAME = 'costing' THEN v_stage_name := 'bills';
        ELSIF TG_TABLE_NAME = 'bank_endorsement' THEN v_stage_name := 'bank_endorsement';
        ELSIF TG_TABLE_NAME = 'gate_out' THEN v_stage_name := 'gate_out';
        ELSIF TG_TABLE_NAME = 'transporter' THEN v_stage_name := 'transportation';
        ELSE v_stage_name := TG_TABLE_NAME;
        END IF;
    END IF;

    -- Update parent shipment with latest activity stage
    IF v_shipment_id IS NOT NULL THEN
        UPDATE public.shipment 
        SET latest_activity_stage = v_stage_name, 
            latest_activity_at = NOW() 
        WHERE id = v_shipment_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Recreate triggers on all stage tables to fire BEFORE INSERT OR UPDATE
-- This ensures that initial inserts are also registered as activities!

-- Proforma Invoice
DROP TRIGGER IF EXISTS update_proforma_invoice_updated_at ON public.proforma_invoice;
CREATE TRIGGER update_proforma_invoice_updated_at
    BEFORE INSERT OR UPDATE ON public.proforma_invoice
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Purchase Order
DROP TRIGGER IF EXISTS update_purchase_order_updated_at ON public.purchase_order;
CREATE TRIGGER update_purchase_order_updated_at
    BEFORE INSERT OR UPDATE ON public.purchase_order
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Commercial Invoice
DROP TRIGGER IF EXISTS update_commercial_invoice_updated_at ON public.commercial_invoice;
CREATE TRIGGER update_commercial_invoice_updated_at
    BEFORE INSERT OR UPDATE ON public.commercial_invoice
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Letter of Credit
DROP TRIGGER IF EXISTS update_letter_of_credit_updated_at ON public.letter_of_credit;
CREATE TRIGGER update_letter_of_credit_updated_at
    BEFORE INSERT OR UPDATE ON public.letter_of_credit
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- IP Number
DROP TRIGGER IF EXISTS update_ip_number_updated_at ON public.ip_number;
CREATE TRIGGER update_ip_number_updated_at
    BEFORE INSERT OR UPDATE ON public.ip_number
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Non-Negotiable Docs
DROP TRIGGER IF EXISTS update_non_negotiable_docs_updated_at ON public.non_negotiable_docs;
CREATE TRIGGER update_non_negotiable_docs_updated_at
    BEFORE INSERT OR UPDATE ON public.non_negotiable_docs
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Original Docs
DROP TRIGGER IF EXISTS update_original_docs_updated_at ON public.original_docs;
CREATE TRIGGER update_original_docs_updated_at
    BEFORE INSERT OR UPDATE ON public.original_docs
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Bank Charges
DROP TRIGGER IF EXISTS update_bank_charges_updated_at ON public.bank_charges;
CREATE TRIGGER update_bank_charges_updated_at
    BEFORE INSERT OR UPDATE ON public.bank_charges
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Insurance
DROP TRIGGER IF EXISTS update_insurance_updated_at ON public.insurance;
CREATE TRIGGER update_insurance_updated_at
    BEFORE INSERT OR UPDATE ON public.insurance
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Freight Forwarder Bill
DROP TRIGGER IF EXISTS update_freight_forwarder_bill_updated_at ON public.freight_forwarder_bill;
CREATE TRIGGER update_freight_forwarder_bill_updated_at
    BEFORE INSERT OR UPDATE ON public.freight_forwarder_bill
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- FBR Duty
DROP TRIGGER IF EXISTS update_fbr_duty_updated_at ON public.fbr_duty;
CREATE TRIGGER update_fbr_duty_updated_at
    BEFORE INSERT OR UPDATE ON public.fbr_duty
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Bility
DROP TRIGGER IF EXISTS update_bility_updated_at ON public.bility;
CREATE TRIGGER update_bility_updated_at
    BEFORE INSERT OR UPDATE ON public.bility
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Clearing Agent Bill
DROP TRIGGER IF EXISTS update_clearing_agent_bill_updated_at ON public.clearing_agent_bill;
CREATE TRIGGER update_clearing_agent_bill_updated_at
    BEFORE INSERT OR UPDATE ON public.clearing_agent_bill
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Warehouse Arrival
DROP TRIGGER IF EXISTS update_warehouse_arrival_updated_at ON public.warehouse_arrival;
CREATE TRIGGER update_warehouse_arrival_updated_at
    BEFORE INSERT OR UPDATE ON public.warehouse_arrival
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Under Clearing Agent
DROP TRIGGER IF EXISTS update_under_clearing_agent_updated_at ON public.under_clearing_agent;
CREATE TRIGGER update_under_clearing_agent_updated_at
    BEFORE INSERT OR UPDATE ON public.under_clearing_agent
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Release Orders
DROP TRIGGER IF EXISTS update_release_orders_updated_at ON public.release_orders;
CREATE TRIGGER update_release_orders_updated_at
    BEFORE INSERT OR UPDATE ON public.release_orders
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Docs to Clearing Agent
DROP TRIGGER IF EXISTS update_docs_to_clearing_agent_updated_at ON public.docs_to_clearing_agent;
CREATE TRIGGER update_docs_to_clearing_agent_updated_at
    BEFORE INSERT OR UPDATE ON public.docs_to_clearing_agent
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Supplier Shipment Details
DROP TRIGGER IF EXISTS update_supplier_shipment_details_updated_at ON public.supplier_shipment_details;
CREATE TRIGGER update_supplier_shipment_details_updated_at
    BEFORE INSERT OR UPDATE ON public.supplier_shipment_details
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Costing
DROP TRIGGER IF EXISTS update_costing_updated_at ON public.costing;
CREATE TRIGGER update_costing_updated_at
    BEFORE INSERT OR UPDATE ON public.costing
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Bank Endorsement
DROP TRIGGER IF EXISTS update_bank_endorsement_updated_at ON public.bank_endorsement;
CREATE TRIGGER update_bank_endorsement_updated_at
    BEFORE INSERT OR UPDATE ON public.bank_endorsement
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Gate Out
DROP TRIGGER IF EXISTS update_gate_out_updated_at ON public.gate_out;
CREATE TRIGGER update_gate_out_updated_at
    BEFORE INSERT OR UPDATE ON public.gate_out
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Transporter
DROP TRIGGER IF EXISTS update_transporter_updated_at ON public.transporter;
CREATE TRIGGER update_transporter_updated_at
    BEFORE INSERT OR UPDATE ON public.transporter
    FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


-- 5. Backfill existing shipment's latest_activity_stage with their current_stage as safe default
UPDATE public.shipment SET latest_activity_stage = current_stage::text WHERE latest_activity_stage IS NULL;


-- 6. Recreate the dashboard view to include the new tracking columns
DROP VIEW IF EXISTS public.v_shipments_with_all_details CASCADE;

CREATE OR REPLACE VIEW public.v_shipments_with_all_details AS
SELECT
    s.id,
    s.reference_code,
    s.current_stage,
    s.status,
    s.type,
    s.created_at,
    s.payment_term_id,
    s.mode_of_transport,
    s.inco_term,
    s.freight_charges,
    s.created_by,
    s.latest_activity_stage,
    s.latest_activity_at,
    
    -- letter of credit
    lc.id AS lc_id,
    lc.lc_number,
    lc.opened_date AS lc_opened_date,
    lc.lc_shared_date,
    lc.notes AS lc_notes,
    
    -- bank
    b.id AS bank_id,
    b.name AS bank_name,
    b.branch AS bank_branch,
    b.address AS bank_address,
    
    -- documents view fkeys
    dtca.clearing_agent_id,
    ca.name AS clearing_agent_name,
    
    -- Calculate overall progress correctly evaluating strict frontend rules defined in STAGE_CONFIG (excluding URLs, notes, and system fields)
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
        (CASE WHEN EXISTS (SELECT 1 FROM public.supplier_shipment_details t WHERE t.shipment_id = s.id AND t.readiness_date IS NOT NULL AND t.address IS NOT NULL AND t.address::text <> '' AND t.origin IS NOT NULL AND t.origin::text <> '' AND t.transport IS NOT NULL AND t.inco_terms IS NOT NULL AND t.container_type IS NOT NULL AND t.cartons_count IS NOT NULL AND t.gross_weight IS NOT NULL AND t.net_weight IS NOT NULL AND t.length IS NOT NULL AND t.width IS NOT NULL AND t.height IS NOT NULL AND t.details_received_date IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.freight_query t WHERE t.shipment_id = s.id AND t.logistics_company_id IS NOT NULL AND t.term IS NOT NULL AND t.shipment_from IS NOT NULL AND t.shipment_from::text <> '' AND t.destination IS NOT NULL AND t.destination::text <> '' AND t.origin IS NOT NULL AND t.origin::text <> '' AND t.readiness_date IS NOT NULL AND t.gross_weight IS NOT NULL AND t.net_weight IS NOT NULL AND t.chargeable_weight IS NOT NULL AND t.no_of_cartoons IS NOT NULL AND t.pick_up_address IS NOT NULL AND t.pick_up_address::text <> '' AND t.remarks IS NOT NULL AND t.remarks::text <> '') THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.shipment_awarded t WHERE t.shipment_id = s.id AND t.awarded IS NOT NULL AND t.notes IS NOT NULL AND t.notes::text <> '' AND t.freight_quote_response_id IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.non_negotiable_docs t WHERE t.shipment_id = s.id AND t.status IS NOT NULL AND t.bank_id IS NOT NULL) THEN 1 ELSE 0 END) +
        (CASE WHEN EXISTS (SELECT 1 FROM public.bank_endorsement t WHERE t.shipment_id = s.id AND t.endorsed IS NOT NULL AND t.endorsed_at IS NOT NULL) THEN 1 ELSE 0 END) +
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
    
    -- total milestones (hardcoded since configuration is static)
    23 AS total_milestones_count,
    
    -- product varieties
    (SELECT jsonb_agg(jsonb_build_object('id', pv.id, 'name', pv.name, 'supplier_id', pv.supplier_id, 'supplier', jsonb_build_object('name', sup.name))) FROM public.shipment_products sp JOIN public.product_variety pv ON sp.product_variety_id = pv.id JOIN public.supplier sup ON pv.supplier_id = sup.id WHERE sp.shipment_id = s.id) AS product_variety
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

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';

COMMIT;
