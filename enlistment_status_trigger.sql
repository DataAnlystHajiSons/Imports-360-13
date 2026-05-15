CREATE OR REPLACE FUNCTION public.update_enlistment_status()
RETURNS TRIGGER AS $$
BEGIN
    NEW.enlistment_status := EXISTS (
        SELECT 1
        FROM public.verification_list
        WHERE crop_id = NEW.product_variety_id
    );
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER forecast_enlistment_status_trigger
BEFORE INSERT OR UPDATE ON public.forecast
FOR EACH ROW
EXECUTE FUNCTION public.update_enlistment_status();