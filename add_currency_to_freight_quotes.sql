-- Migration: Add Multi-Currency Support to Freight Quotes
-- This script adds currency and exchange_rate columns to freight_quote_response.

BEGIN;

ALTER TABLE public.freight_quote_response ADD COLUMN IF NOT EXISTS currency VARCHAR(10) DEFAULT 'USD';
ALTER TABLE public.freight_quote_response DROP CONSTRAINT IF EXISTS freight_quote_response_currency_check;
ALTER TABLE public.freight_quote_response ADD CONSTRAINT freight_quote_response_currency_check CHECK (currency IN ('USD', 'EUR', 'PKR', 'CNY', 'GBP'));

ALTER TABLE public.freight_quote_response ADD COLUMN IF NOT EXISTS exchange_rate NUMERIC DEFAULT 1;

-- Also add other_charges if missing, as it's used in calculations but might be missing from schema
ALTER TABLE public.freight_quote_response ADD COLUMN IF NOT EXISTS other_charges NUMERIC DEFAULT 0;

COMMIT;
