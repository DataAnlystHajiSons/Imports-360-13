-- Migration: Add Per-Charge Currency Support to Freight Quotes
-- This script adds individual currency and exchange_rate columns for each charge type.

BEGIN;

-- Add columns for Freight Charges
ALTER TABLE public.freight_quote_response ADD COLUMN IF NOT EXISTS freight_currency VARCHAR(10) DEFAULT 'USD';
ALTER TABLE public.freight_quote_response ADD COLUMN IF NOT EXISTS freight_exchange_rate NUMERIC DEFAULT 278.50;

-- Add columns for DO Charges
ALTER TABLE public.freight_quote_response ADD COLUMN IF NOT EXISTS do_currency VARCHAR(10) DEFAULT 'PKR';
ALTER TABLE public.freight_quote_response ADD COLUMN IF NOT EXISTS do_exchange_rate NUMERIC DEFAULT 1;

-- Add columns for Other Charges
ALTER TABLE public.freight_quote_response ADD COLUMN IF NOT EXISTS other_currency VARCHAR(10) DEFAULT 'PKR';
ALTER TABLE public.freight_quote_response ADD COLUMN IF NOT EXISTS other_exchange_rate NUMERIC DEFAULT 1;

-- Keep the original currency and exchange_rate for backward compatibility or as defaults if needed
-- but we will transition to these specific ones.

COMMIT;
