-- Helper function to get the order of a stage in the workflow
CREATE OR REPLACE FUNCTION get_stage_order(p_stage public.stage)
RETURNS INT AS $$
DECLARE
    v_order INT;
BEGIN
    WITH RECURSIVE stage_path AS (
        SELECT from_stage as stage, 1 as level
        FROM public.stage_edge
        WHERE from_stage = 'forecast'
        UNION ALL
        SELECT e.to_stage, p.level + 1
        FROM public.stage_edge e
        JOIN stage_path p ON e.from_stage = p.stage
    )
    SELECT level INTO v_order
    FROM stage_path
    WHERE stage = p_stage;

    RETURN v_order;
END;
$$ LANGUAGE plpgsql;

-- Trigger function to handle stage updates
CREATE OR REPLACE FUNCTION public.handle_stage_update()
RETURNS TRIGGER AS $$
DECLARE
    v_stage_name TEXT;
    v_stage_done_col TEXT;
    v_is_done BOOLEAN;
    v_shipment_current_stage public.stage;
    v_stage_order INT;
    v_current_stage_order INT;
BEGIN
    -- Map table name to stage name and checklist column name
    CASE TG_TABLE_NAME
        WHEN 'enlistment_verification' THEN
            v_stage_name := 'enlistment_verification';
            v_stage_done_col := 'enlistment_verification_done';
        WHEN 'availability_confirmation' THEN
            v_stage_name := 'availability_confirmation';
            v_stage_done_col := 'availability_confirmation_done';
        WHEN 'purchase_order' THEN
            v_stage_name := 'purchase_order';
            v_stage_done_col := 'purchase_order_done';
        WHEN 'proforma_invoice' THEN
            v_stage_name := 'proforma';
            v_stage_done_col := 'proforma_done';
        WHEN 'commercial_invoice' THEN
            v_stage_name := 'invoice';
            v_stage_done_col := 'invoice_done';
        WHEN 'ip_number' THEN
            v_stage_name := 'ip_number';
            v_stage_done_col := 'ip_number_done';
        WHEN 'letter_of_credit' THEN
            v_stage_name := 'lc_opening';
            v_stage_done_col := 'lc_opening_done';
        WHEN 'lc_share' THEN
            v_stage_name := 'lc_shared_with_supplier';
            v_stage_done_col := 'lc_shared_with_supplier_done';
        WHEN 'supplier_shipment_details' THEN
            v_stage_name := 'shipment_details_from_supplier';
            v_stage_done_col := 'shipment_details_from_supplier_done';
        WHEN 'freight_query' THEN
            v_stage_name := 'freight_query';
            v_stage_done_col := 'freight_query_done';
        WHEN 'shipment_awarded' THEN
            v_stage_name := 'award_shipment';
            v_stage_done_col := 'award_shipment_done';
        WHEN 'non_negotiable_docs' THEN
            v_stage_name := 'non_negotiable_docs';
            v_stage_done_col := 'non_negotiable_docs_done';
        WHEN 'original_docs' THEN
            v_stage_name := 'original_docs';
            v_stage_done_col := 'original_docs_done';
        WHEN 'bank_endorsement' THEN
            v_stage_name := 'bank_endorsement';
            v_stage_done_col := 'bank_endorsement_done';
        WHEN 'docs_to_clearing_agent' THEN
            v_stage_name := 'send_to_clearing_agent';
            v_stage_done_col := 'send_to_clearing_agent_done';
        WHEN 'under_clearing_agent' THEN
            v_stage_name := 'under_clearing_agent';
            v_stage_done_col := 'under_clearing_agent_done';
        WHEN 'release_orders' THEN
            v_stage_name := 'release_orders';
            v_stage_done_col := 'release_orders_done';
        WHEN 'gate_out' THEN
            v_stage_name := 'gate_out';
            v_stage_done_col := 'gate_out_done';
        WHEN 'transporter' THEN
            v_stage_name := 'transportation';
            v_stage_done_col := 'transportation_done';
        WHEN 'warehouse_arrival' THEN
            v_stage_name := 'warehouse';
            v_stage_done_col := 'warehouse_done';
        WHEN 'bills' THEN
            v_stage_name := 'bills';
            v_stage_done_col := 'bills_done';
        ELSE
            RETURN NEW;
    END CASE;

    -- Check if the stage is now incomplete
    EXECUTE format('SELECT %I FROM public.v_shipment_stage_checklist WHERE shipment_id = %L', v_stage_done_col, NEW.shipment_id)
    INTO v_is_done;

    IF NOT v_is_done THEN
        -- Get the current stage of the shipment
        SELECT current_stage INTO v_shipment_current_stage
        FROM public.shipment
        WHERE id = NEW.shipment_id;

        -- Get the order of the stages
        v_stage_order := get_stage_order(v_stage_name::public.stage);
        v_current_stage_order := get_stage_order(v_shipment_current_stage);

        -- If the shipment has moved past the current stage, revert it
        IF v_current_stage_order > v_stage_order THEN
            UPDATE public.shipment
            SET current_stage = v_stage_name::public.stage
            WHERE id = NEW.shipment_id;

            -- Add to audit log
            INSERT INTO public.audit_log(shipment_id, actor_id, action, from_stage, to_stage, meta)
            VALUES (NEW.shipment_id, auth.uid(), 'revert_stage', v_shipment_current_stage, v_stage_name::public.stage, jsonb_build_object('auto', true, 'reason', 'data updated in ' || TG_TABLE_NAME));
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create AFTER UPDATE triggers for all stage tables
CREATE TRIGGER on_enlistment_verification_update
  AFTER UPDATE ON public.enlistment_verification
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_availability_confirmation_update
  AFTER UPDATE ON public.availability_confirmation
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_purchase_order_update
  AFTER UPDATE ON public.purchase_order
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_proforma_invoice_update
  AFTER UPDATE ON public.proforma_invoice
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_commercial_invoice_update
  AFTER UPDATE ON public.commercial_invoice
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_ip_number_update
  AFTER UPDATE ON public.ip_number
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_letter_of_credit_update
  AFTER UPDATE ON public.letter_of_credit
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_lc_share_update
  AFTER UPDATE ON public.lc_share
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_supplier_shipment_details_update
  AFTER UPDATE ON public.supplier_shipment_details
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_freight_query_update
  AFTER UPDATE ON public.freight_query
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_shipment_awarded_update
  AFTER UPDATE ON public.shipment_awarded
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_non_negotiable_docs_update
  AFTER UPDATE ON public.non_negotiable_docs
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_original_docs_update
  AFTER UPDATE ON public.original_docs
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_bank_endorsement_update
  AFTER UPDATE ON public.bank_endorsement
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_docs_to_clearing_agent_update
  AFTER UPDATE ON public.docs_to_clearing_agent
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_under_clearing_agent_update
  AFTER UPDATE ON public.under_clearing_agent
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_release_orders_update
  AFTER UPDATE ON public.release_orders
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_gate_out_update
  AFTER UPDATE ON public.gate_out
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_transporter_update
  AFTER UPDATE ON public.transporter
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_warehouse_arrival_update
  AFTER UPDATE ON public.warehouse_arrival
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();

CREATE TRIGGER on_bills_update
  AFTER UPDATE ON public.bills
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_update();
