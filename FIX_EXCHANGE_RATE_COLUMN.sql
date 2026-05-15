-- FIX: Ensure exchange_rate column exists in all required tables
-- This script is more aggressive and ensures the columns are present.

BEGIN;

-- 1. FIX: shipment table
DO $$ 
BEGIN 
    -- If dollar_rate exists but exchange_rate doesn't, rename it
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='shipment' AND column_name='dollar_rate') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='shipment' AND column_name='exchange_rate') THEN
        ALTER TABLE public.shipment RENAME COLUMN dollar_rate TO exchange_rate;
    -- If neither exists, add exchange_rate
    ELSIF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='shipment' AND column_name='exchange_rate') THEN
        ALTER TABLE public.shipment ADD COLUMN exchange_rate numeric;
    END IF;
END $$;

-- 2. FIX: supplier_payments table
DO $$ 
BEGIN 
    -- If dollar_rate exists but exchange_rate doesn't, rename it
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='supplier_payments' AND column_name='dollar_rate') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='supplier_payments' AND column_name='exchange_rate') THEN
        ALTER TABLE public.supplier_payments RENAME COLUMN dollar_rate TO exchange_rate;
    -- If neither exists, add exchange_rate
    ELSIF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='supplier_payments' AND column_name='exchange_rate') THEN
        ALTER TABLE public.supplier_payments ADD COLUMN exchange_rate numeric;
    END IF;
END $$;

-- 3. FIX: payment_transactions table
DO $$ 
BEGIN 
    -- If dollar_rate exists but exchange_rate doesn't, rename it
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='payment_transactions' AND column_name='dollar_rate') 
       AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='payment_transactions' AND column_name='exchange_rate') THEN
        ALTER TABLE public.payment_transactions RENAME COLUMN dollar_rate TO exchange_rate;
    -- If neither exists, add exchange_rate
    ELSIF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='payment_transactions' AND column_name='exchange_rate') THEN
        ALTER TABLE public.payment_transactions ADD COLUMN exchange_rate numeric;
    END IF;
END $$;

-- 4. Re-verify and update the trigger function to be absolutely sure
CREATE OR REPLACE FUNCTION create_supplier_payment_on_shipment_product()
RETURNS TRIGGER AS $$
DECLARE
    v_shipment_id uuid;
    v_supplier_id uuid;
    v_payment_term_id uuid;
    v_total_amount NUMERIC;
    v_exchange_rate NUMERIC;
    v_currency VARCHAR(10);
BEGIN
    v_shipment_id := NEW.shipment_id;
    
    -- Get data from shipment
    SELECT payment_term_id, exchange_rate, currency 
    INTO v_payment_term_id, v_exchange_rate, v_currency
    FROM shipment
    WHERE id = v_shipment_id;
    
    IF v_payment_term_id IS NOT NULL THEN
        -- Get supplier
        SELECT pv.supplier_id INTO v_supplier_id
        FROM shipment_products sp
        JOIN product_variety pv ON sp.product_variety_id = pv.id
        WHERE sp.shipment_id = v_shipment_id
        LIMIT 1;
        
        -- Calculate total
        SELECT COALESCE(SUM(quantity * COALESCE(rate, 0)), 0)
        INTO v_total_amount
        FROM shipment_products
        WHERE shipment_id = v_shipment_id;
        
        IF v_supplier_id IS NOT NULL THEN
            INSERT INTO supplier_payments (
                shipment_id,
                supplier_id,
                payment_term_id,
                total_amount,
                amount_paid,
                status,
                exchange_rate,
                currency
            )
            VALUES (
                v_shipment_id,
                v_supplier_id,
                v_payment_term_id,
                v_total_amount,
                0,
                'pending',
                v_exchange_rate,
                v_currency
            )
            ON CONFLICT (shipment_id) 
            DO UPDATE SET
                total_amount = EXCLUDED.total_amount,
                exchange_rate = EXCLUDED.exchange_rate,
                currency = EXCLUDED.currency,
                updated_at = NOW();
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMIT;
