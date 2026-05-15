-- Fix missing supplier payments records
-- Creates payment records for all shipments that don't have them yet

BEGIN;

-- Step 1: Backfill existing shipments (run the existing backfill logic)
DO $$
DECLARE
    shipment_record RECORD;
    v_total_amount NUMERIC;
    v_supplier_id UUID;
    v_payment_term_id UUID;
    v_created_count INT := 0;
    v_skipped_count INT := 0;
BEGIN
    RAISE NOTICE 'Starting supplier_payments backfill...';
    
    FOR shipment_record IN 
        SELECT id, payment_term_id, reference_code 
        FROM public.shipment 
        ORDER BY created_at DESC
    LOOP
        -- Check if a supplier_payments record already exists
        IF NOT EXISTS (SELECT 1 FROM public.supplier_payments WHERE shipment_id = shipment_record.id) THEN
            
            -- Get the supplier_id from the first product in the shipment
            SELECT pv.supplier_id INTO v_supplier_id
            FROM public.shipment_products sp
            JOIN public.product_variety pv ON sp.product_variety_id = pv.id
            WHERE sp.shipment_id = shipment_record.id
            LIMIT 1;

            -- Get the payment_term_id from the shipment
            v_payment_term_id := shipment_record.payment_term_id;

            -- Calculate the total amount for the shipment
            SELECT COALESCE(SUM(quantity * rate), 0)
            INTO v_total_amount
            FROM public.shipment_products
            WHERE shipment_id = shipment_record.id;

            -- Insert the new record into supplier_payments
            IF v_supplier_id IS NOT NULL AND v_payment_term_id IS NOT NULL AND v_total_amount > 0 THEN
                INSERT INTO public.supplier_payments (
                    shipment_id, 
                    supplier_id, 
                    payment_term_id, 
                    total_amount,
                    amount_paid,
                    status
                )
                VALUES (
                    shipment_record.id, 
                    v_supplier_id, 
                    v_payment_term_id, 
                    v_total_amount,
                    0,
                    'pending'
                );

                v_created_count := v_created_count + 1;
                RAISE NOTICE 'Created payment record for shipment: % (Ref: %)', 
                    shipment_record.id, shipment_record.reference_code;
            ELSE
                v_skipped_count := v_skipped_count + 1;
                RAISE NOTICE 'Skipped shipment: % (Ref: %) - Reason: supplier_id=%, payment_term_id=%, total_amount=%', 
                    shipment_record.id, 
                    shipment_record.reference_code,
                    v_supplier_id, 
                    v_payment_term_id,
                    v_total_amount;
            END IF;
        END IF;
    END LOOP;
    
    RAISE NOTICE 'Backfill complete! Created: %, Skipped: %', v_created_count, v_skipped_count;
END;
$$;

-- Step 2: Create trigger to auto-create payment records for new shipments
CREATE OR REPLACE FUNCTION create_supplier_payment_on_shipment()
RETURNS TRIGGER AS $$
DECLARE
    v_supplier_id UUID;
    v_total_amount NUMERIC;
BEGIN
    -- Only proceed if shipment has products and payment term
    IF NEW.payment_term_id IS NOT NULL THEN
        
        -- Get supplier from first product
        SELECT pv.supplier_id INTO v_supplier_id
        FROM shipment_products sp
        JOIN product_variety pv ON sp.product_variety_id = pv.id
        WHERE sp.shipment_id = NEW.id
        LIMIT 1;
        
        -- Calculate total amount
        SELECT COALESCE(SUM(quantity * rate), 0)
        INTO v_total_amount
        FROM shipment_products
        WHERE shipment_id = NEW.id;
        
        -- Create payment record if supplier exists and amount > 0
        IF v_supplier_id IS NOT NULL AND v_total_amount > 0 THEN
            INSERT INTO supplier_payments (
                shipment_id,
                supplier_id,
                payment_term_id,
                total_amount,
                amount_paid,
                status
            )
            VALUES (
                NEW.id,
                v_supplier_id,
                NEW.payment_term_id,
                v_total_amount,
                0,
                'pending'
            )
            ON CONFLICT (shipment_id) DO NOTHING;
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS trigger_create_supplier_payment ON shipment_products;

-- Create trigger on shipment_products (runs after products are added)
CREATE TRIGGER trigger_create_supplier_payment
    AFTER INSERT OR UPDATE ON shipment_products
    FOR EACH ROW
    EXECUTE FUNCTION create_supplier_payment_on_shipment();

-- Step 3: Verify results
SELECT 
    'Total Shipments' as metric,
    COUNT(*) as count
FROM shipment
UNION ALL
SELECT 
    'Shipments with Payment Records' as metric,
    COUNT(*) as count
FROM supplier_payments
UNION ALL
SELECT 
    'Shipments Missing Payment Records' as metric,
    COUNT(*) as count
FROM shipment s
WHERE NOT EXISTS (
    SELECT 1 FROM supplier_payments sp WHERE sp.shipment_id = s.id
);

-- Show details of shipments missing payment records
SELECT 
    s.id,
    s.reference_code,
    s.created_at,
    CASE 
        WHEN s.payment_term_id IS NULL THEN 'Missing payment term'
        WHEN NOT EXISTS (SELECT 1 FROM shipment_products WHERE shipment_id = s.id) THEN 'No products'
        WHEN (SELECT SUM(quantity * rate) FROM shipment_products WHERE shipment_id = s.id) = 0 THEN 'Total amount is 0'
        ELSE 'Unknown reason'
    END as reason
FROM shipment s
WHERE NOT EXISTS (
    SELECT 1 FROM supplier_payments sp WHERE sp.shipment_id = s.id
)
ORDER BY s.created_at DESC
LIMIT 10;

COMMIT;

-- =============================================
-- NOTES:
-- =============================================
-- 1. This script creates payment records for all existing shipments
-- 2. Auto-creates payment records when products are added to new shipments
-- 3. Skips shipments without:
--    - Payment term
--    - Products
--    - Valid supplier
--    - Non-zero total amount
-- 4. All shipments should now appear in supplier-payments.html
