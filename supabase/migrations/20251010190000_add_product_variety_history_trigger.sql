-- This migration adds a new trigger to log price changes from the main product_variety table.

-- 1. Create a new trigger function for product_variety changes.
CREATE OR REPLACE FUNCTION public.log_product_variety_price_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if rate_per_unit or unit has changed on update.
    IF TG_OP = 'UPDATE' AND (NEW.rate_per_unit IS DISTINCT FROM OLD.rate_per_unit OR NEW.unit IS DISTINCT FROM OLD.unit) THEN
        INSERT INTO public.product_price_history (product_variety_id, rate, unit, changed_at)
        VALUES (NEW.id, NEW.rate_per_unit, NEW.unit, NOW());
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Create the new trigger on the product_variety table.
-- This trigger will fire after any update on the product_variety table.
DROP TRIGGER IF EXISTS trg_product_variety_price_change ON public.product_variety;
CREATE TRIGGER trg_product_variety_price_change
AFTER UPDATE ON public.product_variety
FOR EACH ROW
EXECUTE FUNCTION public.log_product_variety_price_change();
