-- Create calculation audit table for tracking all auto-calculations
CREATE TABLE IF NOT EXISTS public.calculation_audit (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shipment_id uuid,
  calculation_type text NOT NULL,
  input_data jsonb NOT NULL,
  output_data jsonb NOT NULL,
  calculated_at timestamp with time zone DEFAULT now(),
  calculated_by uuid,
  CONSTRAINT calculation_audit_pkey PRIMARY KEY (id),
  CONSTRAINT calculation_audit_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id),
  CONSTRAINT calculation_audit_calculated_by_fkey FOREIGN KEY (calculated_by) REFERENCES public.app_user(id)
);

-- Create index for better query performance
CREATE INDEX IF NOT EXISTS idx_calculation_audit_shipment_id ON public.calculation_audit(shipment_id);
CREATE INDEX IF NOT EXISTS idx_calculation_audit_type ON public.calculation_audit(calculation_type);
CREATE INDEX IF NOT EXISTS idx_calculation_audit_calculated_at ON public.calculation_audit(calculated_at);

-- Add RLS policies for calculation_audit table
ALTER TABLE public.calculation_audit ENABLE ROW LEVEL SECURITY;

-- Policy: Users can view calculation audits for shipments they have access to
CREATE POLICY "Users can view calculation audits" ON public.calculation_audit
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.shipment s 
      WHERE s.id = calculation_audit.shipment_id
    )
  );

-- Policy: Users can insert calculation audits
CREATE POLICY "Users can insert calculation audits" ON public.calculation_audit
  FOR INSERT WITH CHECK (
    auth.uid() = calculated_by AND
    EXISTS (
      SELECT 1 FROM public.shipment s 
      WHERE s.id = calculation_audit.shipment_id
    )
  );

-- Grant necessary permissions
GRANT SELECT, INSERT ON public.calculation_audit TO authenticated;
GRANT USAGE ON SEQUENCE calculation_audit_id_seq TO authenticated;