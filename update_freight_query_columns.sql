-- Add new cargo detail columns to the freight_query table
ALTER TABLE freight_query
ADD COLUMN IF NOT EXISTS type TEXT,
ADD COLUMN IF NOT EXISTS dimension TEXT,
ADD COLUMN IF NOT EXISTS approx_cbm NUMERIC,
ADD COLUMN IF NOT EXISTS total_containers TEXT;

-- We already have: gross_weight, net_weight, no_of_cartoons
-- The user requested 'type' (Containers/Cartons)
-- 'dimension' (TEXT for like 10x20x30)
-- 'approx_cbm' (NUMERIC)
-- 'total_containers' (TEXT)
