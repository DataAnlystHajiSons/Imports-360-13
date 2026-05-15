DROP FUNCTION IF EXISTS public.handle_stage_reversal() CASCADE;

CREATE OR REPLACE FUNCTION public.handle_stage_reversal()
RETURNS TRIGGER AS $$
DECLARE
  v_previous_stage public.stage;
  v_current_stage public.stage;
  v_shipment_id uuid;
BEGIN
  -- Get the shipment_id from the deleted row
  v_shipment_id := OLD.shipment_id;

  -- Get the current stage of the shipment
  SELECT current_stage INTO v_current_stage
  FROM public.shipment
  WHERE id = v_shipment_id;

  -- Find the previous stage from the stage_edge table
  SELECT from_stage INTO v_previous_stage
  FROM public.stage_edge
  WHERE to_stage = v_current_stage;

  -- If there is no previous stage, do nothing
  IF v_previous_stage IS NULL THEN
    RETURN OLD;
  END IF;

  -- Check if the requirements for the previous stage are met.
  -- This is a safety check; they should be met if the workflow was followed.
  IF NOT public.stage_requirements_met(v_shipment_id, v_previous_stage) THEN
    RAISE EXCEPTION 'Cannot revert to stage % because its requirements are not met.', v_previous_stage;
  END IF;

  -- Update the shipment's current_stage to the previous stage
  UPDATE public.shipment
  SET current_stage = v_previous_stage
  WHERE id = v_shipment_id;

  -- Insert a record into the audit log
  INSERT INTO public.audit_log(shipment_id, actor_id, action, from_stage, to_stage, meta)
  VALUES (v_shipment_id, auth.uid(), 'revert_stage', v_current_stage, v_previous_stage, jsonb_build_object('auto', true, 'reason', 'data deleted from ' || TG_TABLE_NAME));

  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for all stage tables
CREATE TRIGGER on_enlistment_verification_delete
  AFTER DELETE ON public.enlistment_verification
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_availability_confirmation_delete
  AFTER DELETE ON public.availability_confirmation
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_purchase_order_delete
  AFTER DELETE ON public.purchase_order
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_proforma_invoice_delete
  AFTER DELETE ON public.proforma_invoice
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_commercial_invoice_delete
  AFTER DELETE ON public.commercial_invoice
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_ip_number_delete
  AFTER DELETE ON public.ip_number
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_letter_of_credit_delete
  AFTER DELETE ON public.letter_of_credit
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_lc_share_delete
  AFTER DELETE ON public.lc_share
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_supplier_shipment_details_delete
  AFTER DELETE ON public.supplier_shipment_details
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_freight_query_delete
  AFTER DELETE ON public.freight_query
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_shipment_awarded_delete
  AFTER DELETE ON public.shipment_awarded
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_non_negotiable_docs_delete
  AFTER DELETE ON public.non_negotiable_docs
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_original_docs_delete
  AFTER DELETE ON public.original_docs
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_bank_endorsement_delete
  AFTER DELETE ON public.bank_endorsement
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_docs_to_clearing_agent_delete
  AFTER DELETE ON public.docs_to_clearing_agent
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_under_clearing_agent_delete
  AFTER DELETE ON public.under_clearing_agent
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_release_orders_delete
  AFTER DELETE ON public.release_orders
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_gate_out_delete
  AFTER DELETE ON public.gate_out
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_transporter_delete
  AFTER DELETE ON public.transporter
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_warehouse_arrival_delete
  AFTER DELETE ON public.warehouse_arrival
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();

CREATE TRIGGER on_bills_delete
  AFTER DELETE ON public.bills
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_reversal();