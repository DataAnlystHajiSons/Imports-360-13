CREATE OR REPLACE FUNCTION public.handle_supplier_details_insert()
RETURNS TRIGGER AS $$
DECLARE
  v_shipment_current_stage public.stage;
  v_next_stage public.stage;
BEGIN
  -- Get the current stage of the shipment
  SELECT current_stage INTO v_shipment_current_stage
  FROM public.shipment
  WHERE id = NEW.shipment_id;

  -- Check if the shipment is in the correct stage to be advanced
  IF v_shipment_current_stage = 'shipment_details_from_supplier' THEN
    -- Find the next stage from the stage_edge table
    SELECT to_stage INTO v_next_stage
    FROM public.stage_edge
    WHERE from_stage = v_shipment_current_stage;

    -- If there is a next stage, advance the stage
    IF v_next_stage IS NOT NULL THEN
        PERFORM public.advance_stage(NEW.shipment_id, v_next_stage);
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS on_supplier_shipment_details_insert ON public.supplier_shipment_details;
CREATE TRIGGER on_supplier_shipment_details_insert
  AFTER INSERT ON public.supplier_shipment_details
  FOR EACH ROW EXECUTE PROCEDURE public.handle_supplier_details_insert();
