-- This script creates the automation for auto-filling the product rate when it's added to a shipment.

-- 1. The Function
-- This function is called by the trigger before a new row is inserted.
CREATE OR REPLACE FUNCTION public.autofill_shipment_product_rate()
RETURNS TRIGGER AS $$
DECLARE
    v_master_rate numeric;
BEGIN
    -- Only act if the rate for the new product is not already specified.
    -- This allows for manual price overrides during insertion.
    IF NEW.rate IS NULL THEN
        -- Get the master rate from the product_variety table
        SELECT rate_per_unit
        INTO v_master_rate
        FROM public.product_variety
        WHERE id = NEW.product_variety_id;

        -- If a master rate is found, set it on the new shipment_products row
        IF FOUND AND v_master_rate IS NOT NULL THEN
            NEW.rate := v_master_rate;
        END IF;
    END IF;

    -- Return the (potentially modified) new row to allow the insertion to proceed
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. The Trigger
-- This trigger fires the function BEFORE a new product is added to a shipment.
DROP TRIGGER IF EXISTS trigger_autofill_rate ON public.shipment_products;
CREATE TRIGGER trigger_autofill_rate
    BEFORE INSERT ON public.shipment_products
    FOR EACH ROW
    EXECUTE FUNCTION public.autofill_shipment_product_rate();
