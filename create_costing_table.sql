-- Create costing table
CREATE TABLE IF NOT EXISTS public.costing (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shipment_id uuid NOT NULL UNIQUE,
  final_payment numeric,
  invoice_charges numeric,
  exchange_rate numeric,
  ip_charges numeric,
  bank_contract_opening_charges numeric,
  shipping_guarantee numeric,
  fbr_duty numeric,
  forwarder_charges numeric,
  clearing_charges numeric,
  local_transporter numeric,
  port_charges numeric,
  final_payment_charges numeric,
  total numeric,
  total_cost numeric,
  oh_perc numeric,
  qty numeric,
  per_unit_rate numeric,
  created_at timestamp with time zone DEFAULT now(),
  created_by uuid,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT costing_pkey PRIMARY KEY (id),
  CONSTRAINT costing_created_by_fkey FOREIGN KEY (created_by) REFERENCES public.app_user(id),
  CONSTRAINT costing_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id)
);

-- Enable RLS and add policy
ALTER TABLE public.costing ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE tablename = 'costing'
        AND policyname = 'Authenticated users can access costing'
    ) THEN
        CREATE POLICY "Authenticated users can access costing" ON public.costing FOR ALL TO authenticated USING (true);
    END IF;
END
$$;
