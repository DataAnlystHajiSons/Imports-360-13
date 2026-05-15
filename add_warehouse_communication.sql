-- Create warehouse_communication table
CREATE TABLE IF NOT EXISTS public.warehouse_communication (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  shipment_id uuid NOT NULL,
  warehouse_id uuid NOT NULL,
  sent_by uuid NOT NULL,
  sent_at timestamp with time zone DEFAULT now(),
  email_subject text,
  email_body text,
  cc_emails text[],
  status text,
  CONSTRAINT warehouse_communication_pkey PRIMARY KEY (id),
  CONSTRAINT warehouse_communication_shipment_id_fkey FOREIGN KEY (shipment_id) REFERENCES public.shipment(id),
  CONSTRAINT warehouse_communication_warehouse_id_fkey FOREIGN KEY (warehouse_id) REFERENCES public.warehouse(id),
  CONSTRAINT warehouse_communication_sent_by_fkey FOREIGN KEY (sent_by) REFERENCES public.app_user(id)
);

-- Enable RLS
ALTER TABLE public.warehouse_communication ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_policies
        WHERE tablename = 'warehouse_communication'
        AND policyname = 'Authenticated users can access warehouse_communication'
    ) THEN
        CREATE POLICY "Authenticated users can access warehouse_communication" ON public.warehouse_communication FOR ALL TO authenticated USING (true);
    END IF;
END
$$;
