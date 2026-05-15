-- Add dollar_rate column to supplier_payments table
-- This stores the agreed exchange rate (PKR per USD) for the supplier payment

ALTER TABLE public.supplier_payments
ADD COLUMN IF NOT EXISTS dollar_rate numeric;

COMMENT ON COLUMN public.supplier_payments.dollar_rate IS 'Agreed exchange rate (PKR per USD) for this supplier payment';

-- Optionally, you can also add dollar_rate to payment_transactions if each transaction can have different rates
ALTER TABLE public.payment_transactions
ADD COLUMN IF NOT EXISTS dollar_rate numeric;

COMMENT ON COLUMN public.payment_transactions.dollar_rate IS 'Exchange rate (PKR per USD) used for this specific transaction';
