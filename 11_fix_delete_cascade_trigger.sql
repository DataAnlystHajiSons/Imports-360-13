-- Fix handle_stage_reversal trigger to prevent errors during cascading deletes
CREATE OR REPLACE FUNCTION public.handle_stage_reversal()
RETURNS TRIGGER AS $$
DECLARE
    v_stage_name TEXT;
    v_stage_done_col TEXT;
    v_is_done BOOLEAN;
    v_shipment_current_stage public.stage;
    v_stage_order INT;
    v_current_stage_order INT;
BEGIN
    -- Check if the parent shipment still exists
    -- If it doesn't exist, we are in the middle of a cascading delete from the shipment table.
    -- In this case, we should NOT try to revert stages or write to the audit log.
    IF NOT EXISTS (SELECT 1 FROM public.shipment WHERE id = OLD.shipment_id) THEN
        RETURN OLD;
    END IF;

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
            RETURN OLD;
    END CASE;

    -- Check if the stage is now incomplete (after deletion)
    EXECUTE format('SELECT %I FROM public.v_shipment_stage_checklist WHERE shipment_id = %L', v_stage_done_col, OLD.shipment_id)
    INTO v_is_done;

    -- If there's no row in v_shipment_stage_checklist, assume it's incomplete
    IF v_is_done IS NULL THEN
        v_is_done := false;
    END IF;

    IF NOT v_is_done THEN
        -- Get the current stage of the shipment
        SELECT current_stage INTO v_shipment_current_stage
        FROM public.shipment
        WHERE id = OLD.shipment_id;

        -- Extra safety check in case the shipment was deleted between checks
        IF v_shipment_current_stage IS NULL THEN
            RETURN OLD;
        END IF;

        -- Get the order of the stages
        v_stage_order := get_stage_order(v_stage_name::public.stage);
        v_current_stage_order := get_stage_order(v_shipment_current_stage);

        -- If the shipment has moved past the current stage, revert it TO THIS STAGE
        IF v_current_stage_order > v_stage_order THEN
            UPDATE public.shipment
            SET current_stage = v_stage_name::public.stage
            WHERE id = OLD.shipment_id;

            -- Add to audit log
            INSERT INTO public.audit_log(shipment_id, actor_id, action, from_stage, to_stage, meta)
            VALUES (OLD.shipment_id, auth.uid(), 'revert_stage', v_shipment_current_stage, v_stage_name::public.stage, jsonb_build_object('auto', true, 'reason', 'data deleted from ' || TG_TABLE_NAME));
        END IF;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;