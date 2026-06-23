-- repopulate_latest_activity.sql
-- Run this in your Supabase SQL editor to retroactively backfill latest activity stages 
-- for all existing historical shipments based on their actual last modified timestamps.

BEGIN;

CREATE OR REPLACE FUNCTION public.backfill_latest_activity()
RETURNS void AS $$
DECLARE
    s RECORD;
    v_latest_stage TEXT;
    v_max_time TIMESTAMP WITH TIME ZONE;
    v_temp_time TIMESTAMP WITH TIME ZONE;
BEGIN
    FOR s IN SELECT id, current_stage, created_at FROM public.shipment LOOP
        -- Default to the shipment's current stage and created date
        v_latest_stage := s.current_stage::text;
        v_max_time := s.created_at;

        -- 1. proforma_invoice
        SELECT MAX(updated_at) INTO v_temp_time FROM public.proforma_invoice WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'proforma'; END IF;

        -- 2. purchase_order
        SELECT MAX(updated_at) INTO v_temp_time FROM public.purchase_order WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'purchase_order'; END IF;

        -- 3. commercial_invoice
        SELECT MAX(updated_at) INTO v_temp_time FROM public.commercial_invoice WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'invoice'; END IF;

        -- 4. letter_of_credit
        SELECT MAX(updated_at) INTO v_temp_time FROM public.letter_of_credit WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'lc_opening'; END IF;

        -- 5. ip_number
        SELECT MAX(updated_at) INTO v_temp_time FROM public.ip_number WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'ip_number'; END IF;

        -- 6. non_negotiable_docs
        SELECT MAX(updated_at) INTO v_temp_time FROM public.non_negotiable_docs WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'non_negotiable_docs'; END IF;

        -- 7. original_docs
        SELECT MAX(updated_at) INTO v_temp_time FROM public.original_docs WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'original_docs'; END IF;

        -- 8. bank_charges
        SELECT MAX(updated_at) INTO v_temp_time FROM public.bank_charges WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'lc_opening'; END IF;

        -- 9. insurance
        SELECT MAX(updated_at) INTO v_temp_time FROM public.insurance WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'lc_opening'; END IF;

        -- 10. freight_forwarder_bill
        SELECT MAX(updated_at) INTO v_temp_time FROM public.freight_forwarder_bill WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'bills'; END IF;

        -- 11. fbr_duty
        SELECT MAX(updated_at) INTO v_temp_time FROM public.fbr_duty WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'under_clearing_agent'; END IF;

        -- 12. bility
        SELECT MAX(updated_at) INTO v_temp_time FROM public.bility WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'transportation'; END IF;

        -- 13. clearing_agent_bill
        SELECT MAX(updated_at) INTO v_temp_time FROM public.clearing_agent_bill WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'under_clearing_agent'; END IF;

        -- 14. warehouse_arrival
        SELECT MAX(updated_at) INTO v_temp_time FROM public.warehouse_arrival WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'warehouse'; END IF;

        -- 15. under_clearing_agent
        SELECT MAX(updated_at) INTO v_temp_time FROM public.under_clearing_agent WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'under_clearing_agent'; END IF;

        -- 16. release_orders
        SELECT MAX(updated_at) INTO v_temp_time FROM public.release_orders WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'release_orders'; END IF;

        -- 17. docs_to_clearing_agent
        SELECT MAX(updated_at) INTO v_temp_time FROM public.docs_to_clearing_agent WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'send_to_clearing_agent'; END IF;

        -- 18. supplier_shipment_details
        SELECT MAX(updated_at) INTO v_temp_time FROM public.supplier_shipment_details WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'shipment_details_from_supplier'; END IF;

        -- 19. costing
        SELECT MAX(updated_at) INTO v_temp_time FROM public.costing WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'bills'; END IF;

        -- 20. bank_endorsement
        SELECT MAX(updated_at) INTO v_temp_time FROM public.bank_endorsement WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'bank_endorsement'; END IF;

        -- 21. gate_out
        SELECT MAX(updated_at) INTO v_temp_time FROM public.gate_out WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'gate_out'; END IF;

        -- 22. transporter
        SELECT MAX(updated_at) INTO v_temp_time FROM public.transporter WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'transportation'; END IF;

        -- 23. bank_debit_advice
        SELECT MAX(updated_at) INTO v_temp_time FROM public.bank_debit_advice WHERE shipment_id = s.id;
        IF v_temp_time IS NOT NULL AND v_temp_time > v_max_time THEN v_max_time := v_temp_time; v_latest_stage := 'bank_debit_advice'; END IF;

        -- Save the computed most recent edit details back to the parent shipment table
        UPDATE public.shipment 
        SET latest_activity_stage = v_latest_stage,
            latest_activity_at = v_max_time
        WHERE id = s.id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Execute the retroactive backfill
SELECT public.backfill_latest_activity();

-- Cleanup the temporary helper function
DROP FUNCTION IF EXISTS public.backfill_latest_activity();

COMMIT;
