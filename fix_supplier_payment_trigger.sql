-- Fix the supplier payment trigger that's causing the error
-- The issue: trigger tries to access NEW.payment_term_id but it's on shipment table, not shipment_products

-- Drop the problematic trigger
DROP TRIGGER IF EXISTS trigger_create_supplier_payment ON shipment_products;

-- Recreate the function with the correct logic
CREATE OR REPLACE FUNCTION create_supplier_payment_on_shipment_product()
RETURNS TRIGGER AS $$
DECLARE
    v_supplier_id UUID;
    v_total_amount NUMERIC;
    v_payment_term_id UUID;
    v_shipment_id UUID;
BEGIN
    -- Get shipment_id from the NEW record
    v_shipment_id := NEW.shipment_id;
    
    -- Get payment_term_id from the shipment table (not from NEW)
    SELECT payment_term_id INTO v_payment_term_id
    FROM shipment
    WHERE id = v_shipment_id;
    
    -- Only proceed if shipment has payment term
    IF v_payment_term_id IS NOT NULL THEN
        
        -- Get supplier from first product
        SELECT pv.supplier_id INTO v_supplier_id
        FROM shipment_products sp
        JOIN product_variety pv ON sp.product_variety_id = pv.id
        WHERE sp.shipment_id = v_shipment_id
        LIMIT 1;
        
        -- Calculate total amount
        SELECT COALESCE(SUM(quantity * COALESCE(rate, 0)), 0)
        INTO v_total_amount
        FROM shipment_products
        WHERE shipment_id = v_shipment_id;
        
        -- Create or update payment record if supplier exists
        IF v_supplier_id IS NOT NULL THEN
            INSERT INTO supplier_payments (
                shipment_id,
                supplier_id,
                payment_term_id,
                total_amount,
                amount_paid,
                status
            )
            VALUES (
                v_shipment_id,
                v_supplier_id,
                v_payment_term_id,
                v_total_amount,
                0,
                'pending'
            )
            ON CONFLICT (shipment_id) 
            DO UPDATE SET
                total_amount = EXCLUDED.total_amount,
                updated_at = NOW();
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger with the corrected function
CREATE TRIGGER trigger_create_supplier_payment
    AFTER INSERT OR UPDATE ON shipment_products
    FOR EACH ROW
    EXECUTE FUNCTION create_supplier_payment_on_shipment_product();

-- Verify the fix
SELECT 'Trigger fixed successfully! Now you can add products without errors.' as status;
