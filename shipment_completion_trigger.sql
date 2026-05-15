CREATE OR REPLACE FUNCTION public.update_shipment_status_to_completed()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.costing IS NOT NULL THEN
    UPDATE public.shipment
    SET status = 'completed'
    WHERE id = NEW.shipment_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_bill_update_or_insert
  AFTER INSERT OR UPDATE ON public.bills
  FOR EACH ROW EXECUTE PROCEDURE public.update_shipment_status_to_completed();
