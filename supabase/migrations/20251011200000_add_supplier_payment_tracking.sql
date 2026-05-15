-- 1. Create the payment_terms table
CREATE TABLE public.payment_terms (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL UNIQUE,
    description text,
    payment_schedule jsonb NOT NULL,
    created_at timestamptz DEFAULT now(),
    created_by uuid REFERENCES public.app_user(id)
);

-- Add RLS policy for payment_terms
ALTER TABLE public.payment_terms ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to authenticated users on payment_terms" ON public.payment_terms FOR ALL TO authenticated USING (true);


-- 2. Create the supplier_payments table
CREATE TABLE public.supplier_payments (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    shipment_id uuid NOT NULL REFERENCES public.shipment(id) UNIQUE,
    supplier_id uuid NOT NULL REFERENCES public.supplier(id),
    payment_term_id uuid NOT NULL REFERENCES public.payment_terms(id),
    total_amount numeric NOT NULL,
    amount_paid numeric NOT NULL DEFAULT 0,
    due_date date,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'partially_paid', 'paid', 'overdue')),
    proof_of_payment_url text,
    notes text,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now(),
    created_by uuid REFERENCES public.app_user(id)
);

-- Add RLS policy for supplier_payments
ALTER TABLE public.supplier_payments ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Allow all access to authenticated users on supplier_payments" ON public.supplier_payments FOR ALL TO authenticated USING (true);

-- Trigger to automatically update 'updated_at' timestamp
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER on_supplier_payments_update
  BEFORE UPDATE ON public.supplier_payments
  FOR EACH ROW
  EXECUTE PROCEDURE public.handle_updated_at();


-- 3. Alter the supplier table
ALTER TABLE public.supplier
ADD COLUMN default_payment_term_id uuid REFERENCES public.payment_terms(id);
