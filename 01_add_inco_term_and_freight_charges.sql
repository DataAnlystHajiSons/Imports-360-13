-- ========================================================================
-- Migration: Add inco_term and freight_charges to shipment table
-- Purpose: Support inco-term based workflow and freight charges tracking
-- ========================================================================

-- Add inco_term column to shipment table
ALTER TABLE public.shipment 
ADD COLUMN IF NOT EXISTS inco_term text 
CHECK (inco_term = ANY (ARRAY['EXW'::text, 'FOB'::text, 'CFR'::text, 'FCA'::text, 'CPT'::text, 'DDP'::text]));

-- Add freight_charges column to shipment table
-- Only applicable when inco_term is 'FOB'
ALTER TABLE public.shipment 
ADD COLUMN IF NOT EXISTS freight_charges numeric;

-- Add comment for clarity
COMMENT ON COLUMN public.shipment.inco_term IS 'International Commercial Terms - defines buyer/seller responsibilities. Options based on mode_of_transport: Air (FCA, EXW, CPT), Sea (EXW, FOB, CFR)';
COMMENT ON COLUMN public.shipment.freight_charges IS 'Freight charges amount - Required when inco_term is FOB';

-- Create index for faster queries by inco_term
CREATE INDEX IF NOT EXISTS idx_shipment_inco_term ON public.shipment(inco_term);

-- Migration completed
SELECT 'Inco-term and Freight Charges columns added successfully' as migration_status;
