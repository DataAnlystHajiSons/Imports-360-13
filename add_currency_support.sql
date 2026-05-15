-- Migration: Add Multi-Currency Support (Idempotent Version)
-- This script adds currency columns and renames dollar_rate to exchange_rate for better generic support.

BEGIN;

-- 1. Update public.supplier
ALTER TABLE public.supplier ADD COLUMN IF NOT EXISTS currency VARCHAR(10) DEFAULT 'USD';
ALTER TABLE public.supplier DROP CONSTRAINT IF EXISTS supplier_currency_check;
ALTER TABLE public.supplier ADD CONSTRAINT supplier_currency_check CHECK (currency IN ('USD', 'EUR', 'PKR', 'CNY', 'GBP'));

-- 2. Update public.shipment
ALTER TABLE public.shipment ADD COLUMN IF NOT EXISTS currency VARCHAR(10) DEFAULT 'USD';
ALTER TABLE public.shipment DROP CONSTRAINT IF EXISTS shipment_currency_check;
ALTER TABLE public.shipment ADD CONSTRAINT shipment_currency_check CHECK (currency IN ('USD', 'EUR', 'PKR', 'CNY', 'GBP'));

DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='shipment' AND column_name='dollar_rate') THEN
        ALTER TABLE public.shipment RENAME COLUMN dollar_rate TO exchange_rate;
    END IF;
END $$;

-- 3. Update public.supplier_payments
ALTER TABLE public.supplier_payments ADD COLUMN IF NOT EXISTS currency VARCHAR(10) DEFAULT 'USD';
ALTER TABLE public.supplier_payments DROP CONSTRAINT IF EXISTS supplier_payments_currency_check;
ALTER TABLE public.supplier_payments ADD CONSTRAINT supplier_payments_currency_check CHECK (currency IN ('USD', 'EUR', 'PKR', 'CNY', 'GBP'));

DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='supplier_payments' AND column_name='dollar_rate') THEN
        ALTER TABLE public.supplier_payments RENAME COLUMN dollar_rate TO exchange_rate;
    END IF;
END $$;

-- 4. Update public.payment_transactions
ALTER TABLE public.payment_transactions ADD COLUMN IF NOT EXISTS currency VARCHAR(10) DEFAULT 'USD';
ALTER TABLE public.payment_transactions DROP CONSTRAINT IF EXISTS payment_transactions_currency_check;
ALTER TABLE public.payment_transactions ADD CONSTRAINT payment_transactions_currency_check CHECK (currency IN ('USD', 'EUR', 'PKR', 'CNY', 'GBP'));

DO $$ 
BEGIN 
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='payment_transactions' AND column_name='dollar_rate') THEN
        ALTER TABLE public.payment_transactions RENAME COLUMN dollar_rate TO exchange_rate;
    END IF;
END $$;

-- 5. Update v_supplier_shipment_summary View
DROP VIEW IF EXISTS public.v_supplier_shipment_summary;
CREATE VIEW public.v_supplier_shipment_summary AS
SELECT 
    s.id,
    s.name,
    s.contact_email,
    s.contact_phone,
    s.currency,
    (SELECT json_agg(cp.*) FROM public.contact_person cp WHERE cp.supplier_id = s.id) AS contact_persons,
    (SELECT json_agg(so.*) FROM public.supplier_office so WHERE so.supplier_id = s.id) AS supplier_offices,
    COUNT(DISTINCT sh.id) AS total_shipments,
    COUNT(DISTINCT CASE WHEN sh.status = 'active' THEN sh.id END) AS active_shipments,
    COUNT(DISTINCT CASE WHEN sh.status = 'completed' THEN sh.id END) AS completed_shipments
FROM 
    public.supplier s
LEFT JOIN 
    public.product_variety pv ON s.id = pv.supplier_id
LEFT JOIN 
    public.shipment_products sp ON pv.id = sp.product_variety_id
LEFT JOIN 
    public.shipment sh ON sp.shipment_id = sh.id
GROUP BY 
    s.id, s.name, s.contact_email, s.contact_phone, s.currency;

-- 6. Update the supplier_payments trigger function to handle generic exchange_rate and currency
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
    
    -- Get payment_term_id, exchange_rate and currency from shipment
    SELECT payment_term_id, exchange_rate, currency 
    INTO v_payment_term_id, v_exchange_rate, v_currency
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
        -- Note: We use rate_amount if available, otherwise fallback to variety rate
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
                exchange_rate,  -- Renamed from dollar_rate
                currency        -- Pass the currency from shipment
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
