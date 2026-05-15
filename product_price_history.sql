-- This script creates a history table for product prices and a trigger to populate it.

-- 1. Create the history table
CREATE TABLE public.product_price_history (
    id bigserial PRIMARY KEY,
    product_variety_id uuid NOT NULL,
    rate numeric,
    unit text,
    changed_at timestamp with time zone DEFAULT now(),
    CONSTRAINT fk_product_variety
        FOREIGN KEY(product_variety_id) 
        REFERENCES product_variety(id)
        ON DELETE CASCADE
);

-- 2. Create the trigger function
CREATE OR REPLACE FUNCTION public.log_product_price_change()
RETURNS TRIGGER AS $$
BEGIN
    -- Check if rate or unit has changed
    IF TG_OP = 'INSERT' OR (TG_OP = 'UPDATE' AND (NEW.rate IS DISTINCT FROM OLD.rate OR NEW.unit IS DISTINCT FROM OLD.unit)) THEN
        INSERT INTO public.product_price_history (product_variety_id, rate, unit, changed_at)
        VALUES (NEW.product_variety_id, NEW.rate, NEW.unit, NOW());
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Create the trigger
CREATE TRIGGER trg_shipment_products_price_change
AFTER INSERT OR UPDATE ON public.shipment_products
FOR EACH ROW
EXECUTE FUNCTION public.log_product_price_change();
