-- Add dollar_rate to shipment table and update trigger
-- This allows capturing dollar rate during shipment creation

-- ============================================
-- Step 1: Add dollar_rate column to shipment table
-- ============================================
ALTER TABLE public.shipment
ADD COLUMN IF NOT EXISTS dollar_rate numeric;

COMMENT ON COLUMN public.shipment.dollar_rate IS 'Agreed exchange rate (PKR per USD) for this shipment';

-- ============================================
-- Step 2: Update the supplier_payments trigger to include dollar_rate
-- ============================================
CREATE OR REPLACE FUNCTION create_supplier_payment_on_shipment_product()
RETURNS TRIGGER AS $$
DECLARE
    v_shipment_id uuid;
    v_supplier_id uuid;
    v_payment_term_id uuid;
    v_total_amount NUMERIC;
    v_dollar_rate NUMERIC;
BEGIN
    v_shipment_id := NEW.shipment_id;
    
    -- Get payment_term_id and dollar_rate from shipment
    SELECT payment_term_id, dollar_rate 
    INTO v_payment_term_id, v_dollar_rate
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
                status,
                dollar_rate  -- Include dollar_rate from shipment
            )
            VALUES (
                v_shipment_id,
                v_supplier_id,
                v_payment_term_id,
                v_total_amount,
                0,
                'pending',
                v_dollar_rate  -- Use dollar_rate from shipment
            )
            ON CONFLICT (shipment_id) 
            DO UPDATE SET
                total_amount = EXCLUDED.total_amount,
                dollar_rate = EXCLUDED.dollar_rate,  -- Update dollar_rate if changed
                updated_at = NOW();
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Step 3: Recreate the trigger
-- ============================================
DROP TRIGGER IF EXISTS trigger_create_supplier_payment ON shipment_products;

CREATE TRIGGER trigger_create_supplier_payment
    AFTER INSERT OR UPDATE ON shipment_products
    FOR EACH ROW
    EXECUTE FUNCTION create_supplier_payment_on_shipment_product();

-- ============================================
-- Step 4: Verify the changes
-- ============================================
SELECT 
    'dollar_rate column added to shipment table' as status,
    EXISTS(
        SELECT 1 
        FROM information_schema.columns 
        WHERE table_name = 'shipment' 
        AND column_name = 'dollar_rate'
    ) as column_exists;

SELECT 
    'Trigger updated successfully' as status,
    trigger_name,
    event_manipulation,
    event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'trigger_create_supplier_payment';

-- ============================================
-- Success message
-- ============================================
DO $$
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
    RAISE NOTICE '✅ Dollar Rate Setup Complete!';
    RAISE NOTICE '========================================';
    RAISE NOTICE '';
    RAISE NOTICE '1. dollar_rate column added to shipment table';
    RAISE NOTICE '2. dollar_rate column already exists in supplier_payments table';
    RAISE NOTICE '3. Trigger updated to copy dollar_rate from shipment to supplier_payments';
    RAISE NOTICE '';
    RAISE NOTICE '📋 Next Steps:';
    RAISE NOTICE '- Add dollar_rate input field to shipment creation form (admin-dashboard.html)';
    RAISE NOTICE '- Update ShipmentFormManager.js to capture and save dollar_rate';
    RAISE NOTICE '';
    RAISE NOTICE '========================================';
END $$;
