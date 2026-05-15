-- ============================================
-- Update Supplier Payment Total to Include Freight Charges
-- ============================================
-- This updates the automation to include freight_charges in total_amount
--
-- NOTE: shipment_products.rate is already a SNAPSHOT at creation time.
-- Changing product_variety.rate_per_unit does NOT affect existing shipments.
-- This is the correct, professional approach for financial tracking.

BEGIN;

-- 1. Update the function to include freight charges
CREATE OR REPLACE FUNCTION public.update_supplier_payment_total()
RETURNS TRIGGER AS $$
DECLARE
    v_shipment_id uuid;
    v_products_total numeric;
    v_freight_charges numeric;
    v_total_amount numeric;
BEGIN
    -- Determine the shipment_id from the OLD (on delete) or NEW (on insert/update) record
    IF (TG_OP = 'DELETE') THEN
        v_shipment_id := OLD.shipment_id;
    ELSE
        v_shipment_id := NEW.shipment_id;
    END IF;

    -- Calculate the sum of (quantity * rate) for all products
    SELECT SUM(quantity * rate)
    INTO v_products_total
    FROM public.shipment_products
    WHERE shipment_id = v_shipment_id;

    -- Get freight charges from shipment
    SELECT COALESCE(freight_charges, 0)
    INTO v_freight_charges
    FROM public.shipment
    WHERE id = v_shipment_id;

    -- Calculate total = products + freight
    v_total_amount := COALESCE(v_products_total, 0) + COALESCE(v_freight_charges, 0);

    -- Update the total_amount in the supplier_payments table
    UPDATE public.supplier_payments
    SET total_amount = v_total_amount
    WHERE shipment_id = v_shipment_id;

    -- Return the appropriate record based on the operation
    IF (TG_OP = 'DELETE') THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Function for freight charges trigger
-- This function handles updates when freight charges change
CREATE OR REPLACE FUNCTION public.update_supplier_payment_total_on_freight()
RETURNS TRIGGER AS $$
DECLARE
    v_products_total numeric;
    v_freight_charges numeric;
    v_total_amount numeric;
BEGIN
    -- Calculate the sum of (quantity * rate) for all products
    SELECT SUM(quantity * rate)
    INTO v_products_total
    FROM public.shipment_products
    WHERE shipment_id = NEW.id;

    -- Get freight charges
    v_freight_charges := COALESCE(NEW.freight_charges, 0);

    -- Calculate total
    v_total_amount := COALESCE(v_products_total, 0) + v_freight_charges;

    -- Update the total_amount
    UPDATE public.supplier_payments
    SET total_amount = v_total_amount
    WHERE shipment_id = NEW.id;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create trigger for shipment freight_charges updates
-- This ensures total is recalculated when freight charges change
DROP TRIGGER IF EXISTS trigger_update_payment_on_freight ON public.shipment;
CREATE TRIGGER trigger_update_payment_on_freight
    AFTER UPDATE OF freight_charges ON public.shipment
    FOR EACH ROW
    WHEN (OLD.freight_charges IS DISTINCT FROM NEW.freight_charges)
    EXECUTE FUNCTION public.update_supplier_payment_total_on_freight();

-- 4. Backfill existing records to include freight charges
UPDATE public.supplier_payments sp
SET total_amount = (
    SELECT COALESCE(SUM(quantity * rate), 0) + COALESCE(s.freight_charges, 0)
    FROM public.shipment_products sp_prod
    JOIN public.shipment s ON s.id = sp_prod.shipment_id
    WHERE sp_prod.shipment_id = sp.shipment_id
    AND s.id = sp.shipment_id
    GROUP BY s.freight_charges
);

COMMIT;

-- Verification
SELECT '✅ Supplier payment totals now include freight charges!' as result;

-- Show some examples
SELECT 
    s.reference_code,
    COALESCE(SUM(sp_prod.quantity * sp_prod.rate), 0) as products_total,
    COALESCE(s.freight_charges, 0) as freight_charges,
    pay.total_amount as payment_total,
    CASE 
        WHEN pay.total_amount = COALESCE(SUM(sp_prod.quantity * sp_prod.rate), 0) + COALESCE(s.freight_charges, 0)
        THEN '✅ Correct'
        ELSE '❌ Mismatch'
    END as verification
FROM public.shipment s
LEFT JOIN public.shipment_products sp_prod ON sp_prod.shipment_id = s.id
LEFT JOIN public.supplier_payments pay ON pay.shipment_id = s.id
GROUP BY s.id, s.reference_code, s.freight_charges, pay.total_amount
LIMIT 5;
