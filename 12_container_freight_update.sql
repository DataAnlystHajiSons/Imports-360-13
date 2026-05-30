-- 12_container_freight_update.sql
-- Add new columns for Containers specific fields in Freight Queries

ALTER TABLE public.freight_query ADD COLUMN IF NOT EXISTS no_of_containers numeric;
ALTER TABLE public.freight_query ADD COLUMN IF NOT EXISTS container_size text;

-- Add new column for Container Charges in Quotes
ALTER TABLE public.freight_quote_response ADD COLUMN IF NOT EXISTS container_charges numeric DEFAULT 0;
ALTER TABLE public.freight_quote_response ADD COLUMN IF NOT EXISTS container_currency text DEFAULT 'USD';
ALTER TABLE public.freight_quote_response ADD COLUMN IF NOT EXISTS container_exchange_rate numeric DEFAULT 278.50;

-- Refresh schema cache
NOTIFY pgrst, 'reload schema';
