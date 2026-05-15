-- This script creates the automation for calculating the total_amount in the supplier_payments table.

-- 1. The Function
-- This function is called by the trigger. It recalculates the total value of all products in a shipment.
CREATE OR REPLACE FUNCTION public.update_supplier_payment_total()
RETURNS TRIGGER AS $$
DECLARE
    v_shipment_id uuid;
    v_total_amount numeric;
BEGIN
    -- Determine the shipment_id from the OLD (on delete) or NEW (on insert/update) record
    IF (TG_OP = 'DELETE') THEN
        v_shipment_id := OLD.shipment_id;
    ELSE
        v_shipment_id := NEW.shipment_id;
    END IF;

    -- Calculate the sum of (quantity * rate) for all products in the specific shipment
    SELECT SUM(quantity * rate)
    INTO v_total_amount
    FROM public.shipment_products
    WHERE shipment_id = v_shipment_id;

    -- Update the total_amount in the supplier_payments table for the specific shipment.
    -- COALESCE ensures that if no products are left, the total becomes 0 instead of NULL.
    UPDATE public.supplier_payments
    SET total_amount = COALESCE(v_total_amount, 0)
    WHERE shipment_id = v_shipment_id;

    -- Return the appropriate record based on the operation
    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. The Trigger
-- This trigger fires the function whenever a product is added, removed, or its quantity/rate is updated.
DROP TRIGGER IF EXISTS trigger_update_payment_total ON public.shipment_products;
CREATE TRIGGER trigger_update_payment_total
    AFTER INSERT OR UPDATE OF quantity, rate OR DELETE ON public.shipment_products
    FOR EACH ROW
    EXECUTE FUNCTION public.update_supplier_payment_total();
