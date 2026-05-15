-- Add mode_of_transport column to shipment table
-- This column will determine the stage flow and logic for different transport modes

ALTER TABLE public.shipment 
ADD COLUMN mode_of_transport TEXT NOT NULL DEFAULT 'sea';

-- Create check constraint to ensure only valid values
ALTER TABLE public.shipment 
ADD CONSTRAINT shipment_mode_of_transport_check 
CHECK (mode_of_transport IN ('sea', 'air', 'land', 'rail', 'multimodal'));

-- Add comment for documentation
COMMENT ON COLUMN public.shipment.mode_of_transport IS 'Mode of transport for shipment: sea, air, land, rail, multimodal';

-- Update existing shipments to have 'sea' as default mode (already set by DEFAULT clause)
-- The DEFAULT clause above handles this automatically for existing rows

-- Create index for better query performance if this will be used in WHERE clauses
CREATE INDEX idx_shipment_mode_of_transport ON public.shipment(mode_of_transport);
