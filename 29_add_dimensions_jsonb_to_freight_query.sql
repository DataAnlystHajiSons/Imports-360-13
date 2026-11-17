-- Migration: 29_add_dimensions_jsonb_to_freight_query.sql
-- Description: Add dimensions JSONB column to freight_query table to support multiple package dimensions

BEGIN;

ALTER TABLE public.freight_query 
ADD COLUMN IF NOT EXISTS dimensions JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN public.freight_query.dimensions IS 'Structured array of package dimensions: [{length, width, height, cartons, cbm, volumetric_weight}]';

NOTIFY pgrst, 'reload schema';

COMMIT;
