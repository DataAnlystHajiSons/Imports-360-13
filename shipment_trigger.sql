-- Trigger to automatically advance the stage when a new shipment is created
CREATE TRIGGER on_shipment_inserted
  AFTER INSERT ON public.shipment
  FOR EACH ROW EXECUTE PROCEDURE public.handle_stage_change();
