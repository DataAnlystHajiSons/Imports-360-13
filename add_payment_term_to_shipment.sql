ALTER TABLE public.shipment
ADD COLUMN payment_term_id uuid,
ADD CONSTRAINT fk_payment_term
  FOREIGN KEY (payment_term_id)
  REFERENCES public.payment_terms(id);